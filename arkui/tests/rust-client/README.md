# Manual HTTPS interoperability probe

This optional host tool uses reqwest/rustls, the HTTP/TLS family used by Windows
LocalSend 1.16.1 through rhttp. It is separate from the automated Node tests.

Build with `cargo build --manifest-path arkui/tests/rust-client/Cargo.toml
--target-dir arkui/logs/rust-client-target` (put the command on one line).
Run the resulting executable with a localhost service URL. The default operation
makes diagnostic GET requests. `--upload --mib 128` prepares a LocalSend session
and streams a generated file; this writes a file to the selected receiver and
requires that receiver to accept it. Use only an authorized test receiver.

The default bypasses environment proxies, accepts the receiver's self-signed
certificate, and does not print session credentials. `--system-proxy` enables
reqwest's normal proxy selection. This diagnostic setting does not change the
application's certificate or proxy behavior.

The adjacent `../dart_https_probe.dart` exercises Dart's HttpClient separately;
it does not reproduce the Rust HTTP stack used by that Windows LocalSend release.
