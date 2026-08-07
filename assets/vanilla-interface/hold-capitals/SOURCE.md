# Vanilla hold-capital marker fallbacks

These files are neutral-frame exports of the hold-capital castle markers embedded
in Skyrim Special Edition's vanilla `interface/map.swf`. They are authoring and
fallback assets for Diegetic Fast Travel; they are not captures from LoreRim's
active map UI replacer.

## Source identity

- Archive: `Skyrim - Interface.bsa`
- Installed source: Skyrim Special Edition/Anniversary Edition 1.6.1170
- Archive size: `105799354` bytes
- Archive SHA-256: `5C8D5275EEAAA87EEC84C893DA8DC3BF977E0197EBA86560BB0D1DC651432957`
- Member: `interface/map.swf`
- Member size: `98637` bytes
- Member SHA-256: `6180E6BC7FD2743D3E4B0142647E9C4BC17CC84E644456E3517C0F2C988B02B8`

## Exported symbols

| Destination | Vanilla symbol | Character ID | Files |
| --- | --- | ---: | --- |
| Whiterun / Dragonsreach | `WhiterunCastleMarker` | 153 | `whiterun-dragonsreach.*` |
| Solitude / Blue Palace | `SolitudeCastleMarker` | 171 | `solitude-blue-palace.*` |
| Windhelm / Palace of the Kings | `WindhelmCastleMarker` | 147 | `windhelm-palace-of-the-kings.*` |
| Riften / Mistveil Keep | `RiftenCastleMarker` | 195 | `riften-mistveil-keep.*` |
| Markarth / Understone Keep | `MarkarthCastleMarker` | 242 | `markarth-understone-keep.*` |
| Morthal / Highmoon Hall | `MorthalCastleMarker` | 233 | `morthal-highmoon-hall.*` |
| Dawnstar / White Hall | `DawnstarCastleMarker` | 313 | `dawnstar-white-hall.*` |
| Winterhold / College hub | `WinterholdCastleMarker` | 141 | `winterhold-college.*` |
| Falkreath / Jarl's Longhouse | `FalkreathCastleMarker` | 271 | `falkreath-jarl-longhouse.*` |
| Minor destinations | `TownMarker` | 162 | `../town-marker.*` |

The vanilla discovered sprites contain 100 animation frames. These exports use
frame 1, the neutral discovered state. Dawnstar and Morthal deliberately share
the same vanilla silhouette even though they are separate symbols.

## Reproduction notes

1. Extract only `interface/map.swf` with the read-only helper in
   `tools/java/resaver/archive/DNTBsaExtract.java`, using ReSaver's BSA parser.
2. With JPEXS Free Flash Decompiler 26.2.1, export sprite IDs
   `141,147,153,162,171,195,233,242,271,313` as SVG and retain frame `1.svg`
   from each.
3. Render the SVGs with Inkscape 1.4.4.
4. Normalize each raster with `tools/Normalize-TransparentMarker.py` onto a
   transparent 512 x 512 canvas, centered inside a 416 x 416 maximum content
   box. Runtime builds use `--normalize-alpha-max` because vanilla frame 1 is
   globally faded; this makes the strongest pixels opaque without flattening
   antialiased edges.

The SVGs are retained so themed variants can be made without tracing the raster
fallbacks. The PNGs are the normalized runtime-ready derivatives.
