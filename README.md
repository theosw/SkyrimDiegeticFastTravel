# Diegetic Travel

Diegetic Travel is a Skyrim SE carriage-network addon built on
[Carriage and Ferry Travel Overhaul (CFTO)](https://www.nexusmods.com/skyrimspecialedition/mods/8379).
It keeps CFTO's actors and travel behavior, but replaces the pick-any-marker layer
with authored roads, live hazards, route choice, graph-derived fares, and quoted
travel time.

The current beta track is deliberately carriage-only:

- carriage paths use carriage edges only;
- CFTO ferries remain untouched until their per-ferryman lanes are decoded;
- each trip has up to three precomputed candidate paths;
- Papyrus evaluates those few candidates when the player asks for a quote;
- active refuse-tier chokepoints remove a path from consideration;
- the cheapest remaining path supplies the fare and time estimate.

This repository is the public-release implementation. The LoreRim research and
load-order datamine remain upstream evidence, not runtime dependencies.

## Implementation status

The carriage alpha now contains:

- a deterministic provider-aware route compiler;
- geometric proximity-hazard attachment;
- strict live-sensor validation;
- an executable reference evaluator for runtime pricing and refusal;
- verified live sensors for every routed hazard;
- generated CFTO endpoint/dialogue metadata and an xEdit plugin generator;
- five Papyrus runtime/dialogue scripts that compile with no warnings;
- a reproducible alpha packaging command;
- regression tests for routing and pricing.

The strict compiler currently emits 29 stops, 812 ordered routes, an average of
2.99 candidates per trip, and zero sensor or CFTO endpoint errors. The xEdit
generator now runs unattended, and its smoke build emits a valid TES4 header,
the six expected masters, 27 availability/cost/hours global sets, nine origin
quests, and 27 quoted destination topics without xEdit assignment errors. The
mod still needs the in-game checks listed in
[`docs/ROADMAP.md`](docs/ROADMAP.md).

## Developer quick start

```powershell
$env:PYTHONPATH = "src"
python -m unittest discover -s tests -v

python -m diegetic_travel compile `
  --graph "C:\Users\Theo\Documents\LoreRim Info\travel-network\graph.json" `
  --endpoints config\cfto_endpoints.json `
  --sensors config\hazard_sensors.json `
  --out build

.\tools\Compile-Papyrus.ps1 `
  -LoreRimRoot "D:\Games\US SSE\Lorerim\game-files"
```

The compile command writes `runtime.json`, `dialogue_manifest.json`, and a
validation report. A release build fails if a routed hazard lacks the forms
needed to sense its state. Use `--allow-incomplete-sensors` only for authoring
diagnostics.

The complete build is:

```powershell
.\tools\Build-Alpha.ps1
```

It compiles the data and Papyrus, generates `DiegeticTravel.esp`, stages the mod,
and writes `dist\DiegeticTravel-alpha.zip`. The installable alpha requires
SKSE64, JContainers SE, and CFTO, and the generated plugin must load after
`CFTO.esp`.

xEdit 4.1.x does not offer a truly headless `-script` mode: `-script` selects
Script mode, while `-autoload` and `-autoexit` are parsed only in Edit mode.
`Generate-Plugin.ps1` works around that limitation narrowly and unattended: it
supplies a private plugins list, invokes the preselected Module Selection OK
button through Windows UI Automation, waits for the generator status file, and
closes xEdit through its normal `WM_CLOSE` path. On timeout it leaves xEdit open
for inspection.

The current alpha is not compatible with the **Better Carriage Destinations -
CFTO** patch: that patch opens its map picker before CFTO's destination topics,
so it bypasses Diegetic Travel's dynamic route quote and availability dialogue.
See [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) for the analyzed integration
path.
