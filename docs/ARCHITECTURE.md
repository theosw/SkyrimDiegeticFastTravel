# Architecture

## Runtime boundary

CFTO remains responsible for carriage drivers, seating, scenes, and travel. This
mod overrides CFTO's existing paid-carriage root and 27 existing destination
topics; it does not redistribute CFTO assets. The legacy free-carriage root is
disabled so free rides still pass through the same availability checks. The carriage
alpha does not alter ferry dialogue. A separate Lake Honrich boat module adds
one new top-level line to CFTO Route 2 ferrymen without overriding CFTO's
existing destination dialogue.

When the player asks a driver for a ride:

1. A player quest alias registers for `Dialogue Menu`, re-registering after
   every save load. When the menu opens, it resolves the actor under the
   crosshair and refreshes that driver's complete origin quote set.
2. The flat route service checks the destination and any Hearthfire gate.
3. It reads CFTO's local, standard, or extra carriage-cost global.
4. It publishes availability and fare to shared per-destination globals.
5. Selecting a destination repeats those checks, charges once, and travels to
   CFTO's own arrival marker.

Drivers in CFTO's free-carriage faction see zero-cost quotes and are not charged,
but availability is evaluated exactly like a paid trip.

No pathfinding, route candidate evaluation, hazard pricing, or hour estimation
occurs in Papyrus.

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

Each provider owns a fixed stop set and service rules. Carriage travel uses
CFTO's 27 carriage destination numbers; each ferry module preserves its own
CFTO lane and private/destination-only gates. No provider shares a runtime
route graph with another.

CFTO's four ferry route factions, ferrymen, destination INFOs, price globals,
and travel fragments have now been decoded independently. Two isolated public
triangles use the same provider contract:

```text
Riften <-> Heartwood Mill <-> Ivarstead
Brittleshin Pass <-> Half-Moon Mill <-> Guardian Stones
Raven Rock <-> Tel Mithryn <-> Skaal Village
```

The boat plugin adds a start-game-enabled provider/service quest and a cloned,
re-owned top-level dialogue branch. Its INFO requires CFTO's general
travel-dialogue faction plus an exact lane-specific actor whitelist, uses
Dawnguard's shared voiced “Where are you headed?” response, and opens the generic parchment
on `OnEnd`. Selection returns a stable stop ID; the service then revalidates the
speaker, destination, current `KmodFerryCostLocal`, and player gold before one
charge. Execution mirrors the installed CFTO fragments: fade, temporary
over-encumbrance allowance, normal `Game.FastTravel`, and each stop's dedicated
companion markers. If the optional Wizarding Traversal Apparition holder effect
is active, the shared travel helper substitutes `MoveTo` so the same trip takes
no time. CFTO's ordinary dialogue remains the fallback.

Honeyside, Lakeview Manor, and Windstad Manor are private peers only while
CFTO's placed service refs are enabled. Icewater/Volkihar instead follows
CFTO's dedicated state global and preserves its extra outbound/free-return fare.
Destination-only stops are a separate runtime type: they have an arrival
marker, fare, map position, and explicit `available_from` provider set, but no
service NPC and no source identity. Ilinata's Deep uses that type with the
50-gold regional fare; Frostflow Lighthouse, Northshore Landing, and Bujold's
Retreat use it with their original public routes. This preserves one-way travel
without inventing return services.

The carriage parchment adapter is intentionally thinner than the boat service.
It resolves the existing `DNT_OriginService` for the speaker, publishes CFTO
tier fares through that service, and draws the available native destinations.
Selection is sent back to `DNT_TravelCoordinator.Purchase`; the core
then repeats the quote, checks free-driver and gold state, writes
`KmodCarriageDestination`, and wakes CFTO's driver. The adapter therefore owns
presentation and selection state only. Its first vertical slice is nine hold
capitals; the existing 27-topic dialogue remains the fallback until density and
real-ride behavior are proven.

## Deferred route model

Road edges, live hazards, candidate paths, variable rates, and predicted travel
hours are explicitly outside the beta. The earlier compiler and sensor research
remain useful evidence, but nothing from that model is loaded or packaged by
the release build. It can be redesigned after release against observed Skyrim
time passage instead of presenting false precision.

## Generated data

`dialogue_manifest.json` contains stable editor IDs for availability/cost
globals, CFTO destination integers, origin drivers, and copied dialogue forms.
It is generated directly from `cfto_endpoints.json` plus a display-name table.
It contains no routes or hours. Helgen and Granite Hill remain explicit deferred
custom endpoints.

The xEdit generator resolves those editor IDs to plugin-local form references and
writes `dialogue_runtime.json`. Each origin quest has only ordinary scalar VMAD
properties plus an origin ID; its destination entries and generated globals are loaded
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
legacy alpha build complete headlessly. The beta generator now emits only the
flat destination contract and its start-game quest IDs.

The behavior is visible in xEdit's own source:
[`CheckForcedMode`](https://github.com/TES5Edit/TES5Edit/blob/fd1e36020b2b5b6217e553dc0038983146a2e2dd/xEdit/xeInit.pas#L708-L727),
the Edit-only auto flags
([`xeInit.pas`](https://github.com/TES5Edit/TES5Edit/blob/fd1e36020b2b5b6217e553dc0038983146a2e2dd/xEdit/xeInit.pas#L1217-L1243)),
and the module selector fallback
([`xeMainForm.pas`](https://github.com/TES5Edit/TES5Edit/blob/fd1e36020b2b5b6217e553dc0038983146a2e2dd/xEdit/xeMainForm.pas#L5455-L5483)).
