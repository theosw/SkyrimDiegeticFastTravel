# Architecture

## Release shape

The release is one ESL-flagged `DiegeticTravel.esp`, one native SKSE plugin,
22 Papyrus scripts, one 27-location carriage catalogue, and UI textures. The
development modules remain separate source boundaries, but the xEdit release
generator consolidates their records into the single plugin.

## Runtime ownership

### Native plugin

`DNTParchmentPicker.dll` owns work that must be fast or presentation-heavy:

- loading and validating `travel_catalog.tsv` once at startup;
- direct carriage fare/hour estimation from the flat catalogue;
- availability checks that can be resolved from live forms;
- parchment request construction and stable selection-index mapping;
- menu rendering, mouse/controller input, marker styling, and dialogue close;
- voice/subtitle presentation helpers.

The native catalogue is authoritative for carriage menu contents and quotes.
There is no shadow/legacy quote comparison path.

### Papyrus

Papyrus is deliberately a thin world-mutation bridge:

- `DNT_CarriageParchmentPicker` coordinates dialogue close, native menu open,
  and the returned stable destination ID;
- `DNT_TravelCoordinator` maps the nine CFTO drivers to nine scalar origin
  service properties;
- `DNT_OriginService` revalidates the selected quote, charges gold, resolves
  CFTO's arrival marker, and performs travel;
- each boat and wizard service owns only its provider-specific gates, fare,
  companion handoff, and arrival behavior;
- `DNT_TravelCompatibility` chooses normal `Game.FastTravel` or zero-time
  Apparition `MoveTo` immediately before travel.

There are no JContainers maps, generated dialogue globals, Papyrus route
graphs, cached quote arrays, menu listeners, or background update loops.

## Carriage data

- `config/carriage_provider.json` contains the nine driver FormIDs used by the
  generator.
- `modules/carriage-parchment/config/network.json` documents the 27-stop
  topology, marker presentation, and verified one-way classification.
- `modules/parchment-picker/mod/SKSE/Plugins/DiegeticTravel/travel_catalog.tsv`
  is the small runtime catalogue used by native code.

Destination IDs are stable strings at the UI/service boundary. FormIDs are
resolved only where Skyrim records are required.

## Build and verification

`tools/Build-Release.ps1` is the only release entry point. It builds/tests the
native plugin, compiles Papyrus, runs the headless xEdit generator/finalizer,
copies an explicit 22-script inventory, audits the package, and creates the
ZIP. Development-module builders are retained only for isolated provider work.

The generator creates 17 start-game quests: nine carriage origin services and
eight provider quests. The audit enforces one plugin, one SEQ, ESL local-ID
limits, exact masters, exact script inventory, the catalogue schema, and the
absence of obsolete graph artifacts.

## Save behavior

Papyrus properties are serialized into saves. Regenerating quest records or
changing their VMAD properties therefore requires a new game for a trustworthy
integration test. Rebuilding native code, textures, or non-serialized data does
not by itself require a new save, but release-candidate testing uses a fresh
save whenever the consolidated ESP changes.
