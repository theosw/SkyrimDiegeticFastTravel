# Diegetic Travel

Diegetic Travel is a Morrowind-inspired travel network for Skyrim Special
Edition. It replaces one-click fast travel with interconnected in-world
services whose routes, costs, and limitations make geography matter. The first
gameplay-proven pillar is a College-centred wizard-guide network with a reusable
physical parchment destination picker.

The repository also contains a carriage-network prototype built on
[Carriage and Ferry Travel Overhaul (CFTO)](https://www.nexusmods.com/skyrimspecialedition/mods/8379).
It keeps CFTO's actors and travel behavior, but replaces the pick-any-marker
layer with authored roads, live hazards, route choice, graph-derived fares, and
quoted travel time:

- carriage paths use carriage edges only;
- CFTO ferries remain untouched until their per-ferryman lanes are decoded;
- each trip has up to three precomputed candidate paths;
- Papyrus evaluates those few candidates when the player asks for a quote;
- active refuse-tier chokepoints remove a path from consideration;
- the cheapest remaining path supplies the fare and time estimate.

Local LoreRim research, downloaded learning sources, and load-order datamines
remain development evidence rather than redistributed runtime dependencies.

The project also contains a separate
[`modules/wizard-guides`](modules/wizard-guides) vertical slice. That module
starts the Morrowind-style mage-guide pillar without depending on CFTO or
overriding the carriage prototype: permanent College faculty serve the hub,
court wizards are spokes, and the travel service is UI-independent so multiple
pickers call the same fare, payment, and teleport functions. The current
eight-node extension adds Madena/Dawnstar and Falion/Morthal: all seven
spoke wizards travel directly to the College, while permanent College faculty
link outward to Whiterun, Riften, Solitude, Windhelm, Markarth, Dawnstar, and
Morthal.
Voiced INFOs use an explicitly audited short vanilla response whose FUZ exists
for each eligible voice type. The
branching faculty hub owns a forced-subtitle response so its custom `LinkTo`
submenu advances reliably. Mirabelle's provider-specific installed FUZ,
subtitle, and lip sync are gameplay-proven; the current offline candidate
generalizes that presentation before the parchment opens. Only the selected
destination runs a travel fragment.

The separate [`modules/wizard-map-picker`](modules/wizard-map-picker) candidate
uses Better Carriage Destinations only as a five-city MapMenu selector. It
translates the selected world-map marker to one of the core service's stable
destination IDs; the core still validates, charges, logs, and teleports. The
proven dialogue list remains available as a fallback. See
[`docs/WIZARD_MAP_ADAPTER.md`](docs/WIZARD_MAP_ADAPTER.md) for the pinned
upstream contract and live-test gate.

The new [`modules/parchment-picker`](modules/parchment-picker) candidate is a
provider-neutral alternative to the native tween MapMenu. It uses a blocking
SKSE Menu Framework window, provider-defined artwork/aspect/marker positions,
and returns only a selection index to Papyrus. The wizard provider maps that
index to the same stable core destination IDs. The module intentionally ships
no map artwork or audio: a separate mod-manager dependency supplies the
configured texture. Its native/Papyrus builds and structural audits pass. At
32:9, gameplay tests prove the original five-route parchment layout, gold idle/red hover
presentation, Norden-style cursor, no-default startup, Escape/button
cancellation, HUD restoration, service handoff, fare handling, and completed
travel. Dawnstar and both new service flows passed a monitored run. Morthal's
first map-marker arrival landed on rebuilt roof geometry; its verified
ground-level carriage-marker replacement still needs a focused retest. The BCD adapter remains an unchanged five-city fallback; the
core dialogue fallback now contains seven destinations.

The five-pillar scope and reuse decisions are recorded in
[`docs/PILLAR_RESEARCH.md`](docs/PILLAR_RESEARCH.md). The generic spoken
provider boundary is specified in
[`docs/PRESENTATION_CONTRACT.md`](docs/PRESENTATION_CONTRACT.md), and
[`docs/ASSET_POLICY.md`](docs/ASSET_POLICY.md) defines what must remain an
external dependency rather than enter a package.

Dialogue hypotheses and their actual evidence level are tracked in
[`docs/EVIDENCE_LEDGER.md`](docs/EVIDENCE_LEDGER.md). Commit `ed004f2` is the
rollback checkpoint for the fully voiced three-node build. Commit `4dfb646`
is the previous live-proven faculty-access checkpoint. The Solitude, Windhelm,
and Markarth spokes are live-proven in the six-node checkpoint; Dawnstar is
now live-proven and Morthal's replacement arrival is the current candidate.

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
destination topics without xEdit assignment errors. The patched default now
completes that build headlessly with no Module Selection confirmation. The mod
still needs the in-game checks listed in
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

# Safe while another gameplay test is active: workspace builds/audits only.
.\tools\Run-OfflineChecks.ps1 -FullBuild
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

Stock xEdit 4.1.x does not offer a truly headless `-script` mode: `-script`
selects Script mode, while `-autoload` and `-autoexit` are parsed only in Edit
mode. This workspace uses the locally built narrow xEdit patch documented in
`tools/xedit/patches`: it permits autoload/autoexit for the scripted staging
workflow, skips Module Selection, and exits after the script reports its
status. Generators and audits copy inputs into ignored workspace staging; they
do not run through MO2's VFS or write to LoreRim. The stock UI-automation
fallback remains relevant only if that patched executable is unavailable.

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

The standalone wizard-guide Phase 1 package is built separately:

```powershell
.\tools\Build-WizardGuides.ps1
```

This compiles the two wizard scripts and writes
`dist\DiegeticTravelWizardGuides-phase1.zip`. It does not launch Skyrim or
deploy/toggle the module in MO2.

To package the exact already-compiled and already-tested module payload without
changing PEX hashes, use:

```powershell
.\tools\Build-WizardGuides.ps1 -PackageOnly
```

The optional BCD wizard map adapter is built and audited separately:

```powershell
.\tools\Build-WizardMapAdapter.ps1
```

This writes `dist\DiegeticTravelWizardMapAdapter-alpha.zip`. It requires BCD
and the core wizard-guide plugin and does not alter either of them.

For the SEQ artifact, the xEdit script mirrors xEdit's built-in eligibility
rule and emits the fixed FormIDs of newly start-game-enabled quests. PowerShell
then writes those IDs as four-byte little-endian entries and rejects malformed
or duplicate IDs and an unexpected byte count. This avoids binary-buffer
marshalling through xEdit's Pascal interpreter.
