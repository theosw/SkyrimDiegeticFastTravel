# Quest-gated and deferred travel destinations

This ledger distinguishes destinations hidden by game state from valid one-way
destinations that merely lack a provider at the far end. Diegetic Travel should
mirror the source mod's eligibility; it must not globally unlock a destination
or invent a return provider.

## CFTO: state-gated ferry destinations

| Destination / service | Proven source condition | Required behavior | Proof still needed |
| --- | --- | --- | --- |
| Windstad Manor ferry | CFTO's paid INFO requires the player to own the Windstad jetty item (`KmodHouse2Dock == 1`). The provider is part of the private Hearthfire ferry setup. | Show the stop and provider only when CFTO's private service exists; preserve the normal ferry fare. | Verify every provider/actor construction condition in addition to the jetty item. |
| Lakeview Manor ferry | CFTO's paid INFO requires the player to own the Lakeview jetty item (`KmodHouse1Dock == 1`). | Show the stop and provider only when CFTO's private service exists; preserve the local ferry fare. | Verify every provider/actor construction condition in addition to the jetty item. |
| Honeyside ferry | CFTO tests the `HousePurchase` quest variable and distinguishes the private Honeyside ferryman from the public Riften ferryman. | Mirror the original ownership, porch, and ferryman conditions; preserve the local ferry fare. | Record the complete condition stack and the exact provider references. |
| Castle Volkihar / Icewater Jetty | CFTO uses the `KmodFerryVolkihar` global, `KmodFerryCostExtra`, a special persuasion/confirmation branch, and a free return option on the Enthralled Ferryman. | Preserve the special discovery/persuasion flow and extra fare. The Enthralled Ferryman must remain a distinct return provider. | Trace the exact original state transition that sets `KmodFerryVolkihar`; do not guess a Dawnguard quest stage. |

## CFTO: Hearthfire carriage destinations already present

Lakeview Manor, Heljarchen Hall, and Windstad Manor are already present in the
carriage parchment network. The current beta shows each only while its
Hearthfire map marker is enabled. Before release, compare that marker gate with
CFTO's complete dialogue conditions so the parchment never exposes a manor
earlier than CFTO would.

## Journey to Baan Malur: faction-unlocked ports

Captain Remyris's safe initial network is Raven Rock, Baan Malur, and Cormaris.
The other six destinations are exposed by hidden check actors joining the
source mod's destination factions:

| Destination | Proven unlock faction / check actor |
| --- | --- |
| Pryai | `SOMRBoatHirePryai` via `SOMRBoatTravelPryaiCheck` |
| Llethrin Fel | `SOMRBoatHireLlethrinFel` |
| Sunmul | `SOMRBoatHireSunmul` via `SOMRBoatTravelSunmulCheck` |
| Seyda Neen | `SOMRBoatHireSeydaNeen` |
| Vivec | `SOMRBoatHireVivec` via `SOMRBoatTravelVivecCheck` |
| Old Silgrad | `SOMRBoatHireOldSilgrad` |

The adapter should query the original factions (or the same hidden check
actors) instead of duplicating the quests. Exact quest-stage-to-faction
mappings remain unproven and must not be inferred from record order.

## Valid one-way destinations, not quest locks

These are executable destination branches, but no public provider exists at
the destination. They can be offered only from the original route(s) that
reach them and must not create a fake return service:

- Frostflow Lighthouse (north-coast Route 1 extension)
- Ilinalta's Deep (Lake Ilinalta Route 3 extension)
- Northshore Landing (Solstheim Route 4 extension)
- Bujold's Retreat (Solstheim Route 4 extension)

## Deliberately unsupported placeholders

- Helgen: CFTO has no executable destination handoff.
- Granite Hill: CFTO has no executable destination handoff.

## Test-harness policy

LoreRim currently contains ConsoleUtilSSE NG 1.5.1. Its Papyrus surface is
suitable for controlled test-save setup (`ExecuteCommand`, for example), but
it should not become a runtime dependency of Diegetic Travel.

The installed mod metadata identifies the official 1.5.1 Nexus archive. The
upstream repository currently exposes only its `master` branch, but the DLL
does not embed a source commit, so the exact commit cannot be proven from the
installation alone.

Use ConsoleUtil only in a dedicated gameplay harness to prepare ownership,
global, faction, or quest states on a disposable/copy test save. Reload the
pre-command save after each scenario. Never use target-selection-dependent
ConsoleUtil commands for runtime travel logic: selected-reference changes are
queued and are not safe to assume synchronous with the next command.

## Recommended implementation order

1. Add the four one-way destinations, restricted to their original providers.
2. Mirror the three private-property ferry gates exactly.
3. Reproduce the Castle Volkihar discovery/extra-fare/return flow after its
   state transition is fully traced.
4. **Implemented offline; live test pending:** Captain Remyris's three public
   merchant stops, in the isolated `boat-baan-malur` module.
5. Add the six Baan Malur faction-unlocked ports by querying their original
   source-mod factions.
