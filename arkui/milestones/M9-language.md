# M9 — native interface localization

- Version code 2000009; `artifacts/AloeSend-2000009-M9-language-unsigned.hap`.
- SHA256: `E8C02581EED80F2AD6A7D7A55DDF6FF25D3925AD68AB8183DC38403D726105CE`.
- Settings offer Simplified Chinese, English and system language. Existing installs retain their selected language.
- Shared translation catalog covers native navigation, forms, settings, history/conversations, consent, browser-share controls, help and parameterized labels.
- User-authored messages, filenames and device names remain verbatim. Low-level diagnostics and unrecognized platform errors retain their original text.
- Validation: unsigned native build and locale/parameter substitution tests passed. Device UI review remains assigned to the user's morning deployment.
- The browser-delivered HTML remains Chinese in this milestone; native language selection does not currently select a browser language.
