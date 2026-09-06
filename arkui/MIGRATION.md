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
