# Native travel architecture

## Goal

Move catalogue lookup, quote construction, travel-time estimation, travel-mode
resolution, and parchment request assembly out of the Papyrus/JContainers hot
path. Papyrus remains the final world-mutation bridge until native execution has
its own dedicated integration tests.

## Migration order

1. Instrument the working release path.
2. Load the flat native catalogue in observe-only shadow mode.
3. Compare native direct estimates with legacy graph quotes in the log.
4. Let native code construct the menu request from the catalogue.
5. Switch quote publication to native results after integration tests pass.
6. Resolve Apparition and execute travel through one authoritative mode result.
7. Finish explicit controller navigation and controller regression tests.
8. Leave old quests, globals, and scripts dormant for save/FormID stability.

## Phase-one contract

`travel_catalog.tsv` is deliberately small and dependency-free. It contains:

- a schema version;
- provider policies;
- stable destination IDs and display names;
- normalized map coordinates;
- plugin-local arrival-marker FormIDs;
- open, one-way, or quest-locked availability metadata;
- optional direct route overrides.

The estimator performs one location lookup for each endpoint, one Euclidean
distance calculation, policy scaling, and optional override application. It
does not search paths or inspect candidate routes, hazards, wars, or graph
edges. Instant travel always reports zero elapsed hours; a free ride always
reports zero fare.

## Shadow logging

The first integration candidate keeps all gameplay behavior on the proven
legacy path. It adds these diagnostics:

- `QUOTE_BATCH_COMPLETE`: total legacy quote-preparation time;
- `MENU_QUOTES_READY`: dialogue preload time;
- `CARRIAGE_PARCHMENT_OPEN`: handoff, quote, and request-build spans;
- `PARCHMENT_OPEN`: native request-build time;
- `PARCHMENT_FIRST_FRAME`: show-to-first-frame and total native latency;
- `TRAVEL_SHADOW_CATALOG_READY`: catalogue load/count validation;
- `TRAVEL_SHADOW_QUOTE`: legacy/native fare and hour deltas.

No shadow result is published to dialogue, charged to the player, or used to
execute travel.

## First integration gate

The phase-one candidate is intentionally a narrow carriage smoke test. Install
the candidate over the consolidated test profile, then use a disposable save:

1. Open one carriage driver's dialogue and select the route-map prompt.
2. Confirm the parchment appears, remains responsive, and has no default
   destination selection.
3. Hover two destinations and confirm their labels, fares, and times still
   match the proven legacy behavior.
4. Close and reopen the parchment once. Travel is optional for this gate.
5. Capture the native plugin and Papyrus logs without saving altered state.

The gate passes when behavior is unchanged, `TRAVEL_SHADOW_CATALOG_READY`
reports one policy and 27 locations, every displayed quote has a corresponding
`TRAVEL_SHADOW_QUOTE`, and all timing events listed above are present. Fare and
hour deltas are tuning evidence, not failures, because the native result is
still observe-only. Any missing catalogue, unresolved stable ID, crash, or menu
regression blocks phase two.
