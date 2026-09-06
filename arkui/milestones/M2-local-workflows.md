# M2 — Native local workflows

2026-09-06. Version code 2000002. Debug compilation, unsigned.
Build: `arkui/build.ps1 -Milestone M2-local-workflows -VersionCode 2000002`.
Result: Hvigor BUILD SUCCESSFUL. Archive:
`arkui/artifacts/AloeSend-2000002-M2-local-workflows-unsigned.hap`.
SHA256: `2C63E6596AB24C436BF71862D3DCD0162ED5F316DD7FA800EBD39C60A7830CB6`.

Implemented native services and views: file/photo/folder selection; selection list with
size/type, remove/clear and outbound-only rename; text/link composition; explicit clipboard
permission; persistent settings, theme mode/accent, favorites and history model; message/file
history filtering, copy/resend/delete/clear, open/export; help/privacy/about/logs pages.

No synthetic devices or history. Network and web actions explicitly state that their services
are not yet connected. History population will be verified alongside real transfers in M3.
System document-folder selection depends on device capability and errors are surfaced.
Native build/type/resource validation passed; system picker and UI behavior are not yet
verified on a device because this package is unsigned. Prefer newer milestones.
