#include <napi/native_api.h>
#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
using UdpSocket = SOCKET;
constexpr UdpSocket invalidUdp = INVALID_SOCKET;
static void closeUdp(UdpSocket fd) { closesocket(fd); }
#else
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <poll.h>
#include <fcntl.h>
using UdpSocket = int;
constexpr UdpSocket invalidUdp = -1;
static void closeUdp(UdpSocket fd) { ::close(fd); }
#endif
#include <atomic>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

namespace {
struct Datagram {
    std::string kind, ip; int port = 0;
    std::vector<unsigned char> data;
};
struct Endpoint {
    UdpSocket fd = invalidUdp;
    napi_threadsafe_function callback = nullptr;
    std::atomic<bool> stopped{false};
    ~Endpoint() { if (fd != invalidUdp) closeUdp(fd); }
};
// Registry access is confined to the JS thread; workers retain shared ownership
// until their stopped event is queued, so descriptor reuse cannot race send/close.
std::map<int, std::shared_ptr<Endpoint>> endpoints;
int nextId = 0;
int integer(napi_env env, napi_value value) {
    int32_t result = 0;
    if (napi_get_value_int32(env, value, &result) != napi_ok) throw std::runtime_error("Invalid UDP number");
    return result;
}
std::string text(napi_env env, napi_value value) {
    char bytes[64]{}; size_t length = 0;
    if (napi_get_value_string_utf8(env, value, bytes, sizeof(bytes), &length) != napi_ok || length >= sizeof(bytes) - 1)
        throw std::runtime_error("Invalid UDP address");
    return std::string(bytes, length);
}
void dispatch(napi_env env, napi_value callback, void*, void* raw) {
    std::unique_ptr<Datagram> event(static_cast<Datagram*>(raw));
    if (!env || !callback) return;
    napi_value object, value, receiver; napi_create_object(env, &object);
    napi_create_string_utf8(env, event->kind.c_str(), NAPI_AUTO_LENGTH, &value); napi_set_named_property(env, object, "kind", value);
    napi_create_string_utf8(env, event->ip.c_str(), NAPI_AUTO_LENGTH, &value); napi_set_named_property(env, object, "ip", value);
    napi_create_int32(env, event->port, &value); napi_set_named_property(env, object, "port", value);
    void* data = nullptr;
    if (napi_create_arraybuffer(env, event->data.size(), &data, &value) != napi_ok) return;
    if (!event->data.empty()) std::memcpy(data, event->data.data(), event->data.size());
    napi_set_named_property(env, object, "data", value);
    napi_get_undefined(env, &receiver); napi_call_function(env, receiver, callback, 1, &object, nullptr);
}
void receive(const std::shared_ptr<Endpoint>& endpoint) {
    unsigned char bytes[65536];
    while (!endpoint->stopped) {
#ifdef _WIN32
        fd_set reads; FD_ZERO(&reads); FD_SET(endpoint->fd, &reads); timeval wait{0, 100000};
        const int ready = select(0, &reads, nullptr, nullptr, &wait);
#else
        pollfd descriptor{endpoint->fd, POLLIN, 0}; const int ready = poll(&descriptor, 1, 100);
#endif
        if (endpoint->stopped) break;
        if (ready <= 0) continue;
        sockaddr_in address{};
#ifdef _WIN32
        int length = sizeof(address);
#else
        socklen_t length = sizeof(address);
#endif
        const int count = recvfrom(endpoint->fd, reinterpret_cast<char*>(bytes), sizeof(bytes), 0, reinterpret_cast<sockaddr*>(&address), &length);
        if (count < 0) continue;
        auto event = std::make_unique<Datagram>(); event->kind = "message"; event->port = ntohs(address.sin_port);
        char ip[INET_ADDRSTRLEN]{}; inet_ntop(AF_INET, &address.sin_addr, ip, sizeof(ip)); event->ip = ip;
        event->data.assign(bytes, bytes + count);
        // Discovery announcements may be dropped under overload. Never let an
        // untrusted LAN sender block the worker or grow the JS event queue.
        if (napi_call_threadsafe_function(endpoint->callback, event.get(), napi_tsfn_nonblocking) == napi_ok) event.release();
    }
    auto event = new Datagram(); event->kind = "stopped";
    if (napi_call_threadsafe_function(endpoint->callback, event, napi_tsfn_blocking) != napi_ok) delete event;
    napi_release_threadsafe_function(endpoint->callback, napi_tsfn_release);
}
napi_value udpListen(napi_env env, napi_callback_info info) {
    size_t count = 4; napi_value args[4]{}; napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    try {
        if (count != 4) throw std::runtime_error("Expected UDP address, port, group and callback");
#ifdef _WIN32
        static const bool initialized = [] { WSADATA data; return WSAStartup(MAKEWORD(2, 2), &data) == 0; }();
        if (!initialized) throw std::runtime_error("Socket initialization failed");
#endif
        if (endpoints.size() >= 8) throw std::runtime_error("UDP endpoint limit reached");
        const int port = integer(env, args[1]); if (port < 1 || port > 65535) throw std::runtime_error("Invalid UDP port");
        sockaddr_in address{}; address.sin_family = AF_INET; address.sin_port = htons(port);
        ip_mreq membership{};
        if (inet_pton(AF_INET, text(env, args[0]).c_str(), &address.sin_addr) != 1 ||
            inet_pton(AF_INET, text(env, args[2]).c_str(), &membership.imr_multiaddr) != 1 ||
            (ntohl(membership.imr_multiaddr.s_addr) & 0xf0000000u) != 0xe0000000u)
            throw std::runtime_error("Invalid UDP multicast address");
        auto endpoint = std::make_shared<Endpoint>(); endpoint->fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (endpoint->fd == invalidUdp) throw std::runtime_error("UDP socket creation failed");
        const int reuse = 1;
        if (setsockopt(endpoint->fd, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char*>(&reuse), sizeof(reuse)) != 0 ||
            bind(endpoint->fd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0 ||
            setsockopt(endpoint->fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, reinterpret_cast<const char*>(&membership), sizeof(membership)) != 0)
            throw std::runtime_error("UDP bind or multicast membership failed");
        const unsigned char ttl = 1;
        if (setsockopt(endpoint->fd, IPPROTO_IP, IP_MULTICAST_TTL, reinterpret_cast<const char*>(&ttl), sizeof(ttl)) != 0)
            throw std::runtime_error("UDP multicast TTL setup failed");
#ifdef _WIN32
        u_long nonblocking = 1;
        if (ioctlsocket(endpoint->fd, FIONBIO, &nonblocking) != 0) throw std::runtime_error("UDP nonblocking setup failed");
#else
        const int flags = fcntl(endpoint->fd, F_GETFL, 0);
        if (flags < 0 || fcntl(endpoint->fd, F_SETFL, flags | O_NONBLOCK) != 0) throw std::runtime_error("UDP nonblocking setup failed");
#endif
        napi_value name; napi_create_string_utf8(env, "AloeDiscoveryUDP", NAPI_AUTO_LENGTH, &name);
        if (napi_create_threadsafe_function(env, args[3], nullptr, name, 16, 1, nullptr, nullptr, nullptr, dispatch, &endpoint->callback) != napi_ok)
            throw std::runtime_error("UDP callback creation failed");
        const int id = ++nextId; endpoints[id] = endpoint;
        try { std::thread([endpoint] { receive(endpoint); }).detach(); }
        catch (...) { endpoints.erase(id); napi_release_threadsafe_function(endpoint->callback, napi_tsfn_abort); throw; }
        napi_value result; napi_create_int32(env, id, &result); return result;
    } catch (const std::exception& error) { napi_throw_error(env, nullptr, error.what()); return nullptr; }
}
napi_value udpSend(napi_env env, napi_callback_info info) {
    size_t count = 4; napi_value args[4]{}; napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    try {
        if (count != 4) throw std::runtime_error("Expected UDP handle, address, port and buffer");
        auto found = endpoints.find(integer(env, args[0])); if (found == endpoints.end()) throw std::runtime_error("UDP endpoint closed");
        const int port = integer(env, args[2]); if (port < 1 || port > 65535) throw std::runtime_error("Invalid UDP port");
        sockaddr_in address{}; address.sin_family = AF_INET; address.sin_port = htons(port);
        if (inet_pton(AF_INET, text(env, args[1]).c_str(), &address.sin_addr) != 1) throw std::runtime_error("Invalid UDP destination");
        void* bytes = nullptr; size_t size = 0;
        if (napi_get_arraybuffer_info(env, args[3], &bytes, &size) != napi_ok || size > 65507) throw std::runtime_error("Invalid UDP payload");
        if (sendto(found->second->fd, static_cast<const char*>(bytes), static_cast<int>(size), 0, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != static_cast<int>(size))
            throw std::runtime_error("UDP send failed");
    } catch (const std::exception& error) { napi_throw_error(env, nullptr, error.what()); }
    return nullptr;
}
napi_value udpClose(napi_env env, napi_callback_info info) {
    size_t count = 1; napi_value arg{}; napi_get_cb_info(env, info, &count, &arg, nullptr, nullptr);
    try {
        auto found = endpoints.find(integer(env, arg));
        if (found != endpoints.end()) { found->second->stopped = true; endpoints.erase(found); }
    } catch (const std::exception& error) { napi_throw_error(env, nullptr, error.what()); }
    return nullptr;
}
}
void registerUdp(napi_env env, napi_value exports) {
    const napi_property_descriptor functions[] = {
        {"udpListen", nullptr, udpListen, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"udpSend", nullptr, udpSend, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"udpClose", nullptr, udpClose, nullptr, nullptr, nullptr, napi_default, nullptr}};
    napi_define_properties(env, exports, sizeof(functions) / sizeof(functions[0]), functions);
}
