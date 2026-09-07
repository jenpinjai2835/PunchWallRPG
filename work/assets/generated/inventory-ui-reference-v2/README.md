# Inventory Reference Chrome V2

Production-oriented UI chrome generated from the supplied Inventory screenshot
as a **style reference only**. The components contain no text or item artwork,
so Roblox-owned labels, icons, states, and accessibility targets remain native.

## Selected deliverables

| File | Size | Intended use | SHA-256 |
| --- | ---: | --- | --- |
| `inventory-ui-chrome-atlas-production-v2.png` | 1672x941 | Alpha atlas and visual source of truth | `F3C5C1C84061F04FB67523DF6000A226A10673A95C01F1DB402F4B4C768BB9E5` |
| `inventory-window-frame.png` | 597x430 | Desktop Inventory outer chrome and red header | `BBA92D6A7450C98B52D70D6544385CF836B2EDB03E03AC000A60B38882BDA3EA` |
| `inventory-nav-panel.png` | 262x415 | Left category rail | `65F2533F8A55E0CC6838246AABFD0339E9146815C4F5B80F0956AB71A233E181` |
| `inventory-filter-control.png` | 385x118 | Search, rarity, and capacity controls | `240B6FB7E4DC49B2E8492C87A6291E6E3E9F7F4C30B546CF95F82929C42FE772` |
| `inventory-item-card.png` | 300x301 | Reusable item-card chrome | `D23A00BF6DD92B187F361D9C24095FDC6DFB9BEF01CA6BF428A816F6F87BE3B1` |
| `inventory-detail-panel.png` | 324x429 | Selected-item detail pane | `08298231353FD85C44A990420CA2B41135936B40423BBD9521379BA17A8D6E24` |
| `inventory-primary-button.png` | 442x158 | Equip/use/confirm actions | `438E38748B5B1AA0EFF74D97FE1D36CDC03FDF65A57DF2994452F5326E9ED0EF` |
| `inventory-secondary-button.png` | 435x159 | Secondary actions | `76AF8E1ECC117C347DFE0B0C93EABB309EE1B29F98384734B13E14F4966DB0CE` |
| `inventory-close-button.png` | 216x183 | Close control chrome | `775414D0190E01016691E241DAC64A6F5AAC0A6FD27F4FD4993FA96EFCB89F02` |

Every selected PNG is RGBA with transparent corners. Keep
`inventory-ui-chrome-atlas-chroma.png` only as generation provenance. Other
atlas variants are post-processing experiments and are not runtime inputs.

## Roblox integration contract

1. Upload the nine selected production PNGs as project-owned Roblox image
   assets, record their IDs in `GameConfig`, and never depend on a local path at
   runtime.
2. Keep the existing native Frames, labels, controls, and focus order. Raster
   chrome is decorative and must use `Active=false`.
3. Use `ScaleType=Slice` for the nav, filter, card, detail, and button assets.
   Start with a 12% inset on each edge, then visually verify all accepted
   viewport and UI-scale cases before freezing exact `SliceCenter` values.
4. Treat the full window frame as desktop reference chrome only. Compact phone
   and tablet layouts must keep the native responsive shell so the header,
   drawer, and 44 px controls do not distort.
5. If an uploaded asset ID is absent or fails to load, fall back to the native
   reference-styled chrome without changing layout or function.
6. Do not declare `ArtMode=ReferenceChromeV2` until the uploaded image path has
   been rendered and captured in Studio. The local generated file by itself is
   not proof that Roblox clients can load it.

## Generation prompt

Built-in image generation was used, followed by local chroma-key removal,
alpha validation, and deterministic cropping:

> Create exactly eight empty modular Roblox Inventory UI chrome components in
> a 4x2 atlas: outer window with red header, navigation panel, filter control,
> item card, detail panel, green primary button, blue secondary button, and red
> close button. Match the supplied dark navy, cyan-edged, red-and-gold
> sci-fi/arcade sports-RPG reference. Use an orthographic front view, isolate
> every component on a perfectly uniform `#ff00ff` chroma-key background, and
> include no text, numbers, icons, objects, logos, watermarks, perspective,
> external shadows, or magenta inside the components.

