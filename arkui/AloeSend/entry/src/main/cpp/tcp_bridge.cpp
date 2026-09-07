#include <napi/native_api.h>
#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>
using Socket = SOCKET;
constexpr Socket invalidSocket = INVALID_SOCKET;
static void closeSocket(Socket fd) { closesocket(fd); }
static void shutdownSocket(Socket fd) { shutdown(fd, SD_BOTH); }
#else
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/time.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <poll.h>
#include <fcntl.h>
#include <net/if.h>
using Socket = int;
constexpr Socket invalidSocket = -1;
static void closeSocket(Socket fd) { ::close(fd); }
static void shutdownSocket(Socket fd) { ::shutdown(fd, SHUT_RDWR); }
#endif
#include <atomic>
#include <condition_variable>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <stdexcept>
#include <cerrno>

namespace {
struct Event {
    std::string kind, ip, error;
    int id = 0;
    std::vector<unsigned char> bytes;
};
struct Server;
struct Connection {
    Socket fd = invalidSocket;
    int id = 0, owner = 0;
    std::string ip;
    napi_threadsafe_function callback = nullptr;
    std::atomic<bool> stopped{false};
    std::mutex mutex, sendMutex;
    std::condition_variable condition;
    bool credit = false;
    ~Connection() { if (fd != invalidSocket) closeSocket(fd); }
    void stop() {
        if (!stopped.exchange(true)) shutdownSocket(fd);
        condition.notify_all();
    }
};
struct Server {
    Socket fd = invalidSocket;
    int id = 0;
    napi_threadsafe_function callback = nullptr;
    std::atomic<bool> stopped{false};
    std::mutex socketMutex;
    void stop() {
        std::lock_guard<std::mutex> lock(socketMutex);
        stopped = true;
        if (fd != invalidSocket) shutdownSocket(fd);
    }
    void close() {
        std::lock_guard<std::mutex> lock(socketMutex);
        if (fd != invalidSocket) { closeSocket(fd); fd = invalidSocket; }
    }
};
std::mutex registryMutex;
std::map<int, std::shared_ptr<Server>> servers;
std::map<int, std::shared_ptr<Connection>> connections;
std::atomic<int> nextId{0};

void property(napi_env env, napi_value object, const char* name, const std::string& text) {
    napi_value value; napi_create_string_utf8(env, text.c_str(), text.size(), &value);
    napi_set_named_property(env, object, name, value);
}
void dispatch(napi_env env, napi_value callback, void*, void* data) {
    std::unique_ptr<Event> event(static_cast<Event*>(data));
    if (!env || !callback) return;
    napi_value object, value, receiver;
    napi_create_object(env, &object);
    property(env, object, "kind", event->kind); property(env, object, "ip", event->ip);
    property(env, object, "error", event->error);
    napi_create_int32(env, event->id, &value); napi_set_named_property(env, object, "id", value);
    void* bytes = nullptr;
    if (napi_create_arraybuffer(env, event->bytes.size(), &bytes, &value) != napi_ok) return;
    if (!event->bytes.empty()) std::memcpy(bytes, event->bytes.data(), event->bytes.size());
    napi_set_named_property(env, object, "data", value);
    napi_get_undefined(env, &receiver); napi_call_function(env, receiver, callback, 1, &object, nullptr);
}
void emit(napi_threadsafe_function callback, Event* event) {
    if (napi_call_threadsafe_function(callback, event, napi_tsfn_blocking) != napi_ok) delete event;
}
bool wouldBlock() {
#ifdef _WIN32
    const int error = WSAGetLastError(); return error == WSAEWOULDBLOCK || error == WSAEINTR;
#else
    return errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR;
#endif
}
int ready(Socket fd, bool writing) {
#ifdef _WIN32
    fd_set selected, errors; FD_ZERO(&selected); FD_SET(fd, &selected); FD_ZERO(&errors); FD_SET(fd, &errors);
    timeval wait{0, 100000};
    return select(0, writing ? nullptr : &selected, writing ? &selected : nullptr, writing ? &errors : nullptr, &wait);
#else
    pollfd descriptor{fd, static_cast<short>(writing ? POLLOUT : POLLIN), 0};
    return poll(&descriptor, 1, 100);
#endif
}
bool ended(Socket fd) {
#ifdef _WIN32
    fd_set reads; FD_ZERO(&reads); FD_SET(fd, &reads); timeval wait{0, 0};
    if (select(0, &reads, nullptr, nullptr, &wait) <= 0) return false;
    char byte; const int count = recv(fd, &byte, 1, MSG_PEEK);
    return count == 0 || (count < 0 && WSAGetLastError() != WSAEWOULDBLOCK && WSAGetLastError() != WSAEINTR);
#else
    char byte; const int count = recv(fd, &byte, 1, MSG_PEEK | MSG_DONTWAIT);
    return count == 0 || (count < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR);
#endif
}
void readLoop(const std::shared_ptr<Connection>& connection) {
    unsigned char buffer[65536];
    while (!connection->stopped) {
        bool read = false;
        {
            std::unique_lock<std::mutex> lock(connection->mutex);
            connection->condition.wait_for(lock, std::chrono::milliseconds(100), [&] { return connection->stopped || connection->credit; });
            if (connection->stopped) break;
            read = connection->credit; connection->credit = false;
        }
        if (!read) {
            // Detect a peer leaving a consent dialog without consuming buffered
            // data while the application is applying disk backpressure.
            if (ended(connection->fd)) break;
            continue;
        }
        const int available = ready(connection->fd, false);
        if (available == 0 || (available < 0 && wouldBlock())) {
            std::lock_guard<std::mutex> lock(connection->mutex); connection->credit = true; continue;
        }
        if (available < 0 || connection->stopped) break;
        const int count = recv(connection->fd, reinterpret_cast<char*>(buffer), sizeof(buffer), 0);
        if (count < 0 && wouldBlock()) { std::lock_guard<std::mutex> lock(connection->mutex); connection->credit = true; continue; }
        if (count <= 0) break;
        auto event = new Event(); event->kind = "message"; event->id = connection->id; event->ip = connection->ip;
        event->bytes.assign(buffer, buffer + count); emit(connection->callback, event);
        // Exactly one read credit is consumed. The next recv starts only after
        // ArkTS has decrypted and written this chunk, bounding per-peer memory.
    }
    connection->stop();
    auto event = new Event(); event->kind = "close"; event->id = connection->id;
    emit(connection->callback, event);
    napi_release_threadsafe_function(connection->callback, napi_tsfn_release);
}
void acceptLoop(const std::shared_ptr<Server>& server) {
    while (!server->stopped) {
#ifdef _WIN32
        fd_set reads; FD_ZERO(&reads); FD_SET(server->fd, &reads); timeval wait{0, 100000};
        if (select(static_cast<int>(server->fd) + 1, &reads, nullptr, nullptr, &wait) <= 0) continue;
#else
        // poll supports descriptors above FD_SETSIZE without writing past an
        // fd_set, which is possible when the app has many open media files.
        pollfd descriptor{server->fd, POLLIN, 0};
        if (poll(&descriptor, 1, 100) <= 0) continue;
#endif
        if (server->stopped) break;
        sockaddr_storage address{};
#ifdef _WIN32
        int size = sizeof(address);
#else
        socklen_t size = sizeof(address);
#endif
        const Socket fd = accept(server->fd, reinterpret_cast<sockaddr*>(&address), &size);
        if (fd == invalidSocket) { if (server->stopped) break; continue; }
        if (server->stopped) { closeSocket(fd); break; }
        auto connection = std::make_shared<Connection>(); connection->fd = fd;
#ifdef _WIN32
        u_long nonblocking = 1;
        if (ioctlsocket(fd, FIONBIO, &nonblocking) != 0) continue;
#else
        const int flags = fcntl(fd, F_GETFL, 0);
        if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) != 0) continue;
#endif
        connection->id = ++nextId; connection->owner = server->id; connection->callback = server->callback;
        char ip[INET6_ADDRSTRLEN]{};
        if (address.ss_family == AF_INET) inet_ntop(AF_INET, &reinterpret_cast<sockaddr_in*>(&address)->sin_addr, ip, sizeof(ip));
        else inet_ntop(AF_INET6, &reinterpret_cast<sockaddr_in6*>(&address)->sin6_addr, ip, sizeof(ip));
        connection->ip = ip;
        {
            std::lock_guard<std::mutex> lock(registryMutex);
            if (connections.size() >= 64 || server->stopped) { connection->stop(); continue; }
            connections[connection->id] = connection;
        }
        if (napi_acquire_threadsafe_function(server->callback) != napi_ok) {
            connection->stop(); std::lock_guard<std::mutex> lock(registryMutex);
            connections.erase(connection->id); continue;
        }
        auto event = new Event(); event->kind = "connect"; event->id = connection->id; event->ip = connection->ip;
        emit(server->callback, event);
        try { std::thread([connection] { readLoop(connection); }).detach(); }
        catch (const std::exception&) {
            connection->stop();
            { std::lock_guard<std::mutex> lock(registryMutex); connections.erase(connection->id); }
            auto closed = new Event(); closed->kind = "close"; closed->id = connection->id;
            emit(server->callback, closed);
            napi_release_threadsafe_function(server->callback, napi_tsfn_release);
        }
    }
    server->close();
    auto event = new Event(); event->kind = "stopped"; event->id = server->id; emit(server->callback, event);
    napi_release_threadsafe_function(server->callback, napi_tsfn_release);
}
int integer(napi_env env, napi_value value) {
    int32_t result = 0;
    if (napi_get_value_int32(env, value, &result) != napi_ok) throw std::runtime_error("Expected TCP handle");
    return result;
}
std::shared_ptr<Connection> lookup(int id) {
    std::lock_guard<std::mutex> lock(registryMutex);
    const auto found = connections.find(id);
    if (found == connections.end()) throw std::runtime_error("TCP connection closed");
    return found->second;
}
napi_value tcpConnect(napi_env env, napi_callback_info info) {
    size_t count = 3; napi_value args[3]{}; napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    try {
        if (count != 3) throw std::runtime_error("Expected peer address, port and callback");
#ifdef _WIN32
        static const bool initialized = [] { WSADATA data; return WSAStartup(MAKEWORD(2, 2), &data) == 0; }();
        if (!initialized) throw std::runtime_error("Socket initialization failed");
#endif
        char host[128]{}; size_t length = 0;
        if (napi_get_value_string_utf8(env, args[0], host, sizeof(host), &length) != napi_ok || length >= sizeof(host) - 1)
            throw std::runtime_error("Invalid peer address");
        const int port = integer(env, args[1]); if (port < 1 || port > 65535) throw std::runtime_error("Invalid peer port");
        sockaddr_storage address{}; int addressSize;
        if (std::strchr(host, ':')) {
            auto& target = *reinterpret_cast<sockaddr_in6*>(&address); target.sin6_family = AF_INET6; target.sin6_port = htons(port);
            if (char* scope = std::strchr(host, '%')) {
                *scope++ = '\0'; const std::string zone(scope);
                if (zone.empty()) throw std::runtime_error("Invalid IPv6 scope");
                if (zone.find_first_not_of("0123456789") == std::string::npos) {
                    const auto index = std::stoull(zone);
                    if (index > 0xffffffffULL) throw std::runtime_error("Invalid IPv6 scope");
                    target.sin6_scope_id = static_cast<uint32_t>(index);
                } else {
                    target.sin6_scope_id = if_nametoindex(scope);
                    if (!target.sin6_scope_id) throw std::runtime_error("Unknown IPv6 interface");
                }
            }
            if (inet_pton(AF_INET6, host, &target.sin6_addr) != 1) throw std::runtime_error("Invalid IPv6 peer address");
            addressSize = sizeof(target);
        } else {
            auto& target = *reinterpret_cast<sockaddr_in*>(&address); target.sin_family = AF_INET; target.sin_port = htons(port);
            if (inet_pton(AF_INET, host, &target.sin_addr) != 1) throw std::runtime_error("Invalid IPv4 peer address");
            addressSize = sizeof(target);
        }
        auto connection = std::make_shared<Connection>(); connection->id = ++nextId; connection->ip = host;
        connection->fd = socket(address.ss_family, SOCK_STREAM, 0);
        if (connection->fd == invalidSocket) throw std::runtime_error("TCP socket creation failed");
#ifdef _WIN32
        u_long nonblocking = 1;
        if (ioctlsocket(connection->fd, FIONBIO, &nonblocking) != 0) throw std::runtime_error("TCP nonblocking setup failed");
#else
        const int flags = fcntl(connection->fd, F_GETFL, 0);
        if (flags < 0 || fcntl(connection->fd, F_SETFL, flags | O_NONBLOCK) != 0) throw std::runtime_error("TCP nonblocking setup failed");
#endif
        napi_value name; napi_create_string_utf8(env, "AloeTCPClient", NAPI_AUTO_LENGTH, &name);
        { std::lock_guard<std::mutex> lock(registryMutex);
          if (connections.size() >= 64) throw std::runtime_error("TCP connection limit reached");
          if (napi_create_threadsafe_function(env, args[2], nullptr, name, 4, 1, nullptr, nullptr, nullptr, dispatch, &connection->callback) != napi_ok)
              throw std::runtime_error("TCP callback creation failed");
          connections[connection->id] = connection; }
        try { std::thread([connection, address, addressSize] {
            bool connected = false;
            if (!connection->stopped) {
                const int result = connect(connection->fd, reinterpret_cast<const sockaddr*>(&address), addressSize);
                connected = result == 0;
#ifdef _WIN32
                const bool pending = result < 0 && WSAGetLastError() == WSAEWOULDBLOCK;
#else
                const bool pending = result < 0 && (errno == EINPROGRESS || errno == EINTR);
#endif
                const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
                while (!connected && pending && !connection->stopped && std::chrono::steady_clock::now() < deadline) {
                    if (ready(connection->fd, true) <= 0) continue;
                    int error = 0;
#ifdef _WIN32
                    int size = sizeof(error);
#else
                    socklen_t size = sizeof(error);
#endif
                    connected = getsockopt(connection->fd, SOL_SOCKET, SO_ERROR, reinterpret_cast<char*>(&error), &size) == 0 && error == 0;
                    break;
                }
            }
            if (connected && !connection->stopped) {
                auto event = new Event(); event->kind = "connect"; event->id = connection->id; event->ip = connection->ip;
                emit(connection->callback, event); readLoop(connection);
            } else {
                if (!connection->stopped) {
                    auto error = new Event(); error->kind = "error"; error->id = connection->id; error->error = "TCP connection failed or timed out";
                    emit(connection->callback, error);
                }
                connection->stop();
                auto event = new Event(); event->kind = "close"; event->id = connection->id; emit(connection->callback, event);
                napi_release_threadsafe_function(connection->callback, napi_tsfn_release);
            }
        }).detach(); } catch (...) {
            { std::lock_guard<std::mutex> lock(registryMutex); connections.erase(connection->id); }
            connection->stop(); napi_release_threadsafe_function(connection->callback, napi_tsfn_abort); throw;
        }
        napi_value result; napi_create_int32(env, connection->id, &result); return result;
    } catch (const std::exception& error) { napi_throw_error(env, nullptr, error.what()); return nullptr; }
}
napi_value tcpListen(napi_env env, napi_callback_info info) {
    size_t count = 3; napi_value args[3]; napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    try {
        if (count != 3) throw std::runtime_error("Expected listen address, port and callback");
#ifdef _WIN32
        static const bool initialized = [] { WSADATA data; return WSAStartup(MAKEWORD(2, 2), &data) == 0; }();
        if (!initialized) throw std::runtime_error("Socket initialization failed");
#endif
        char host[128]; size_t length = 0;
        if (napi_get_value_string_utf8(env, args[0], host, sizeof(host), &length) != napi_ok) throw std::runtime_error("Invalid listen address");
        const int port = integer(env, args[1]); if (port < 1 || port > 65535) throw std::runtime_error("Invalid listen port");
        auto server = std::make_shared<Server>(); server->id = ++nextId;
        server->fd = socket(AF_INET, SOCK_STREAM, 0);
        if (server->fd == invalidSocket) throw std::runtime_error("Socket creation failed");
        const int reuse = 1; setsockopt(server->fd, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char*>(&reuse), sizeof(reuse));
        sockaddr_in address{}; address.sin_family = AF_INET; address.sin_port = htons(static_cast<unsigned short>(port));
        if (inet_pton(AF_INET, host, &address.sin_addr) != 1 || bind(server->fd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0 || listen(server->fd, 16) != 0) {
            closeSocket(server->fd); throw std::runtime_error("TCP listen failed (address or port unavailable)");
        }
        napi_value name; napi_create_string_utf8(env, "AloePullTCP", NAPI_AUTO_LENGTH, &name);
        if (napi_create_threadsafe_function(env, args[2], nullptr, name, 64, 1, nullptr, nullptr, nullptr, dispatch, &server->callback) != napi_ok) {
            closeSocket(server->fd); throw std::runtime_error("TCP callback creation failed");
        }
        { std::lock_guard<std::mutex> lock(registryMutex); servers[server->id] = server; }
        try { std::thread([server] { acceptLoop(server); }).detach(); }
        catch (...) {
            { std::lock_guard<std::mutex> lock(registryMutex); servers.erase(server->id); }
            server->close(); napi_release_threadsafe_function(server->callback, napi_tsfn_abort); throw;
        }
        napi_value result; napi_create_int32(env, server->id, &result); return result;
    } catch (const std::exception& error) { napi_throw_error(env, nullptr, error.what()); return nullptr; }
}
napi_value tcpRead(napi_env env, napi_callback_info info) {
    size_t count = 1; napi_value arg; napi_get_cb_info(env, info, &count, &arg, nullptr, nullptr);
    try {
        auto connection = lookup(integer(env, arg));
        { std::lock_guard<std::mutex> lock(connection->mutex); connection->credit = true; }
        connection->condition.notify_one();
    } catch (const std::exception&) { /* A queued close event may race a read acknowledgement. */ }
    return nullptr;
}
napi_value tcpClose(napi_env env, napi_callback_info info) {
    size_t count = 1; napi_value arg; napi_get_cb_info(env, info, &count, &arg, nullptr, nullptr);
    try {
        const int id = integer(env, arg); std::shared_ptr<Connection> connection;
        { std::lock_guard<std::mutex> lock(registryMutex); auto found = connections.find(id);
          if (found != connections.end()) { connection = found->second; connections.erase(found); } }
        if (connection) connection->stop();
    } catch (const std::exception& error) { napi_throw_error(env, nullptr, error.what()); }
    return nullptr;
}
napi_value tcpStop(napi_env env, napi_callback_info info) {
    size_t count = 1; napi_value arg; napi_get_cb_info(env, info, &count, &arg, nullptr, nullptr);
    try {
        const int id = integer(env, arg); std::shared_ptr<Server> server;
        { std::lock_guard<std::mutex> lock(registryMutex); const auto found = servers.find(id);
          if (found == servers.end()) return nullptr;
          server = found->second; servers.erase(found); server->stop();
          for (auto item = connections.begin(); item != connections.end();) {
              if (item->second->owner == id) { item->second->stop(); item = connections.erase(item); } else ++item;
          } }
        // stop and close share the server socket mutex, preventing shutdown
        // from touching a reused descriptor after the accept thread exits.
    } catch (const std::exception& error) { napi_throw_error(env, nullptr, error.what()); }
    return nullptr;
}
struct WriteWork {
    napi_async_work work = nullptr; napi_deferred deferred = nullptr;
    std::shared_ptr<Connection> connection;
    std::vector<unsigned char> bytes; std::string error;
};
napi_value tcpSend(napi_env env, napi_callback_info info) {
    size_t count = 2; napi_value args[2]; napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    try {
        if (count != 2) throw std::runtime_error("Expected TCP handle and output buffer");
        auto work = std::make_unique<WriteWork>(); work->connection = lookup(integer(env, args[0]));
        void* data = nullptr; size_t length = 0;
        if (napi_get_arraybuffer_info(env, args[1], &data, &length) != napi_ok || length > 2 * 1024 * 1024) throw std::runtime_error("Invalid TCP output buffer");
        if (length) work->bytes.assign(static_cast<unsigned char*>(data), static_cast<unsigned char*>(data) + length);
        napi_value promise, name;
        if (napi_create_promise(env, &work->deferred, &promise) != napi_ok) throw std::runtime_error("TCP promise creation failed");
        napi_create_string_utf8(env, "AloeTCPSend", NAPI_AUTO_LENGTH, &name);
        const napi_status created = napi_create_async_work(env, nullptr, name, [](napi_env, void* raw) {
            auto& work = *static_cast<WriteWork*>(raw); std::lock_guard<std::mutex> lock(work.connection->sendMutex);
            size_t offset = 0;
            while (offset < work.bytes.size() && !work.connection->stopped) {
                // Never rely on shutdown interrupting a blocking send. A peer
                // can stop reading with a full window; cancellation must still
                // release this worker and every queued write promptly.
                const int available = ready(work.connection->fd, true);
                if (available == 0 || (available < 0 && wouldBlock())) continue;
                if (available < 0 || work.connection->stopped) break;
#ifdef _WIN32
                const int flags = 0;
#else
                const int flags = MSG_NOSIGNAL;
#endif
                const int sent = send(work.connection->fd, reinterpret_cast<const char*>(work.bytes.data() + offset), static_cast<int>(work.bytes.size() - offset), flags);
                if (sent < 0 && wouldBlock()) continue;
                if (sent <= 0) break; offset += sent;
            }
            if (offset != work.bytes.size()) work.error = "TCP send interrupted";
        }, [](napi_env env, napi_status status, void* raw) {
            std::unique_ptr<WriteWork> work(static_cast<WriteWork*>(raw)); napi_value result;
            if (status != napi_ok || !work->error.empty()) {
                napi_value message; napi_create_string_utf8(env, work->error.empty() ? "TCP send cancelled" : work->error.c_str(), NAPI_AUTO_LENGTH, &message);
                napi_create_error(env, nullptr, message, &result); napi_reject_deferred(env, work->deferred, result);
            } else { napi_get_undefined(env, &result); napi_resolve_deferred(env, work->deferred, result); }
            napi_delete_async_work(env, work->work);
        }, work.get(), &work->work);
        if (created != napi_ok || napi_queue_async_work(env, work->work) != napi_ok) {
            napi_value message, error;
            napi_create_string_utf8(env, "TCP send scheduling failed", NAPI_AUTO_LENGTH, &message);
            napi_create_error(env, nullptr, message, &error); napi_reject_deferred(env, work->deferred, error);
            if (work->work) napi_delete_async_work(env, work->work);
            return promise;
        }
        work.release(); return promise;
    } catch (const std::exception& error) { napi_throw_error(env, nullptr, error.what()); return nullptr; }
}
}

void registerPullTcp(napi_env env, napi_value exports) {
    const napi_property_descriptor functions[] = {
        {"tcpConnect", nullptr, tcpConnect, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"tcpListen", nullptr, tcpListen, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"tcpRead", nullptr, tcpRead, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"tcpSend", nullptr, tcpSend, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"tcpClose", nullptr, tcpClose, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"tcpStop", nullptr, tcpStop, nullptr, nullptr, nullptr, napi_default, nullptr}};
    napi_define_properties(env, exports, sizeof(functions) / sizeof(functions[0]), functions);
}
