// NetworkKit does not expose multicast interface selection. Keep this bridge
// limited to discovery: TCP clients and HTTP receive remain on NetworkKit.
#include <napi/native_api.h>
#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>
using UdpFd = SOCKET;
constexpr UdpFd badFd = INVALID_SOCKET;
static void closeUdp(UdpFd fd) { closesocket(fd); }
#else
#include <sys/socket.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <unistd.h>
#include <poll.h>
#include <fcntl.h>
using UdpFd = int;
constexpr UdpFd badFd = -1;
static void closeUdp(UdpFd fd) { close(fd); }
#endif
#include <atomic>
#include <cerrno>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

namespace {
struct Datagram { std::string kind, ip, error; int port = 0; std::vector<unsigned char> bytes; };
struct Channel {
    UdpFd fd = badFd;
    int id = 0;
    sockaddr_storage target{};
    int targetSize = 0;
    napi_threadsafe_function callback = nullptr;
    std::atomic<bool> stopped{false};
    std::mutex mutex;
    ~Channel() { if (fd != badFd) closeUdp(fd); }
};
std::mutex registryMutex;
std::map<int, std::shared_ptr<Channel>> channels;
std::atomic<int> sequence{0};
void setText(napi_env env, napi_value object, const char* name, const std::string& text) {
    napi_value value; napi_create_string_utf8(env, text.c_str(), text.size(), &value); napi_set_named_property(env, object, name, value);
}
void appendInterface(napi_env env, napi_value array, const char* name, const sockaddr* address, int prefix) {
    char text[INET6_ADDRSTRLEN]{};
    const void* bytes = address->sa_family == AF_INET
        ? static_cast<const void*>(&reinterpret_cast<const sockaddr_in*>(address)->sin_addr)
        : static_cast<const void*>(&reinterpret_cast<const sockaddr_in6*>(address)->sin6_addr);
    if (!inet_ntop(address->sa_family, bytes, text, sizeof(text))) return;
    std::string ip(text);
    if (address->sa_family == AF_INET6) {
        const auto* v6 = reinterpret_cast<const sockaddr_in6*>(address);
        if (IN6_IS_ADDR_LINKLOCAL(&v6->sin6_addr)) ip += "%" + std::to_string(v6->sin6_scope_id ? v6->sin6_scope_id : if_nametoindex(name));
    }
    napi_value object, value; napi_create_object(env, &object);
    setText(env, object, "name", name); setText(env, object, "ip", ip);
    napi_create_int32(env, prefix, &value); napi_set_named_property(env, object, "prefixLength", value);
    uint32_t length = 0; napi_get_array_length(env, array, &length); napi_set_element(env, array, length, object);
}
napi_value listInterfaces(napi_env env, napi_callback_info) {
    napi_value array; napi_create_array(env, &array);
#ifdef _WIN32
    ULONG size = 16384, result = ERROR_BUFFER_OVERFLOW;
    std::vector<unsigned char> buffer;
    for (int attempt = 0; attempt < 3 && result == ERROR_BUFFER_OVERFLOW; ++attempt) {
        buffer.resize(size);
        result = GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER,
            nullptr, reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data()), &size);
    }
    if (result == ERROR_NO_DATA) return array;
    if (result != NO_ERROR) { napi_throw_error(env, nullptr, "Enumerating network interfaces failed"); return nullptr; }
    for (auto* adapter = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data()); adapter; adapter = adapter->Next) {
        if (adapter->OperStatus != IfOperStatusUp || adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK) continue;
        for (auto* link = adapter->FirstUnicastAddress; link; link = link->Next) {
            const auto* address = link->Address.lpSockaddr;
            if (!address || (address->sa_family != AF_INET && address->sa_family != AF_INET6)) continue;
            const std::string name = std::to_string(address->sa_family == AF_INET6 ? adapter->Ipv6IfIndex : adapter->IfIndex);
            appendInterface(env, array, name.c_str(), address, link->OnLinkPrefixLength);
        }
    }
#else
    ifaddrs* raw = nullptr;
    if (getifaddrs(&raw) != 0) { napi_throw_error(env, nullptr, "Enumerating network interfaces failed"); return nullptr; }
    std::unique_ptr<ifaddrs, decltype(&freeifaddrs)> list(raw, freeifaddrs);
    for (auto* link = raw; link; link = link->ifa_next) {
        if (!link->ifa_addr || !link->ifa_name || !(link->ifa_flags & IFF_UP) || (link->ifa_flags & IFF_LOOPBACK)) continue;
        const int family = link->ifa_addr->sa_family;
        if (family != AF_INET && family != AF_INET6) continue;
        int prefix = 0;
        if (link->ifa_netmask && link->ifa_netmask->sa_family == family) {
            const auto* mask = family == AF_INET
                ? reinterpret_cast<const unsigned char*>(&reinterpret_cast<const sockaddr_in*>(link->ifa_netmask)->sin_addr)
                : reinterpret_cast<const unsigned char*>(&reinterpret_cast<const sockaddr_in6*>(link->ifa_netmask)->sin6_addr);
            bool zero = false, valid = true;
            for (int i = 0; i < (family == AF_INET ? 4 : 16); ++i) {
                for (int bit = 7; bit >= 0; --bit) {
                    if (mask[i] & (1 << bit)) { if (zero) valid = false; ++prefix; } else zero = true;
                }
            }
            if (!valid) prefix = 0;
        }
        appendInterface(env, array, link->ifa_name, link->ifa_addr, prefix);
    }
#endif
    return array;
}
void dispatch(napi_env env, napi_value callback, void*, void* raw) {
    std::unique_ptr<Datagram> event(static_cast<Datagram*>(raw));
    if (!env || !callback) return;
    napi_value object, data, receiver; napi_create_object(env, &object);
    setText(env, object, "kind", event->kind); setText(env, object, "ip", event->ip); setText(env, object, "error", event->error);
    napi_create_int32(env, event->port, &data); napi_set_named_property(env, object, "port", data);
    void* bytes = nullptr;
    if (napi_create_arraybuffer(env, event->bytes.size(), &bytes, &data) != napi_ok) return;
    if (!event->bytes.empty()) memcpy(bytes, event->bytes.data(), event->bytes.size());
    napi_set_named_property(env, object, "data", data);
    napi_get_undefined(env, &receiver); napi_call_function(env, receiver, callback, 1, &object, nullptr);
}
void emit(Channel& channel, Datagram* event, bool required = false) {
    if (napi_call_threadsafe_function(channel.callback, event, required ? napi_tsfn_blocking : napi_tsfn_nonblocking) != napi_ok) delete event;
}
std::string socketError(const char* action) {
#ifdef _WIN32
    return std::string(action) + " (" + std::to_string(WSAGetLastError()) + ")";
#else
    return std::string(action) + " (" + std::to_string(errno) + ")";
#endif
}
bool retryable() {
#ifdef _WIN32
    const int e = WSAGetLastError(); return e == WSAEINTR || e == WSAEWOULDBLOCK;
#else
    return errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK;
#endif
}
void receive(const std::shared_ptr<Channel>& channel) {
    unsigned char buffer[16385];
    std::string failure;
    while (!channel->stopped) {
#ifdef _WIN32
        fd_set reads; FD_ZERO(&reads); FD_SET(channel->fd, &reads); timeval timeout{0, 100000};
        const int ready = select(0, &reads, nullptr, nullptr, &timeout);
#else
        pollfd descriptor{channel->fd, POLLIN, 0}; const int ready = poll(&descriptor, 1, 100);
#endif
        if (channel->stopped) break;
        if (ready == 0 || (ready < 0 && retryable())) continue;
        if (ready < 0) { failure = socketError("Multicast wait failed"); break; }
        sockaddr_storage address{};
#ifdef _WIN32
        int length = sizeof(address);
#else
        socklen_t length = sizeof(address);
#endif
        const int size = recvfrom(channel->fd, reinterpret_cast<char*>(buffer), sizeof(buffer), 0, reinterpret_cast<sockaddr*>(&address), &length);
        if (size < 0 && retryable()) continue;
#ifdef _WIN32
        if (size < 0 && WSAGetLastError() == WSAEMSGSIZE) continue;
#endif
        if (size < 0) { failure = socketError("Multicast receive failed"); break; }
        if (size == 0 || size > 16384) continue;
        auto event = new Datagram(); event->kind = "message"; char ip[INET6_ADDRSTRLEN]{};
        if (address.ss_family == AF_INET6) {
            auto& v6 = *reinterpret_cast<sockaddr_in6*>(&address); inet_ntop(AF_INET6, &v6.sin6_addr, ip, sizeof(ip));
            event->ip = ip; if (v6.sin6_scope_id) event->ip += "%" + std::to_string(v6.sin6_scope_id);
            event->port = ntohs(v6.sin6_port);
        } else {
            auto& v4 = *reinterpret_cast<sockaddr_in*>(&address); inet_ntop(AF_INET, &v4.sin_addr, ip, sizeof(ip));
            event->ip = ip; event->port = ntohs(v4.sin_port);
        }
        event->bytes.assign(buffer, buffer + size); emit(*channel, event);
    }
    {
        std::lock_guard<std::mutex> lock(channel->mutex);
        channel->stopped = true; closeUdp(channel->fd); channel->fd = badFd;
    }
    { std::lock_guard<std::mutex> lock(registryMutex); channels.erase(channel->id); }
    // Close is acknowledged only after the descriptor has been released.
    auto event = new Datagram(); event->kind = "stopped"; event->error = failure;
    emit(*channel, event, true); napi_release_threadsafe_function(channel->callback, napi_tsfn_release);
}
std::string text(napi_env env, napi_value value) {
    char buffer[256]; size_t length = 0;
    if (napi_get_value_string_utf8(env, value, buffer, sizeof(buffer), &length) != napi_ok || length >= sizeof(buffer) - 1) throw std::runtime_error("Invalid multicast address/interface");
    return std::string(buffer, length);
}
int number(napi_env env, napi_value value) {
    int32_t result;
    if (napi_get_value_int32(env, value, &result) != napi_ok) throw std::runtime_error("Invalid multicast number");
    return result;
}
void option(UdpFd fd, int level, int name, const void* data, int length) {
    if (setsockopt(fd, level, name, static_cast<const char*>(data), length) != 0) throw std::runtime_error(socketError("Multicast option failed"));
}
napi_value openChannel(napi_env env, napi_callback_info info) {
    size_t count = 4; napi_value args[4]; napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    try {
        if (count != 4) throw std::runtime_error("Expected group, port, interface, callback");
#ifdef _WIN32
        static const bool initialized = [] { WSADATA data; return WSAStartup(MAKEWORD(2, 2), &data) == 0; }();
        if (!initialized) throw std::runtime_error("Socket initialization failed");
#endif
        const auto group = text(env, args[0]), network = text(env, args[2]);
        const int port = number(env, args[1]); if (port < 1 || port > 65535) throw std::runtime_error("Invalid multicast port");
        const bool v6 = group.find(':') != std::string::npos;
        auto channel = std::make_shared<Channel>(); channel->id = ++sequence;
        channel->fd = socket(v6 ? AF_INET6 : AF_INET, SOCK_DGRAM, 0);
        if (channel->fd == badFd) throw std::runtime_error(socketError("Multicast socket failed"));
        const int yes = 1;
        option(channel->fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
#ifdef SO_REUSEPORT
        option(channel->fd, SOL_SOCKET, SO_REUSEPORT, &yes, sizeof(yes));
#endif
        sockaddr_storage bindAddress{}; int length;
        if (v6) {
            auto& address = *reinterpret_cast<sockaddr_in6*>(&bindAddress); address.sin6_family = AF_INET6; address.sin6_port = htons(port); length = sizeof(address);
            option(channel->fd, IPPROTO_IPV6, IPV6_V6ONLY, &yes, sizeof(yes));
        } else {
            auto& address = *reinterpret_cast<sockaddr_in*>(&bindAddress); address.sin_family = AF_INET; address.sin_port = htons(port); length = sizeof(address);
        }
        if (bind(channel->fd, reinterpret_cast<sockaddr*>(&bindAddress), length) != 0) throw std::runtime_error(socketError("Multicast bind failed"));
        if (v6) {
            const bool numeric = !network.empty() && network.find_first_not_of("0123456789") == std::string::npos;
            const auto supplied = numeric ? std::stoul(network) : 0;
            if (supplied > 0xffffffffUL) throw std::runtime_error("Invalid IPv6 interface index");
            const unsigned index = numeric ? static_cast<unsigned>(supplied) : if_nametoindex(network.c_str());
            if (!index) throw std::runtime_error("Unknown IPv6 interface");
            ipv6_mreq membership{}; membership.ipv6mr_interface = index;
            if (inet_pton(AF_INET6, group.c_str(), &membership.ipv6mr_multiaddr) != 1 || membership.ipv6mr_multiaddr.s6_addr[0] != 0xff) throw std::runtime_error("Invalid IPv6 multicast group");
            option(channel->fd, IPPROTO_IPV6, IPV6_JOIN_GROUP, &membership, sizeof(membership));
            option(channel->fd, IPPROTO_IPV6, IPV6_MULTICAST_IF, &index, sizeof(index));
            option(channel->fd, IPPROTO_IPV6, IPV6_MULTICAST_HOPS, &yes, sizeof(yes));
            option(channel->fd, IPPROTO_IPV6, IPV6_MULTICAST_LOOP, &yes, sizeof(yes));
            auto& target = *reinterpret_cast<sockaddr_in6*>(&channel->target); target.sin6_family = AF_INET6;
            target.sin6_addr = membership.ipv6mr_multiaddr; target.sin6_port = htons(port); target.sin6_scope_id = index; channel->targetSize = sizeof(target);
        } else {
            ip_mreq membership{};
            if (inet_pton(AF_INET, group.c_str(), &membership.imr_multiaddr) != 1 || (ntohl(membership.imr_multiaddr.s_addr) >> 28) != 14 || inet_pton(AF_INET, network.c_str(), &membership.imr_interface) != 1) throw std::runtime_error("Invalid IPv4 multicast interface/group");
            option(channel->fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &membership, sizeof(membership));
            option(channel->fd, IPPROTO_IP, IP_MULTICAST_IF, &membership.imr_interface, sizeof(membership.imr_interface));
            option(channel->fd, IPPROTO_IP, IP_MULTICAST_TTL, &yes, sizeof(yes));
            option(channel->fd, IPPROTO_IP, IP_MULTICAST_LOOP, &yes, sizeof(yes));
            auto& target = *reinterpret_cast<sockaddr_in*>(&channel->target); target.sin_family = AF_INET;
            target.sin_addr = membership.imr_multiaddr; target.sin_port = htons(port); channel->targetSize = sizeof(target);
        }
#ifdef _WIN32
        u_long nonblocking = 1; if (ioctlsocket(channel->fd, FIONBIO, &nonblocking) != 0) throw std::runtime_error("Multicast nonblocking failed");
#else
        const int flags = fcntl(channel->fd, F_GETFL, 0);
        if (flags < 0 || fcntl(channel->fd, F_SETFL, flags | O_NONBLOCK) != 0) throw std::runtime_error("Multicast nonblocking failed");
#endif
        napi_value name; napi_create_string_utf8(env, "AloeMulticast", NAPI_AUTO_LENGTH, &name);
        if (napi_create_threadsafe_function(env, args[3], nullptr, name, 64, 1, nullptr, nullptr, nullptr, dispatch, &channel->callback) != napi_ok) throw std::runtime_error("Multicast callback creation failed");
        { std::lock_guard<std::mutex> lock(registryMutex); channels[channel->id] = channel; }
        try { std::thread([channel] { receive(channel); }).detach(); }
        catch (...) { { std::lock_guard<std::mutex> lock(registryMutex); channels.erase(channel->id); } napi_release_threadsafe_function(channel->callback, napi_tsfn_abort); throw; }
        napi_value result; napi_create_int32(env, channel->id, &result); return result;
    } catch (const std::exception& e) { napi_throw_error(env, nullptr, e.what()); return nullptr; }
}
napi_value sendChannel(napi_env env, napi_callback_info info) {
    size_t count = 2; napi_value args[2]; napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    try {
        if (count != 2) throw std::runtime_error("Expected multicast handle and bytes");
        const int id = number(env, args[0]); std::shared_ptr<Channel> channel;
        { std::lock_guard<std::mutex> lock(registryMutex); auto it = channels.find(id); if (it == channels.end()) throw std::runtime_error("Multicast closed"); channel = it->second; }
        void* bytes; size_t size;
        if (napi_get_arraybuffer_info(env, args[1], &bytes, &size) != napi_ok || size > 16384) throw std::runtime_error("Invalid multicast payload");
        std::lock_guard<std::mutex> lock(channel->mutex);
        if (channel->stopped || channel->fd == badFd) throw std::runtime_error("Multicast closed");
        if (sendto(channel->fd, static_cast<char*>(bytes), static_cast<int>(size), 0, reinterpret_cast<sockaddr*>(&channel->target), channel->targetSize) != static_cast<int>(size)) throw std::runtime_error(socketError("Multicast send failed"));
    } catch (const std::exception& e) { napi_throw_error(env, nullptr, e.what()); }
    return nullptr;
}
napi_value stopChannel(napi_env env, napi_callback_info info) {
    size_t count = 1; napi_value arg; napi_get_cb_info(env, info, &count, &arg, nullptr, nullptr);
    try { const int id = number(env, arg); std::lock_guard<std::mutex> lock(registryMutex); auto it = channels.find(id); if (it != channels.end()) it->second->stopped = true; }
    catch (const std::exception& e) { napi_throw_error(env, nullptr, e.what()); }
    return nullptr;
}
}
void registerMulticast(napi_env env, napi_value exports) {
    const napi_property_descriptor functions[] = {
        {"networkInterfaces", nullptr, listInterfaces, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"multicastOpen", nullptr, openChannel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"multicastSend", nullptr, sendChannel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"multicastStop", nullptr, stopChannel, nullptr, nullptr, nullptr, napi_default, nullptr}};
    napi_define_properties(env, exports, sizeof(functions) / sizeof(functions[0]), functions);
}
