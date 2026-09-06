#include "tls_core.h"
#include <napi/native_api.h>
#include <map>
#include <functional>

namespace {
std::map<int, std::shared_ptr<aloe::Server>> servers;
std::map<int, std::unique_ptr<aloe::Session>> sessions;
int nextId = 0;
int integer(napi_env env, napi_value value) {
    int32_t result; if (napi_get_value_int32(env, value, &result) != napi_ok) throw std::runtime_error("Expected TLS handle"); return result;
}
napi_value number(napi_env env, int value) { napi_value result; napi_create_int32(env, value, &result); return result; }
std::string string(napi_env env, napi_value value) {
    size_t size = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &size) != napi_ok || size > 65536) throw std::runtime_error("Invalid PEM");
    std::vector<char> bytes(size + 1); napi_get_value_string_utf8(env, value, bytes.data(), bytes.size(), &size);
    return std::string(bytes.data(), size);
}
napi_value buffer(napi_env env, const std::vector<unsigned char>& bytes) {
    void* data; napi_value result; if (napi_create_arraybuffer(env, bytes.size(), &data, &result) != napi_ok) throw std::runtime_error("TLS output allocation failed");
    if (!bytes.empty()) std::memcpy(data, bytes.data(), bytes.size()); return result;
}
napi_value invoke(napi_env env, napi_callback_info info, const std::function<napi_value(napi_value*)>& fn) {
    napi_value args[2] = {}; size_t count = 2;
    napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    try { return fn(args); } catch (const std::exception& error) { napi_throw_error(env, nullptr, error.what()); return nullptr; }
}
napi_value createServer(napi_env env, napi_callback_info info) {
    return invoke(env, info, [&](napi_value* args) {
        if (servers.size() >= 4) throw std::runtime_error("TLS server limit reached");
        auto server = std::make_shared<aloe::Server>(); server->init(string(env, args[0]), string(env, args[1]));
        const int id = ++nextId; servers[id] = server; return number(env, id);
    });
}
napi_value createSession(napi_env env, napi_callback_info info) {
    return invoke(env, info, [&](napi_value* args) {
        if (sessions.size() >= 64) throw std::runtime_error("TLS connection limit reached");
        auto server = servers.find(integer(env, args[0])); if (server == servers.end()) throw std::runtime_error("TLS server stopped");
        auto session = std::make_unique<aloe::Session>(server->second); session->init();
        const int id = ++nextId; sessions[id] = std::move(session); return number(env, id);
    });
}
napi_value process(napi_env env, napi_callback_info info, bool writing) {
    return invoke(env, info, [&](napi_value* args) {
        auto found = sessions.find(integer(env, args[0])); if (found == sessions.end()) throw std::runtime_error("TLS connection closed");
        void* bytes = nullptr; size_t size = 0;
        if (napi_get_arraybuffer_info(env, args[1], &bytes, &size) != napi_ok) throw std::runtime_error("Expected ArrayBuffer");
        auto& session = *found->second;
        std::vector<unsigned char> plain;
        if (writing) session.write(static_cast<unsigned char*>(bytes), size); else plain = session.feed(static_cast<unsigned char*>(bytes), size);
        napi_value result; napi_create_object(env, &result);
        napi_set_named_property(env, result, "plain", buffer(env, plain));
        napi_set_named_property(env, result, "wire", buffer(env, session.output)); session.output.clear();
        napi_value closed; napi_get_boolean(env, session.closed, &closed); napi_set_named_property(env, result, "closed", closed);
        return result;
    });
}
napi_value feed(napi_env env, napi_callback_info info) { return process(env, info, false); }
napi_value write(napi_env env, napi_callback_info info) { return process(env, info, true); }
napi_value closeSession(napi_env env, napi_callback_info info) { return invoke(env, info, [&](napi_value* args) { sessions.erase(integer(env, args[0])); return number(env, 0); }); }
napi_value closeServer(napi_env env, napi_callback_info info) { return invoke(env, info, [&](napi_value* args) { servers.erase(integer(env, args[0])); return number(env, 0); }); }
napi_value init(napi_env env, napi_value exports) {
    const napi_property_descriptor functions[] = {
        {"createServer", nullptr, createServer, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"createSession", nullptr, createSession, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"feed", nullptr, feed, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"write", nullptr, write, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"closeSession", nullptr, closeSession, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"closeServer", nullptr, closeServer, nullptr, nullptr, nullptr, napi_default, nullptr}};
    napi_define_properties(env, exports, sizeof(functions) / sizeof(functions[0]), functions); return exports;
}
napi_module module = {1, 0, nullptr, init, "aloetls", nullptr, {0}};
}
extern "C" __attribute__((constructor)) void registerAloeTls() { napi_module_register(&module); }
