# Norden UI carriage marker source

These SVGs are exact discovered-state marker symbols exported from Norden UI
1.2.5's `Interface/skyui/mapmarkerart.swf` with FFDec 26.2.1. The project owner
reports direct use and redistribution permission from the Norden UI author.

- Nexus: https://www.nexusmods.com/skyrimspecialedition/mods/166086
- Installed source: `mods/Norden UI 21x9/Interface/skyui/mapmarkerart.swf`
- Source SHA-256: `AF39A7C181E8BF6187E389CC6D5F333780F11057C562673BC40A78490998B1AA`
- The 16:9 and 21:9 installed SWFs have the same SHA-256.

Exported symbols:

- Town: `DefineSprite_38_Town`
- Settlement: `DefineSprite_40_Settlement`
- Farm: `DefineSprite_60_Farm`
- Wood Mill: `DefineSprite_62_Wood Mill`
- Mine: `DefineSprite_64_Mine`
- Riften: `DefineSprite_104_RiftenCapital`
- Windhelm: `DefineSprite_108_WindhelmCapital`
- Whiterun: `DefineSprite_112_WhiterunCapital`
- Solitude: `DefineSprite_116_SolitudeCapital`
- Markarth: `DefineSprite_120_MarkathCapital` (spelled `Markath` in the SWF)
- Winterhold: `DefineSprite_124_WinterholdCapital`
- Morthal: `DefineSprite_129_MorthalCapital`
- Falkreath: `DefineSprite_132_FalkreathCapital`
- Dawnstar: `DefineSprite_135_DawnstarCapital`

`tools/Build-NordenCarriageMarkers.ps1` pins every SVG hash, renders each to a
transparent normalized 512-square image, and encodes the runtime BC7 DDS files.
