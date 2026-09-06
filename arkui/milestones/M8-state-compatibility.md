# M8 — state updates and compatibility

- Version code 2000008; `artifacts/AloeSend-2000008-M8-state-compatibility-unsigned.hap`.
- SHA256: `96B10EE5AAA1C3019EC7CCF2D9A86BD1DC4E1049870894A76E852312F73FA070`.
- Transfer/file/peer/conversation list identities include changed display data so plain snapshots do not leave retained ArkUI nodes stale.
- Message composer checks its own transfer when deciding whether to clear the draft, even if other tasks finish concurrently.
- Correct legacy routes from `common/lib/api_route_builder.dart`: v1 `send-request` and `send`, token-map response, cancellation and v2-to-v1 fallback.
- Streamed text creates real message history; PIN lockout expires after five minutes; bounded concurrent sends and retained retry contexts.
- Local-address enumeration failure no longer stops an otherwise usable server.
- Validation: unsigned build, 15 service interoperability groups and conversation tests passed. Native UI runtime remains deferred per user instruction.
- Build defaults preserve the current version code. `record-milestone.ps1` validates archived hashes and records the milestone commit after committing; the pre-build revision is retained separately as `baseCommit`.
