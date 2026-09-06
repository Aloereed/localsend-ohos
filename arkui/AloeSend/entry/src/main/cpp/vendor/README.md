# Mbed TLS 3.6.7

Unmodified `include`, `library` and `3rdparty` directories from the official release:
https://github.com/Mbed-TLS/mbedtls/releases/tag/mbedtls-3.6.7

Archive: `mbedtls-3.6.7.tar.bz2`
SHA-256: `a7e8bcbec0e6f761b4af24f25677626b35f762f68eef79c08677a363212d11f6`

License: `MBEDTLS-LICENSE`, with third-party notices retained in their original directories.
The application uses this maintained LTS version for TLS 1.2/1.3 binary reception,
avoiding the HarmonyOS 6.1 TLSSocketServer `RecvRemoteInfo` / `__strlen_chk` abort
observed in device faultlog on 2026-09-07. Certificates retain their existing identity.

Both the HarmonyOS NAPI library and Windows Node NAPI regression module compile
the same `tls_core.h`, `tls_bridge.cpp` and vendored library sources. Host adapter
tests use real TLS against Node/OpenSSL; they do not mock cryptographic operations.
