# M3 — Native LocalSend protocol and transfer UI

2026-09-06. Version 2000003. Debug compilation, unsigned.
Artifact: `arkui/artifacts/AloeSend-2000003-M3-protocol-unsigned.hap`.
SHA256: `CCB73E6837A5298D7E228BF2D4572E2AE78698965BDE7F1DEB97B6B6869BE94F`.
Hvigor BUILD SUCCESSFUL; canonical HAP refreshed.

Implemented: native UDP discovery/register/manual address; per-install RSA TLS identity;
certificate fingerprint checks; LocalSend v2 prepare/upload/cancel and v1 receive routes;
receive consent and per-file selection; PIN; binary streaming; incoming checksum checking;
message preview receipt; history; progress/speed/ETA and cancellation cleanup; duplicate-name
protection. TLS enabled by default, including upgrades from older native preference formats.

Verification:
- 10 protocol test groups: framing boundaries/chunked data, malformed framing, path traversal,
  duplicate names and HTML escaping.
- Certificate DER signed with independent Node/OpenSSL RSA implementation: signature, subject,
  validity and server/client EKUs validated, including dates after 2050.
- 12 integration groups run unchanged ArkTS service/business sources with host adapters for
  OS sockets/files/crypto: real HTTPS requests, pinning failure, registration, binary upload
  and SHA256, invalid tokens/replay, traversal, bad checksum cleanup, mid-upload cancellation,
  consent, PIN, text history and outbound transfer to an independent Node HTTP receiver.
- Zero leaked file handles after the integration suite.

Limitations: host adapters validate network/business behavior, not HarmonyOS ABI or device UI.
Package remains unsigned and uninstalled. Browser sharing, automatic lifecycle recovery,
retry/multi-target refinements and remaining settings/platform parity continue in later milestones.
