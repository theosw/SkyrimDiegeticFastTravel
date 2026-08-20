# Architecture

## Release shape

The release is one ESL-flagged `DiegeticTravel.esp`, one native SKSE plugin,
22 Papyrus scripts, one validated pricing INI, one 28-location carriage
catalogue, and UI textures. The
development modules remain separate source boundaries, but the xEdit release
generator consolidates their records into the single plugin.

## Runtime ownership

### Native plugin

`DNTParchmentPicker.dll` owns work that must be fast or presentation-heavy:

- loading and validating `DiegeticTravel.ini` and `travel_catalog.tsv` once at
  startup;
- direct carriage fare/hour estimation from the flat catalogue;
- availability checks that can be resolved from live forms;
- parchment request construction and stable selection-index mapping;
- menu rendering, mouse/controller input, marker styling, and dialogue close.

The native catalogue is authoritative for carriage menu contents and quotes.
There is no shadow/legacy quote comparison path.

### Papyrus

Papyrus is deliberately a thin world-mutation bridge:

- `DNT_CarriageParchmentPicker` coordinates dialogue close, native menu open,
  and the returned stable destination ID;
- `DNT_TravelCoordinator` maps the nine CFTO drivers to nine scalar origin
  service properties. Its optional WCI integration validates one of WCI's four
  spawned drivers, translates the player's exact inn Location into one of the
  seven existing catalogue origin IDs, and passes that scalar origin onward;
- `DNT_OriginService` revalidates the selected quote, requests CFTO's arrival
  marker from the same native catalogue, charges gold, and performs travel. It
  contains no destination/FormID table. Its explicit-origin entry point
  lets compatible providers reuse this world-mutation path without adding
  another persistent service quest;
- each boat and wizard service owns only its provider-specific gates,
  companion handoff, and arrival behavior; prices are resolved through the
  immutable native pricing snapshot so labels and deductions cannot diverge;
- `DNT_TravelCompatibility` chooses normal `Game.FastTravel` or zero-time
  Apparition `MoveTo` immediately before travel.

There are no JContainers maps, Papyrus route graphs, cached quote arrays, menu
listeners, or background update loops. The ESP contains one static compatibility
global, `DNT_ShowLegacyTravelDialogue`, used only as a default-off condition on
the superseded CFTO request INFOs and the obsolete College list hub. It is not
read or written by the runtime travel path.

## Carriage data

- `config/carriage_provider.json` contains the nine driver FormIDs used by the
  generator.
- `modules/carriage-parchment/config/network.json` documents the 28-stop
  topology, marker presentation, and verified one-way classification.
- `modules/parchment-picker/mod/SKSE/Plugins/DiegeticTravel/travel_catalog.tsv`
  is the small runtime catalogue used by native code.
- `modules/parchment-picker/mod/SKSE/Plugins/DiegeticTravel.ini` holds supported
  user-facing fare and estimate settings. Invalid individual values retain
  defaults; settings are never reloaded mid-session. The public carriage policy
  is 475 gold per normalized map unit, a 50-gold minimum, and 50-gold rounding,
  yielding 50–400-gold trips from the nine physical drivers. Ferries follow
  CFTO's live fare globals unless explicitly overridden.

Destination IDs are stable strings at the UI/service boundary. The native
catalogue is the sole destination/FormID registry and returns the resolved
`ObjectReference` to the small Papyrus world-mutation bridge only at commit.

## Build and verification

`tools/Build-Release.ps1` is the only release entry point. It builds/tests the
native plugin, compiles Papyrus, runs the headless xEdit generator/finalizer,
copies an explicit 22-script inventory, proves every borrowed wizard/ferry
voice asset in the installed dependency archives, audits the package, and
creates the ZIP. Voice proof also runs during `-PackageOnly`; development-module
builders are retained only for isolated provider work.

The generator creates 17 start-game quests: nine carriage origin services and
eight provider quests. The audit enforces one plugin, one SEQ, ESL local-ID
limits, exact masters, exact script inventory, the catalogue schema, the
absence of obsolete graph artifacts, and the legacy-dialogue boundary: one
wizard INFO, two carriage INFOs, and four ferry INFOs gated while all seven
replacement parchment INFOs remain ungated.

Wait Carriage in Inns uses the same consolidated carriage topology. The core
picker recognizes WCI's temporary driver and translates the exact inn Location
into an existing catalogue origin ID. The native request builder then obtains
the source label, destinations, and quotes from the catalogue. WCI remains
responsible for the innkeeper request, sit/wait sequence, spawned driver, and
cleanup; no compatibility ESP, extra dialogue branch, quest, or script is
required.

## Save behavior

Papyrus properties are serialized into saves. Regenerating quest records or
changing their VMAD properties therefore requires a new game for a trustworthy
integration test. Rebuilding native code, textures, or non-serialized data does
not by itself require a new save, but release-candidate testing uses a fresh
save whenever the consolidated ESP changes.
