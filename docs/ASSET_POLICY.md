# Asset and dependency policy

This repository ships its own source, generated plugins, Papyrus bytecode, and
native DLL. It does not redistribute Bethesda audio or third-party map art.

## Referenced, not bundled

- The parchment art path currently resolves to RUSTIC MAPS'
  `textures/dungeons/imperial/battlemap01.dds`.
- Provider voice paths resolve to FUZ files in the user's installed Bethesda
  archives or other separately installed dependencies.
- Better Carriage Destinations remains a separate optional adapter dependency.
- SKSE Menu Framework, SKSE, Address Library, and RUSTIC MAPS are installed by
  the user and listed as requirements by the eventual mod manager manifest or
  Nexus dependency metadata.

Packages are audited to reject `.png`, `.jpg`, `.jpeg`, `.dds`, `.svg`, `.wav`,
`.xwm`, and `.fuz` payloads. A local learning-source copy is ignored by Git and
must never be copied into `modules/*/mod` or `dist`.

## Licensing rules

- Record every runtime/build dependency, version, source URL, and license before
  release.
- A dependency relationship does not grant redistribution rights. Reference
  installed assets by path only unless the asset author has explicitly granted
  redistribution permission.
- If external art is missing, the picker must retain usable buttons and the
  dialogue fallback; missing optional presentation audio must fall back to the
  picker.
- Generated patches may require another mod, but must not contain that mod's
  loose artwork/audio.

The exact development-machine hashes are pinned in `dependencies.lock.json`.
`DEPENDENCIES.md` explains how they are audited.
