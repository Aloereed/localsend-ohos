# M1 — Native foundation

2026-09-06. Version code 2000001. Native ArkUI, Debug compilation, unsigned.

Build: `arkui/build.ps1 -Milestone M1-foundation -VersionCode 2000001`.
Result: Hvigor BUILD SUCCESSFUL; unsigned HAP timestamp refreshed.
Artifact: `arkui/artifacts/AloeSend-2000001-M1-foundation-unsigned.hap`.
SHA256: `1DCD251106CE4312C0ACED62A93E056DBD7199B07B76656DB47BE2F3F6EBEC1C`.

Implemented: four native tabs, system light/dark color resources, constrained tablet content
width, preferences-backed device alias and receive/history settings, signing-free build/archive.

Known limitations: foundation only. Networking, selection, history and other functional
screens are not yet implemented. No device runtime claim; package has not been signed/installed.
Prefer newer milestones for actual use.
