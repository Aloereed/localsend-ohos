# M7 — conversations and receive consent

- Version code 2000007; `artifacts/AloeSend-2000007-M7-conversations-unsigned.hap`.
- SHA256: `AB16B3EC6754FBCD8B0685E82D228FE1631755E11CE22E300E566B3AC372A09C`.
- Replaced the message-history-only tab with device conversations, reply composer, attached-file sending, in-conversation search, record actions and conversation management.
- History retains device identity/address snapshots. Conversation grouping follows fingerprints across address/name changes and separates same-name devices; old history remains available.
- Incoming consent displays text previews and provides select-all/invert and safe per-file rename before acceptance.
- Validation: native unsigned build passed; 14 service integration groups plus identity/history conversation tests passed.
- Native visual interaction is deferred to the user's morning deployment. No signing, deployment or further DevEco UI interaction was performed.
