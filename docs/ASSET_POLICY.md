# Asset and dependency policy

This repository ships its own source, generated plugins, Papyrus bytecode,
native DLL, explicitly allowlisted original artwork, and approved dependency
notices. It does not redistribute Bethesda audio or third-party map art without
permission.

## Bundled and credited

- The source for `boat-route-chalk-overlay.dds` is user-authored artwork for
  this project. It is retained as a post-release authoring source, but the beta
  package does not build, activate, or ship the DDS.
- `docks-marker.dds` uses an AI-generated general anchor design that the mod
  author edited and touched up in Krita. Its transparent 512-square build
  source is retained at `assets/user-authored/stylized-docks-marker.png`.
- `shipwreck-marker.dds` uses AI-assisted boat artwork supplied and edited by
  the mod author. Its transparent 512-square build source is retained at
  `assets/user-authored/stylized-ship-marker.png`.
- The unused `winterhold-marker.png` and `wizard-hat-marker.png` experiments use
  AI-assisted designs supplied by the mod author. Their pinned authoring sources
  remain under `assets/user-authored/`, but the vanilla-icon beta does not
  encode or bundle them.
- Eight hold-capital fallback markers are neutral-frame derivatives of the
  castle symbols in Skyrim's vanilla `interface/map.swf`. Their exact source
  archive/member hashes, character IDs, SVGs, and normalized PNGs are retained
  under `assets/vanilla-interface/hold-capitals/`.
- The carriage beta uses fourteen exact discovered-map symbols from outobugi's
  NORDIC UI 2.4.1: nine capital markers plus Town, Settlement, Farm, Wood Mill,
  and Mine. NORDIC UI's published author instructions state that its art is open
  to use, while asking users to check SkyUI and SkyHUD permissions as well. The
  pinned development extraction was made from a downstream Norden UI 1.2.5 SWF.
  Exported, hash-pinned SVG sources remain under the legacy
  `assets/norden-interface/carriage-markers/` path; both original-art and
  extraction provenance are recorded in `dependencies.lock.json`.
- Formal wizard and carriage sheets use the exact two-arrow round-trip symbol
  exported from Norden UI's loading menu as a selection ring. Its hash-pinned
  SVG source and extraction record live under
  `assets/norden-interface/selection-ring/`.
- The earlier Skyrim-derived Docks and Shipwreck vectors remain in
  `assets/vanilla-interface/` as rollback sources, but are not bundled by the
  current build.
- The earlier Dragonborn Reskin - Wheeler apparition marker remains under
  `assets/third-party/` as a credited learning/rollback source, but the current
  build no longer converts or bundles it.

## Referenced, not bundled

- Boat providers use Bethesda physical-map paths such as
  `textures/dungeons/imperial/battlemap01.dds`. RUSTIC MAPS is a recommended
  loose visual override at those same paths, not a runtime requirement.
- Wizard and carriage providers prefer Skyrim Paper Map by Caro Tuts for FWMF's
  `textures/terrain/tamriel/skyrim.dds`. It is referenced only and is not
  redistributed. If it is absent, both providers switch to a separately
  calibrated Bethesda `battlemap01.dds` artwork profile.
- SKSE Menu Framework loads only filesystem files. When a requested Bethesda
  DDS has no loose winner, the native DLL reads it through Skyrim's
  archive-aware resource stream and writes a bounded copy to the operating
  system's DiegeticTravel texture cache for Menu Framework to load. This is a
  runtime interoperability cache, not packaged redistribution.
- The optional Baan Malur merchant-ferry add-on resolves to Caites' Solstheim
  and Baan Malur Paper Map for FWMF at
  `textures/terrain/dlc2solstheimworld/solstheim.dds`. It is referenced only,
  is never copied into either archive, and is not a main-release dependency.
- Provider voice paths resolve to FUZ files in the user's installed Bethesda
  archives or other separately installed dependencies.
- Better Carriage Destinations remains a separate optional adapter dependency.
- SKSE Menu Framework, SKSE, Address Library, and CFTO are installed by the
  user and listed as main-file requirements. RUSTIC MAPS and Skyrim Paper Map
  by Caro Tuts for FWMF are listed as visual recommendations. The optional Baan
  Malur chart remains a requirement of that separate add-on only.

Packages reject unallowlisted `.png`, `.jpg`, `.jpeg`, `.dds`, `.svg`, `.wav`,
`.xwm`, and `.fuz` payloads. Each permitted runtime asset is named explicitly
in the relevant build and audit scripts. A local learning-source copy is ignored
by Git and must never be copied into `modules/*/mod` or `dist`.

## Licensing rules

- Record every runtime/build dependency, version, source URL, and license before
  release.
- A dependency relationship does not grant redistribution rights. Reference
  installed assets by path only unless the asset author has explicitly granted
  redistribution permission.
- If preferred external art is missing, the picker must select and transform a
  usable archived-art profile; a blank diagnostic canvas is not the supported
  public fallback. Missing optional presentation audio must fall back to the
  picker.
- Generated patches may require another mod, but must not contain that mod's
  loose artwork/audio.

The exact development-machine hashes are pinned in `dependencies.lock.json`.
`DEPENDENCIES.md` explains how they are audited.
