# M5 — system workflows

- Version code: 2000005. Unsigned debug HAP: `artifacts/AloeSend-2000005-M5-system-workflows-unsigned.hap`.
- SHA256: `A57998AC1016B4B5078A5571B9FD660242F4B65071F79FCFEF5E0E058EEF3662`.
- Native single/multiple recipient selection; sequential queue cancellation; retry only unfinished files.
- System ShareKit file/text import on cold and warm launch. Files are copied to app cache while URI grants are valid.
- Data-transfer background task requested only while a transfer is active; platform failure is recorded in diagnostics.
- Browser downloads can be cancelled through transfer UI. Settings initialization is shared across lifecycle/page entry.
- Validation: unsigned Hvigor build passed; 13 service interoperability groups and six browser groups passed against independent Node clients/servers; zero leaked file handles.
- Device ShareKit routing, background task authorization, and actual ArkUI layout still require native runtime validation. Host tests exercise unchanged application logic with OS primitives adapted, and do not prove those device behaviors.
