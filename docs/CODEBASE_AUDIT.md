# Release codebase audit

Audit date: 2026-08-21
Behavior fallback: `efc32bd` (`checkpoint: controller-proven release candidate`)

## Verdict

The release path now has one understandable authority for each concern:

- native `TravelCatalog` owns carriage stops and quotes;
- native `ParchmentMenu` owns selection presentation and input;
- thin Papyrus services own Skyrim state mutation;
- the generated ESL-flagged ESP owns only quest/script wiring;
- the release builder owns an explicit script/plugin inventory.

The obsolete graph/dialogue runtime, JContainers caches, generated globals,
split-plugin carriage harness, native comparison probes, transparent overlays,
and dynamic route-segment renderer have been removed rather than hidden behind
unused branches.

## Removed architecture

- Python route compiler/evaluator package and its tests;
- `runtime.json`, `dialogue_runtime.json`, hazard sensors, endpoint compiler
  inputs, and generated dialogue manifests;
- `DNT_RouteService`, dialogue listener, prepare/select fragments, cached
  quotes, and JContainers data maps;
- generated availability/cost/hour globals and legacy carriage dialogue
  fragments;
- separate carriage-plugin build/deploy/audit path;
- native shadow quote/catalogue terminology and Mirabelle-only diagnostic probe;
- unused Papyrus `AddStyledDestination` binding;
- retired chalk-overlay request/loading/rendering API;
- unused dynamic route edges, Dijkstra pathfinding, red/gold route drawing,
  provider authoring functions, and their extraction/application tools;
- dormant native voice/subtitle presentation and its runtime relocation;
- unused incremental marker-texture setter and superseded Papyrus purchase
  wrappers;
- unused mandatory Menu Framework button, focus, outline-triangle, and circle
  exports.

This cleanup removes more than five thousand lines while preserving the tested
map, marker, controller, payment, timing, Apparition, and travel flows.

## Current release flow

1. A dialogue fragment asks its provider picker to open.
2. Generic providers build a bounded native request; carriages call the native
   catalogue builder directly.
3. `ParchmentMenu` renders the map and returns an index.
4. The provider resolves a stable destination ID and revalidates it.
5. Papyrus charges, checks Apparition, advances time when appropriate, fades,
   and moves the player.

Carriage selection has no Papyrus destination loop: native code retains the
ordered stable IDs used to render the request and consumes the chosen ID.

## Data structures retained intentionally

- `TravelCatalog` vectors for 28 carriage locations and one policy. Linear
  lookup is appropriate at this scale and is covered by native tests.
- one mutex-protected active parchment request and small texture caches. Skyrim
  exposes one UI session, so a singleton runtime is the correct ownership
  model here.
- bounded destination and landmark vectors. Route origins and inactive
  landmarks remain because ferries visibly use them; route edges do not.
- scalar driver/service properties on the generated coordinator. Nine explicit
  public pairs are easier to inspect in xEdit and avoid runtime map
  dependencies. Three conditional Hearthfire origins resolve exact CFTO base
  forms at request time after the existing free-faction check, avoiding new
  forms or save-persisted properties.

## Papyrus boundary

Papyrus remains only where it provides value: dialogue integration, quest
gates, player inventory, game-time mutation, fades, and movement. Carriage
catalogue enumeration, quote calculation, request construction, selection
mapping, layout, hit testing, controller navigation, and texture lifetime are
native.

Apparition is authoritative only when `fFastTravelSpeedMult` is at least
`99999` (the tested Wizarding Traversal override is `100000`). The holder spell
is logged diagnostically but is not used as an active-state signal because it
can persist after the effect is removed.

## Release inventory and save behavior

The package audit requires exactly:

- one `DiegeticTravel.esp`, ESL-flagged;
- one native DLL and catalogue TSV;
- 22 named PSC/PEX pairs;
- exactly 22 named live DDS assets from `config/release-textures.txt`;
- no runtime/dialogue JSON files and no extra DNT scripts.

Generated quest records currently occupy plugin-local IDs below `0x800`.
Changing generated records or script properties can invalidate an existing
development save's serialized quest state even when the ESP remains ESL-safe.
Release testing therefore uses a new game after structural plugin changes.

## Deliberately retained development material

- the coordinate/icon calibration web app and asset-authoring sources;
- provider-specific plugin-generation/audit sources needed to reproduce the
  consolidated ESP;
- the Baan Malur research and calibration records for unfinished external areas;
- historical gameplay evidence in `EVIDENCE_LEDGER.md`.

These are outside the explicit release package and are labelled by directory or
documentation. They are not runtime dependencies.

The release builder uses the optimized `parchment-ae-release` native preset;
the symbol-bearing `parchment-ae` preset is reserved for development work.

## Verification gates

- native CMake build;
- 2/2 CTest targets;
- ordered carriage parity across 28 JSON/TSV destinations;
- ordered College parity across seven JSON/C++/Papyrus destinations;
- all release Papyrus compile sets with zero errors/warnings;
- provider structural audits;
- headless xEdit generation/finalization/semantic audit;
- explicit release package inventory and provenance audit;
- `git diff --check`.

The required fresh/disposable-game smoke test passed on the exact timestamped
candidate `0.1.0-beta-20260820T015340Z`, including the corrected Lake Honrich
fare-label placement and route completion. All engineering gates required for
the annotated beta tag `v0.1.0-beta` are complete. Public Nexus publishing is a
separate step and remains subject to the private page, graphics, permissions,
requirements, and upload checklist.
