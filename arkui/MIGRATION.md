# AloeSend ArkUI migration

Started 2026-09-06 21:30 CST. Six-hour work window ends approximately 2026-09-07 03:30 CST.
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
implementation evidence as of M26:

| Flutter flow | Native implementation | Evidence / remaining checks |
| --- | --- | --- |
| Receive, receive options | Index, ReceiveRequest, TransferList, LocalSendService | Consent/progress, selection and renaming tested; device authorization and progress appearance need M21+ retest. |
| Send, selected files | SendView, PeerDetail, AppStore | Five input types, editing and batch send implemented; OS file/photo/folder pickers need device coverage. |
| Discovery and favorites | LocalSendService, SendView, SettingsView | Automatic discovery schedule, manual addresses and identity matching covered by host tests. |
| Progress | TransferList, NativeServer, SecureServer | Cancel/retry/queue and 128 MiB real TLS upload verified; system background behavior remains device-dependent. |
| Messages and history | MessagesView, LibraryView, FileDetailsView | Search, conversation isolation, open/export/share, metadata, favorite conversation targets and public folder reveal implemented; system interactions need device confirmation. |
| Browser sharing | WebShareView, WebShareService, WebPage | Real HTTP consent, upload/download, PIN, cancellation and resource tests pass. |
| Settings and appearance | SettingsView, Locale, AppStore | Chinese/English/system, colors, theme, animations, reduced effects, OLED background, receive and network controls implemented; original extra theme presets and full translation coverage not claimed. |
| Help, privacy, credits, diagnostics | Index information routes, PrivacyView and SettingsView | Native routes and first-launch privacy flow implemented; developer-only screens need final parity review. |
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
