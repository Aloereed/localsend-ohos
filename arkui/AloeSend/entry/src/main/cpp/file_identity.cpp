#include <napi/native_api.h>
#include <string>
#ifdef _WIN32
#include <windows.h>
#else
#include <sys/stat.h>
#endif

namespace {
napi_value identity(napi_env env, napi_callback_info info) {
    size_t count = 1; napi_value args[1]; int32_t fd = -1;
    napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    if (count != 1 || napi_get_value_int32(env, args[0], &fd) != napi_ok || fd < 0) {
        napi_throw_error(env, nullptr, "Invalid file descriptor"); return nullptr;
    }
    std::string key;
#ifdef _WIN32
    BY_HANDLE_FILE_INFORMATION data{};
    // Host tests use Node's CRT descriptor table, not MinGW's separate table.
    using GetHandle = HANDLE (*)(int);
    const auto getHandle = reinterpret_cast<GetHandle>(GetProcAddress(GetModuleHandleW(nullptr), "uv_get_osfhandle"));
    if (!getHandle) { napi_throw_error(env, nullptr, "Node file handle API unavailable"); return nullptr; }
    const auto handle = getHandle(fd);
    if (handle == INVALID_HANDLE_VALUE || !GetFileInformationByHandle(handle, &data)) {
        napi_throw_error(env, nullptr, "Could not read file identity"); return nullptr;
    }
    key = std::to_string(data.dwVolumeSerialNumber) + ":" + std::to_string(data.nFileIndexHigh) + ":" + std::to_string(data.nFileIndexLow);
#else
    struct stat data{};
    if (fstat(fd, &data) != 0) {
        napi_throw_error(env, nullptr, "Could not read file identity"); return nullptr;
    }
    key = std::to_string(static_cast<unsigned long long>(data.st_dev)) + ":" + std::to_string(static_cast<unsigned long long>(data.st_ino));
#endif
    napi_value result; napi_create_string_utf8(env, key.c_str(), key.size(), &result); return result;
}
}

void registerFileIdentity(napi_env env, napi_value exports) {
    const napi_property_descriptor descriptor = {"fileIdentity", nullptr, identity, nullptr, nullptr, nullptr, napi_default, nullptr};
    napi_define_properties(env, exports, 1, &descriptor);
}
