# Architecture

## Runtime boundary

CFTO remains responsible for carriage drivers, seating, scenes, and travel. This
mod overrides CFTO's existing paid-carriage root and 27 existing destination
topics; it does not redistribute CFTO assets. The legacy free-carriage root is
disabled so free rides still pass through the same hazard checks. Ferry dialogue
is untouched.

When the player asks a driver for a ride:

1. Opening carriage dialogue identifies the driver and refreshes that origin's
   quotes.
2. The route service evaluates at most three precompiled candidates per
   destination.
3. It reads live `Location.IsCleared()`, mound-activation state, and Civil War
   completion state.
4. It drops candidates blocked by an active refuse-tier chokepoint.
5. It publishes the cheapest remaining fare and travel-time estimate to shared
   per-destination globals used by CFTO's existing topics.
6. Selecting a destination re-evaluates the quote, charges the player, writes
   CFTO's `KmodCarriageDestination`, and wakes the existing driver script.

Drivers in CFTO's free-carriage faction see zero-cost quotes and are not charged,
but availability is evaluated exactly like a paid trip.

No pathfinding occurs in Papyrus.

## Provider separation

The authored graph contains carriage and provisional ferry edges. A carriage
driver must not silently route the player onto a ferry, so compilation creates a
separate graph per provider. The beta emits only the carriage network.

Ferry integration is gated on decoding the CTDA conditions that define each
ferryman's actual lanes. Until then, CFTO ferry dialogue is unchanged.

## Hazard state model

| Class | Dormant | Active | Cleared |
| --- | --- | --- | --- |
| Bandit | n/a | location not cleared | `Location.IsCleared()` |
| Civil War fort | n/a | location not cleared and war unresolved | cleared or war resolved |
| Giant camp | n/a | always; static toll | n/a |
| Dragon mound | activation ref disabled | activation ref enabled and not cleared | `Location.IsCleared()` or verified mound dragon dead |

An active chokepoint with multiplier at or above the refuse threshold blocks a
candidate. Active proximity hazards and lower-tier chokepoints add a surcharge.

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
explicitly incompatible with other tool modes. The release launcher therefore
uses `-P` to preselect only CFTO and its dependencies, invokes that dialog's OK
button through Windows UI Automation when Windows exposes the control, and
closes xEdit only after the Pascal generator writes
`xedit_generator.status`. Stock xEdit is briefly visible because a deliberately
hidden modal selector is not present in the UI Automation tree. The current
LoreRim executable has still required one manual OK click in practice. This is
scoped GUI automation around a CLI limitation; the plugin work remains in the
xEdit script.

The behavior is visible in xEdit's own source:
[`CheckForcedMode`](https://github.com/TES5Edit/TES5Edit/blob/fd1e36020b2b5b6217e553dc0038983146a2e2dd/xEdit/xeInit.pas#L708-L727),
the Edit-only auto flags
([`xeInit.pas`](https://github.com/TES5Edit/TES5Edit/blob/fd1e36020b2b5b6217e553dc0038983146a2e2dd/xEdit/xeInit.pas#L1217-L1243)),
and the module selector fallback
([`xeMainForm.pas`](https://github.com/TES5Edit/TES5Edit/blob/fd1e36020b2b5b6217e553dc0038983146a2e2dd/xEdit/xeMainForm.pas#L5455-L5483)).
