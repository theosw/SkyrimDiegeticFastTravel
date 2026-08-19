# Norden UI round-trip selection ring

The source SVG in this directory is FFDec shape 48 exported from Norden UI
1.2.5's `Interface/loadingmenu.swf`. It is the two-arrow loading symbol selected
by the project owner for round-trip destinations on formal wizard and carriage
maps.

- Installed source: `D:\Lorerim\mods\Norden UI 16x9\Interface\loadingmenu.swf`
- Installed SWF SHA-256: `A2C39E2F99F1506ABAABE65DF4FA8EF2192A57E6B5156557B0441C658F4BA4AD`
- Exported shape: `48.svg`
- Exported SVG SHA-256: `A207F90E2A73263FC9AA71EF8E05AE89A37ED609CF1CA634CAB494DC0E59B921`
- Permission: use and redistribution permission supplied directly by the
  Norden UI author to the project owner.

`selection-ring-cropped.svg` records the accepted calibrated vector derived
from that permitted source. The shipped one-way ring is extracted directly
from the accepted calibrated round-trip raster, retaining the complete darker
arrow and its antialiased shadow. It is normalized against the complete ring
so both variants share the same rotation, scale, and marker anchor.

`tools/Build-NordenSelectionRing.ps1` renders, alpha-normalizes, and BC7-encodes
the pinned SVG. Ferryman maps intentionally do not use this asset; their
one-way/return visual language is authored separately.
