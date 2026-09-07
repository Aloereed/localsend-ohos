# AloeSend ArkUI migration

Started 2026-09-06 21:30 CST. Latest user-authorized continuation: 2026-09-07 approximately 09:30–15:30 CST; early completion allowed after the work is done. The user has left with the device: do not access it. Continue source, host-test and unsigned-build milestones.
Source baseline: f341 / 227d25dc. Upstream reference: main / 6279d3e3.

## Contract

Reimplement all user-facing Flutter features in native ArkUI, with HarmonyOS navigation,
typography, spacing, adaptive layout, system file selection and accessibility. Preserve
Flutter sources. Native service implementation must use the LocalSend protocol and be
verified against another implementation; UI presence alone is not feature completion.
Each milestone gets a Git commit and an archived unsigned HAP with matching metadata.
Do not sign or install packages without a new request. Never include signing credentials.

## Architecture

ArkUI frontend and ArkTS application state/platform services. Evaluate native protocol
implementation versus Rust reuse against actual toolchain and interoperability evidence.
Keep networking separated from views so backend changes do not require UI rewrites.
Use the existing bundle name; milestone version codes increase so newest can be installed
first. Downgrade may require uninstalling and would remove app data; preserve exported data.

## Feature acceptance inventory

The checkboxes below are final acceptance, not merely source presence. They remain
open until device verification and the remaining parity audit are complete. Current
implementation evidence through M112 (device checks are handed back to the user and do not authorize device access):

| Flutter flow | Native implementation | Evidence / remaining checks |
| --- | --- | --- |
| Receive, receive options | Index, ReceiveRequest, TransferList, LocalSendService | Consent/progress, selection, renaming and per-session gallery prompt tested; device authorization and progress appearance need M21+ retest. |
| Send, selected files | SendView, PeerDetail, AppStore | Five input types, editing, selected-file preview and batch send implemented; OS file/photo/folder pickers and viewer handoff need device coverage. |
| Discovery and favorites | LocalSendService, SendView, SettingsView | Automatic discovery schedule, manual addresses and identity matching covered by host tests. |
| Progress | TransferList, NativeServer, SecureServer, PullSocket/native TCP | M51: 3 GiB real TLS upload with a one-second disk stall, SHA-256 match and about 64 KiB application queue; M52: blocked-send cancellation and 12 immediate restart cycles. HTTP/HTTPS cancellation and immediate resend pass. Actual HarmonyOS large-file performance remains unverified. |
| Messages and history | MessagesView, LibraryView, FileDetailsView | M54–M57 retain live/terminal states and partial results, group file batches before search/pagination, count unread batches and support atomic resend/batch deletion. Private history, deletion during transfer and interrupted restart tested. System interactions and actual batch-sheet layout remain user device checks. |
| Browser sharing | WebShareView, WebShareService, WebPage | Real HTTP consent, upload/download, PIN, cancellation and resource tests pass. Full-screen QR/link presentation implemented; device visual check pending. |
| Settings and appearance | SettingsView, Locale, AppStore | M58 color presets, system-resource refresh, contrast and legacy preservation tested. Through M107: 53 locale variants, 98 mapped static labels and 8 dynamic templates, regional/script resolution and basic RTL. Native-only descriptions still fall back to English; full translation coverage and RTL interaction audit remain in progress. |
| Help, privacy, credits, diagnostics | Index information routes, PrivacyView, DiagnosticsView and SettingsView | M43 privacy content generated exactly from Flutter with a synchronization test. Native routes, searchable discovery/HTTP logs, certificate regeneration and preference restoration implemented. Refena tracing is Flutter-runtime-specific. |
| Upgrade and folder selection | FlutterImport, DownloadFolders, DownloadDirectoryPicker | M45 imports Flutter favorites/history/messages without modifying source data; rollback/retry and 1,100 records tested. M47/M53 custom Download directory picker covers missing capability and runtime unsupported errors. Overwrite upgrade/signature and authorization behavior need user device checks. |
| Legacy UI | Shared native flows | No duplicate legacy navigation shell; equivalent actions are consolidated. Final interaction audit pending. |
| Android/desktop-only actions | Platform scope | APK installed-app picker, desktop tray, autostart and shell integration are not HarmonyOS equivalents. |
| Upstream Rust rewrite | Preserved upstream reference | LocalSend interoperability is implemented; Rust-only WebRTC/pairing parity is not claimed. |

See `README.md` for morning checks and `PACKAGES.md` for verified archived packages.

- [ ] Receive: device identity, local addresses, visibility, receiving options and consent.
- [ ] Send: files, media, directories, text/link, clipboard, selection review, rename/remove.
- [ ] Discovery: multicast, manual address, refresh, favorites add/edit/remove and direct send.
- [ ] Transfers: single/multiple devices, selection, PIN, progress/speed/ETA, cancel/retry/errors.
- [ ] Messages: persistent conversation history, search, copy, resend, delete/clear.
- [ ] Receive history: metadata, open, reveal/export, delete/clear.
- [ ] Browser sharing: URL/QR, list/download, stop, access consent and settings.
- [ ] Settings: identity, language, appearance, animations, receive policies, destination,
      network/port/multicast/interfaces, encryption, history, automatic completion.
- [ ] Help: about, licenses, privacy, changelog, troubleshooting, diagnostics/logs.
- [ ] Platform: incoming share intents, lifecycle/background behavior, file permissions,
      system open/share, tablet/foldable/adaptive navigation, dark mode/accessibility.
- [ ] Existing modern and legacy Flutter flows represented by coherent native equivalents.
- [ ] Upstream additions inventory assessed without falsely claiming Rust-only parity.

## Milestones

1. Native foundation: reproducible unsigned build, navigation, design system, persistent state.
2. Local workflows: selection, messages/history/settings/details, native platform integrations.
3. Protocol: real discovery, sending/receiving with consent and progress, interoperability checks.
4. Completion: browser sharing, remaining screens, adaptive polish, regression and package audit.

## Verification and evidence

Record commands, outcomes, known limitations and package hashes in `milestones/`.
Unsigned HAPs cannot be runtime-installed on a normal device without signing. Build success
does not prove device runtime behavior. Keep that distinction explicit in milestone notes.


