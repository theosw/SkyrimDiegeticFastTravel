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
- six Papyrus runtime/dialogue scripts that compile with no warnings;
- a reproducible alpha packaging command;
- regression tests for routing and pricing.

The strict compiler currently emits 29 stops, 812 ordered routes, an average of
2.99 candidates per trip, and zero sensor or CFTO endpoint errors. The xEdit
generator's smoke build emits a valid TES4 header, the six expected masters, 27
availability/cost/hours global sets, nine origin quests, and 27 quoted
destination topics without xEdit assignment errors. Stock xEdit may still need
one manual Module Selection confirmation, as described below. The mod still
needs the in-game checks listed in
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
  -LoreRimRoot "D:\Lorerim"
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

To repackage already-generated, already-validated build artifacts without
reopening xEdit, use `.\tools\Build-Alpha.ps1 -PackageOnly`. It verifies that
every `DNT_*.psc` source has its matching compiled PEX before creating the ZIP.

xEdit 4.1.x does not offer a truly headless `-script` mode: `-script` selects
Script mode, while `-autoload` and `-autoexit` are parsed only in Edit mode.
`Generate-Plugin.ps1` works around that limitation narrowly: it supplies a
private plugins list, attempts to invoke the preselected Module Selection OK
button through Windows UI Automation, waits for the generator status file, and
closes xEdit through its normal window-close path. Stock xEdit is briefly
visible because its modal selector is not exposed to UI Automation while
hidden. On the current LoreRim setup the managed invocation has not activated
the button reliably, so one manual OK click may still be required. On timeout
the launcher leaves xEdit open for inspection.

The current alpha is not compatible with the **Better Carriage Destinations -
CFTO** patch: that patch opens its map picker before CFTO's destination topics,
so it bypasses Diegetic Travel's dynamic route quote and availability dialogue.
See [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) for the analyzed integration
path.

Quote globals are prepared by a player-alias listener registered for SkyUI's
`Dialogue Menu` event. The listener re-registers after every save load, resolves
the carriage driver under the crosshair, and completes the whole origin quote
set before CFTO constructs its destination choices. The root INFO fragment is a
cache-aware fallback; it no longer clears a successfully preloaded menu. The
package ships `Seq\DiegeticTravel.seq` so the listener and service quests start
reliably.

For the SEQ artifact, the xEdit script mirrors xEdit's built-in eligibility
rule and emits the fixed FormIDs of newly start-game-enabled quests. PowerShell
then writes those IDs as four-byte little-endian entries and rejects malformed
or duplicate IDs and an unexpected byte count. This avoids binary-buffer
marshalling through xEdit's Pascal interpreter.
