# M4 — Browser sharing and device identity screens

2026-09-06. Version code 2000004. Native Debug HAP, unsigned.
Artifact: `arkui/artifacts/AloeSend-2000004-M4-web-sharing-unsigned.hap`.
SHA256: `CD8451F386DCC27BF9AFEE622EAB4701B41E925384A9422F65F9258734D938BF`.
Hvigor BUILD SUCCESSFUL, canonical artifact refreshed.

Implemented: independent HTTP/HTTPS browser server on the adjacent port; expiring capability
links and native QR code; file/text download; explicit native download authorization; browser
file chooser/drag-drop and text upload; PIN and native receive consent; stop/close invalidation.
Device detail, editable favorite labels, complete fingerprint display/copy and connection probe.
The main LocalSend TLS server remains enabled while HTTP browser sharing is active.

Verification: six host integration groups pass with actual HTTP sockets and unchanged ArkTS
business sources: escaped HTML, invalid capability and cross-origin POST, approved binary
download, rejected download, browser binary upload with PIN, pending-request/server shutdown.
Zero open file handles afterward. Host TCP adapter mapping was corrected while adding these tests.

Device runtime/UI still unverified because packages remain unsigned. Pending work includes
multi-target/retry refinements, lifecycle recovery, richer platform integration and final visual
and feature-parity audit. The browser page and native controls are real, not screenshots/mock data.
