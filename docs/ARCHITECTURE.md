# Architecture

## Runtime boundary

CFTO remains responsible for carriage drivers, seating, scenes, and travel. This
mod overrides CFTO's existing paid-carriage root and 27 existing destination
topics; it does not redistribute CFTO assets. The legacy free-carriage root is
disabled so free rides still pass through the same hazard checks. The carriage
alpha does not alter ferry dialogue. A separate Lake Honrich boat module adds
one new top-level line to CFTO Route 2 ferrymen without overriding CFTO's
existing destination dialogue.

When the player asks a driver for a ride:

1. A player quest alias registers for `Dialogue Menu`, re-registering after
   every save load. When the menu opens, it resolves the actor under the
   crosshair and refreshes that driver's complete origin quote set.
2. The route service evaluates at most three precompiled candidates per
   destination.
3. It reads live `Location.IsCleared()`, mound-activation state, and Civil War
   completion state.
4. For the beta, it prices active/unknown hazards but retains every executable candidate.
5. It publishes the cheapest remaining fare and travel-time estimate to shared
   per-destination globals used by CFTO's existing topics.
6. Selecting a destination re-evaluates the quote, charges the player, writes
   CFTO's `KmodCarriageDestination`, and wakes the existing driver script.

Drivers in CFTO's free-carriage faction see zero-cost quotes and are not charged,
but availability is evaluated exactly like a paid trip.

No pathfinding occurs in Papyrus.

The root carriage INFO still carries `DNT_PrepareOrigin.Fragment_0`, but it is a
cache-aware fallback. If the menu listener already completed the current
speaker's quote set, the fragment reuses it instead of clearing the globals.
This separation is deliberate: INFO `OnBegin` is late enough that Skyrim can
snapshot the first refreshed destination before the remaining route evaluations
finish. The listener quest and its player alias are start-game enabled and
shipped with `Seq\DiegeticTravel.seq`.

The Pascal generator does not write the SEQ binary directly. It follows xEdit's
own eligibility rule—new start-game-enabled quests, plus overrides that newly
enable the flag—and emits their fixed FormIDs as text. The PowerShell launcher
validates those IDs and serializes each as a four-byte little-endian entry.
Keeping binary output outside JvInterpreter avoids its variant/buffer
marshalling behavior.

## Provider separation

The authored graph contains carriage and provisional ferry edges. A carriage
driver must not silently route the player onto a ferry, so compilation creates a
separate graph per provider. The beta emits only the carriage network.

CFTO's four ferry route factions, ferrymen, destination INFOs, price globals,
and travel fragments have now been decoded independently. Two isolated public
triangles use the same provider contract:

```text
Riften <-> Heartwood Mill <-> Ivarstead
Brittleshin Pass <-> Half-Moon Mill <-> Guardian Stones
Raven Rock <-> Tel Mithryn <-> Skaal Village
```

The boat plugin adds a start-game-enabled provider/service quest and a cloned,
re-owned top-level dialogue branch. Its INFO requires both CFTO's general
travel-dialogue faction and the lane's Route 2 or Route 3 faction, uses
Dawnguard's shared voiced “Where are you headed?” response, and opens the generic parchment
on `OnEnd`. Selection returns a stable stop ID; the service then revalidates the
speaker, destination, current `KmodFerryCostLocal`, and player gold before one
charge. Execution mirrors the installed CFTO fragments: fade, temporary
over-encumbrance allowance, `Game.FastTravel`, and each stop's dedicated
companion markers. CFTO's ordinary dialogue remains the fallback.

Honeyside and Lakeview Manor are not treated as public peers because their CFTO
dialogue is conditional on private ownership and ferryman/jetty state.
Ilinata's Deep is destination-only and uses the 50-gold regional fare. These
extensions remain deferred rather than weakening the public-lane contract.
The same rule keeps Northshore Landing and Bujold's Retreat out of the public
Solstheim triangle: both are CFTO destination-only records without Route 4
service providers.

The carriage parchment adapter is intentionally thinner than the boat service.
It resolves the existing `DNT_OriginService` for the speaker, publishes live
hazard-aware quotes through that service, and draws only available capital
routes. Selection is sent back to `DNT_TravelCoordinator.Purchase`; the core
then repeats the quote, checks free-driver and gold state, writes
`KmodCarriageDestination`, and wakes CFTO's driver. The adapter therefore owns
presentation and selection state only. Its first vertical slice is nine hold
capitals; the existing 27-topic dialogue remains the fallback until density and
real-ride behavior are proven.

## Hazard state model

| Class | Dormant | Active | Cleared |
| --- | --- | --- | --- |
| Bandit | n/a | location not cleared | `Location.IsCleared()` |
| Civil War fort | n/a | location not cleared and war unresolved | cleared or war resolved |
| Giant camp | n/a | always; static toll | n/a |
| Dragon mound | activation ref disabled | activation ref enabled and not cleared | `Location.IsCleared()` or verified mound dragon dead |

Active and unknown hazards add a surcharge. Chokepoint refusal remains reserved
in the compiled schema for a post-beta design pass; it does not remove an
otherwise executable CFTO destination from the beta map.

Unknown state is never silently treated as safe. The reference evaluator treats
it conservatively as active, while the release compiler rejects incomplete
sensors.

## Generated data

`runtime.json` is shaped for JContainers and includes only what Papyrus needs:
rules, nodes, hazards, and the provider-specific candidate table. Bethesda forms
are emitted as JContainers `__formData|Plugin|0xID` references.

`hazard_sensors.json` corrects the design graph's presentation-oriented `marker`
field with the disabled/enabled references held by `dunDragonMoundQST` or the
persistent mound dragon itself. These activation references—not world-map
markers—supply dormancy state. Verified actor references can also use death as
the cleared state where no reliable cleared `Location` exists.

`dialogue_manifest.json` contains stable editor IDs for generated globals and the
CFTO destination integer for each supported stop. Helgen and Granite Hill remain
explicit custom-transport endpoints and are not emitted into CFTO dialogue until
their travel handoff is implemented.

The xEdit generator resolves those editor IDs to plugin-local form references and
writes `dialogue_runtime.json`. Each origin quest has only ordinary scalar VMAD
properties plus an origin ID; its route entries and generated globals are loaded
through JContainers. This keeps the generated quest records simple and avoids
large, brittle Papyrus property arrays.

## Generator lifecycle

xEdit's `-script` switch forces Script mode. In xEdit 4.1.x, the command-line
parser only honors `-autoload` and `-autoexit` in Edit mode, and Quick Edit is
explicitly incompatible with other tool modes. The repository carries a narrow
source patch that enables those two existing flags in Script mode. The launcher
defaults to the locally built patched executable, uses `-P` to preselect only
CFTO and its dependencies, runs hidden against copied staging data, and exits
after the Pascal generator writes `xedit_generator.status`. Managed Windows UI
Automation remains only as an explicit stock-executable fallback.

The first full patched carriage run exposed a generator bug rather than a CLI
bug: the script copied a complete player alias and then tried to rewrite its
`Specific Reference` union through `ALFR`. xEdit correctly rejects editing that
non-editable union container. Removing the redundant assignment made the full
29-stop/812-route alpha build complete headlessly with 11 SEQ quest IDs.

The behavior is visible in xEdit's own source:
[`CheckForcedMode`](https://github.com/TES5Edit/TES5Edit/blob/fd1e36020b2b5b6217e553dc0038983146a2e2dd/xEdit/xeInit.pas#L708-L727),
the Edit-only auto flags
([`xeInit.pas`](https://github.com/TES5Edit/TES5Edit/blob/fd1e36020b2b5b6217e553dc0038983146a2e2dd/xEdit/xeInit.pas#L1217-L1243)),
and the module selector fallback
([`xeMainForm.pas`](https://github.com/TES5Edit/TES5Edit/blob/fd1e36020b2b5b6217e553dc0038983146a2e2dd/xEdit/xeMainForm.pas#L5455-L5483)).
