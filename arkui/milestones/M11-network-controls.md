# M11 — network controls

- Version code 2000011; `artifacts/AloeSend-2000011-M11-network-controls-unsigned.hap`.
- SHA256: `994F456A95616D4866C40155383BC54B4B95E9441D5A7D6222673F11670318DF`.
- Native network-interface screen with include/exclude wildcard rules, current addresses and applied state.
- Rules filter automatic discovery/address presentation, not inbound service access; the interface explicitly explains this distinction.
- Configurable device model and discovery timeout. Discovery requests use that timeout while transfer consent retains its longer timeout.
- Validated IPv4 and bracketed/bare IPv6 manual input including scoped addresses. Outgoing native transport supports IPv6; multicast discovery and the receive listener remain IPv4 in this milestone.
- Validation: unsigned build; address/filter/subnet tests; 16 service groups including real host IPv6 traffic and timeout cancellation passed.
- No device deployment or DevEco interaction. Actual native network-interface enumeration remains for the morning check.
