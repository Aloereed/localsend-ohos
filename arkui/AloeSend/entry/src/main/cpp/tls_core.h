#pragma once
#include <mbedtls/ssl.h>
#include <mbedtls/entropy.h>
#include <mbedtls/ctr_drbg.h>
#include <mbedtls/error.h>
#include <psa/crypto.h>
#include <algorithm>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace aloe {
inline void check(int result) {
    if (result >= 0) return;
    char error[160] = {};
    mbedtls_strerror(result, error, sizeof(error));
    throw std::runtime_error(std::string("TLS: ") + error);
}
struct Server {
    mbedtls_ssl_config config;
    mbedtls_x509_crt certificate;
    mbedtls_pk_context key;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context random;
    Server() {
        mbedtls_ssl_config_init(&config); mbedtls_x509_crt_init(&certificate);
        mbedtls_pk_init(&key); mbedtls_entropy_init(&entropy); mbedtls_ctr_drbg_init(&random);
    }
    ~Server() {
        mbedtls_ssl_config_free(&config); mbedtls_x509_crt_free(&certificate);
        mbedtls_pk_free(&key); mbedtls_ctr_drbg_free(&random); mbedtls_entropy_free(&entropy);
    }
    void init(const std::string& cert, const std::string& pemKey, bool client = false) {
        check(psa_crypto_init());
        const std::string personal = client ? "AloeSend TLS client" : "AloeSend TLS server";
        check(mbedtls_ctr_drbg_seed(&random, mbedtls_entropy_func, &entropy,
              reinterpret_cast<const unsigned char*>(personal.data()), personal.size()));
        if (!client) {
            check(mbedtls_x509_crt_parse(&certificate, reinterpret_cast<const unsigned char*>(cert.c_str()), cert.size() + 1));
            check(mbedtls_pk_parse_key(&key, reinterpret_cast<const unsigned char*>(pemKey.c_str()), pemKey.size() + 1,
                  nullptr, 0, mbedtls_ctr_drbg_random, &random));
        }
        check(mbedtls_ssl_config_defaults(&config, client ? MBEDTLS_SSL_IS_CLIENT : MBEDTLS_SSL_IS_SERVER, MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT));
        mbedtls_ssl_conf_rng(&config, mbedtls_ctr_drbg_random, &random);
        // LocalSend authenticates known peers using certificate fingerprints.
        // Client certificates are not required by its transfer protocol.
        mbedtls_ssl_conf_authmode(&config, MBEDTLS_SSL_VERIFY_NONE);
        if (!client) check(mbedtls_ssl_conf_own_cert(&config, &certificate, &key));
    }
};
struct Session {
    std::shared_ptr<Server> server;
    mbedtls_ssl_context ssl;
    std::vector<unsigned char> input, output;
    size_t consumed = 0;
    bool ready = false, closed = false;
    explicit Session(std::shared_ptr<Server> owner) : server(std::move(owner)) { mbedtls_ssl_init(&ssl); }
    ~Session() { mbedtls_ssl_free(&ssl); }
    void init() { check(mbedtls_ssl_setup(&ssl, &server->config)); mbedtls_ssl_set_bio(&ssl, this, send, recv, nullptr); }
    static int recv(void* context, unsigned char* bytes, size_t size) {
        auto& self = *static_cast<Session*>(context);
        const size_t count = std::min(size, self.input.size() - self.consumed);
        if (!count) return MBEDTLS_ERR_SSL_WANT_READ;
        std::memcpy(bytes, self.input.data() + self.consumed, count); self.consumed += count;
        return static_cast<int>(count);
    }
    static int send(void* context, const unsigned char* bytes, size_t size) {
        auto& self = *static_cast<Session*>(context);
        if (self.output.size() + size > 2 * 1024 * 1024) return MBEDTLS_ERR_SSL_ALLOC_FAILED;
        self.output.insert(self.output.end(), bytes, bytes + size); return static_cast<int>(size);
    }
    std::vector<unsigned char> feed(const unsigned char* bytes, size_t size) {
        if (closed || size > 1024 * 1024 || input.size() - consumed + size > 2 * 1024 * 1024)
            throw std::runtime_error("Invalid TLS input state or size");
        if (consumed) { input.erase(input.begin(), input.begin() + consumed); consumed = 0; }
        if (size) input.insert(input.end(), bytes, bytes + size);
        if (!ready) {
            int result = mbedtls_ssl_handshake(&ssl);
            if (result == MBEDTLS_ERR_SSL_WANT_READ) return {};
            check(result); ready = true;
        }
        std::vector<unsigned char> plain;
        unsigned char buffer[16384];
        while (true) {
            int count = mbedtls_ssl_read(&ssl, buffer, sizeof(buffer));
            if (count == MBEDTLS_ERR_SSL_WANT_READ) break;
            if (count == 0 || count == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) { closed = true; break; }
            check(count);
            plain.insert(plain.end(), buffer, buffer + count);
            if (plain.size() > 2 * 1024 * 1024) throw std::runtime_error("TLS plaintext limit exceeded");
        }
        if (consumed == input.size()) { input.clear(); consumed = 0; }
        return plain;
    }
    void write(const unsigned char* bytes, size_t size) {
        if (!ready || closed || size > 1024 * 1024) throw std::runtime_error("TLS connection is not writable");
        size_t offset = 0;
        while (offset < size) {
            int count = mbedtls_ssl_write(&ssl, bytes + offset, std::min(size - offset, size_t(16384)));
            check(count); if (!count) throw std::runtime_error("TLS write made no progress"); offset += count;
        }
    }
    void shutdown() {
        if (ready && !closed) check(mbedtls_ssl_close_notify(&ssl));
        closed = true;
    }
};
}
