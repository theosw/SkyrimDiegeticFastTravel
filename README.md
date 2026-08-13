# Diegetic Travel

Diegetic Travel is a Morrowind-inspired travel network for Skyrim Special
Edition. It replaces one-click fast travel with interconnected in-world
services whose routes, costs, and limitations make geography matter. The first
gameplay-proven pillar is a College-centred wizard-guide network with a reusable
physical parchment destination picker.

The repository also contains a carriage-network beta built on
[Carriage and Ferry Travel Overhaul (CFTO)](https://www.nexusmods.com/skyrimspecialedition/mods/8379).
It keeps CFTO's actors, destination numbers, return-service topology, and live
fare globals while replacing the selection surface with the physical parchment
map. The beta deliberately has no route graph, hazard pricing, or estimated
hours. Carriage fares use CFTO's own local, standard, and extra tiers, including
any compatible patch that changes those globals.

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

The first boat-provider slice now lives in
[`modules/boat-honrich`](modules/boat-honrich). It preserves CFTO's ferrymen,
live local-fare global, destination markers, time-passing `Game.FastTravel`,
and Heartwood follower/horse handoff while replacing only the selection
  surface. Its public lane is Riften, Heartwood Mill, and Ivarstead; the private
  Honeyside ferryman joins it only while CFTO's placed service actor is enabled.
  The plugin and three Papyrus scripts build, its exact
CFTO/Dawnguard dialogue links pass an independent headless xEdit audit, and no
artwork, audio, BCD record, or BCD master is shipped. All three ferrymen resolve
to `MaleEvenToned`, and the exact Dawnguard shared-response FUZ is verified in
the vanilla archive. Its first monitored LoreRim pass proved all three
providers, a complete three-stop cycle, cancellation, and funded/unfunded fare
handling. Heartwood and Ivarstead exposed a dialogue-close handoff defect;
the corrected candidate requests Skyrim's normal Dialogue Menu hide message
and waits for confirmed closure before showing the map. The follow-up live pass
proved that handoff at all three ferrymen with no manual Escape and completed
the reverse three-stop cycle, so all six directed public-lane trips are now
exercised. Follower/horse arrival at Heartwood remains.

The second isolated boat slice now lives in
[`modules/boat-ilinalta`](modules/boat-ilinalta). Its public Route 3 triangle is
Brittleshin Pass, Half-Moon Mill, and Guardian Stones. It preserves CFTO's
live 30-gold local fare and exact arrival markers, including Brittleshin's
horse marker and Guardian Stones' follower/horse markers. Ilinata's Deep is
  available as a destination-only 50-gold regional trip from every available
  provider, including its dedicated follower/horse arrival markers. The private
  Lakeview Manor ferryman joins only while CFTO's placed service actor is
  enabled and retains its local fare and dedicated companion markers.
All three ferrymen and the shared voiced response are independently verified;
the plugin, scripts, SEQ, package, and byte-identical regeneration pass offline
audits. Its monitored LoreRim run proved all three providers, a complete
three-stop cycle, five parchment opens, Escape cancellation, a 12-gold denial,
exact 30-gold payment, and normal shutdown with no DNT/native errors. Companion
placement is deliberately no longer a release blocker for this list.

The third isolated boat slice is
[`modules/boat-solstheim`](modules/boat-solstheim). It covers the public CFTO
Route 4 triangle at Raven Rock, Tel Mithryn, and Skaal Village, preserves the
live 50-gold regional fare and exact arrival markers, and references the clean
Dragonborn/RUSTIC physical map with a deliberate square presentation correction.
Northshore Landing and Bujold's Retreat are available as destination-only
extensions from all three public providers without becoming return docks. All three
drivers resolve to `MaleEvenToned`; the exact shared-response FUZ, ESP, scripts,
SEQ, source topology, and no-asset package pass independent offline audits. A
first monitored gameplay pass proved automatic dialogue handoff, cancel,
low-gold denial, and two completed 50-gold trips. A follow-up proved that saved
auto-property values could retain stale map settings; the current candidate
moves presentation constants into executable code and awaits a 1:1 visual
check.

Carriage parchment work lives in
[`modules/carriage-parchment`](modules/carriage-parchment). The existing
flat CFTO service remains the sole availability, fare, payment, and travel
authority. The adapter draws all 27 native CFTO destinations with fare-only
labels and returns the stable selection to `DNT_TravelCoordinator.Purchase`
for revalidation. Its two
scripts compile without warnings; the separate ESP/SEQ and both paid/free
shared-voice INFO paths pass an independent xEdit audit. The map now distinguishes
eight verified destination-only stops from physical-driver, inn-request, and
Hearthfire private-carriage return services. The ordinary destination dialogue
remains the fallback.

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

The carriage beta now contains a flat, reproducible CFTO manifest; 27 direct
destinations; nine origin services; CFTO local/standard/extra fare lookup;
Hearthfire destination gates; direct arrival-marker travel; and the parchment
picker. No graph runtime, candidate paths, hazard sensors, generated hour
globals, or route-derived prices enter the release package or repository
product code.

## Developer quick start

The maintained repository surface and the distinction between runtime source,
release tooling, visual-authoring utilities, and historical research are
documented in [`docs/REPOSITORY_SCOPE.md`](docs/REPOSITORY_SCOPE.md) and the
machine-readable [`config/repository-scope.json`](config/repository-scope.json).

```powershell
.\tools\Build-Release.ps1 -LoreRimRoot "D:\Lorerim"
```

The release build checks the dependency lock, builds and tests the native menu,
compiles all 22 Papyrus scripts, generates and audits the consolidated
ESL-flagged `DiegeticTravel.esp`, and writes
`dist\DiegeticTravel-beta.zip`. The package requires SKSE64, Address Library,
SKSE Menu Framework, CFTO, and the external map-art dependencies listed in
`mod\README.txt`. It does not require JContainers.

To repackage already-generated, already-validated build artifacts without
reopening xEdit, use `.\tools\Build-Release.ps1 -PackageOnly`. Packaging copies
only the 22 source/PEX pairs in the release inventory, so stale compiler output
cannot enter the ZIP. Compiled PEX/DLL files and intermediate module plugins are
not tracked; see [`docs/ARTIFACT_POLICY.md`](docs/ARTIFACT_POLICY.md).

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
so it bypasses Diegetic Travel's own parchment handoff and availability gates.
See [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) for the analyzed integration
path.

Carriage dialogue closes into one native request built from
`travel_catalog.tsv`. The selected stable destination ID is returned to a small
Papyrus service, which revalidates fare and availability, charges the player,
and performs the final world mutation. There is no dialogue listener, quote
cache, runtime-generated global set, or Papyrus destination array. The release
ESP does contain the default-off `DNT_ShowLegacyTravelDialogue` compatibility
global, which hides only the superseded CFTO request prompts and obsolete
College destination-list hub; it is not part of fare, availability, or travel
execution.

Wait Carriage in Inns support is built into the consolidated runtime. WCI
continues to own its innkeeper request, sit/wait sequence, temporary driver,
and cleanup; Diegetic Travel recognizes that driver and uses the exact inn as
the catalogue origin. No compatibility ESP or load-order patch is required.
See [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md).

The maintained build surface is intentionally singular: use
`tools\Build-Release.ps1` for all release modules and
`tools\Run-OfflineChecks.ps1 -FullBuild` for the same build wrapped in the
workspace-only safety suite. The former per-module package, audit, deployment,
and gameplay wrappers were retired after consolidation; their history remains
available in Git. Module-specific Papyrus compilers and xEdit generators remain
internal inputs to the consolidated builder.

For the SEQ artifact, the xEdit script mirrors xEdit's built-in eligibility
rule and emits the fixed FormIDs of newly start-game-enabled quests. PowerShell
then writes those IDs as four-byte little-endian entries and rejects malformed
or duplicate IDs and an unexpected byte count. This avoids binary-buffer
marshalling through xEdit's Pascal interpreter.
