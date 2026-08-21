# Quest-gated and deferred travel destinations

This ledger distinguishes destinations hidden by game state from valid one-way
destinations that merely lack a provider at the far end. Diegetic Travel should
mirror the source mod's eligibility; it must not globally unlock a destination
or invent a return provider.

## CFTO: state-gated ferry destinations

| Destination / service | Proven source condition | Implemented behavior |
| --- | --- | --- |
| Windstad Manor ferry | CFTO owns the private placed ferryman's enable state. | Exact actor whitelist; provider/destination shown only while placed ref `014C8A` is enabled; regional fare and dedicated follower/horse markers retained. |
| Lakeview Manor ferry | CFTO owns the private placed ferryman's enable state. | Exact actor whitelist; provider/destination shown only while placed ref `014C81` is enabled; local fare and dedicated follower/horse markers retained. |
| Honeyside ferry | CFTO owns the private placed ferryman's enable state. | Exact actor whitelist; provider/destination shown only while placed ref `014C8D` is enabled; local fare retained. |
| Castle Volkihar / Icewater Jetty | CFTO exposes `KmodFerryVolkihar`, `KmodFerryCostExtra`, and the distinct Enthralled Ferryman. | Provider/destination shown at state >= 1; outbound fare is the live extra-fare global (100 fallback), return source is free, and dedicated companion markers are retained. |

## CFTO: Hearthfire carriage destinations and private origins

Lakeview Manor, Heljarchen Hall, and Windstad Manor are already present in the
carriage parchment network. The current beta shows each only while its
Hearthfire map marker is enabled. The private return path recognizes only
CFTO's exact Gunjar, Engar, and Markus bases after confirming membership in
`KmodCarriageFreeFaction`; it then reuses the existing quest-locked source IDs
and zero-fare purchase path. Independent xEdit and package audits cover those
records and mappings. Gameplay still needs to prove all three map opens and at
least one free trip, and the marker gate still needs comparison with CFTO's
complete destination dialogue conditions before publication.

## Journey to Baan Malur: faction-unlocked ports

Captain Remyris's optional add-on network is Raven Rock, Baan Malur, and
Cormaris. Six additional destinations are described by hidden check actors or
source quest stages; only the verified one-way Sunmul trip is enabled in the
add-on beta:

| Destination | Proven unlock faction / check actor |
| --- | --- |
| Pryai | `SOMRBoatHirePryai` via `SOMRBoatTravelPryaiCheck` |
| Llethrin Fel | `SOMRBoatHireLlethrinFel` |
| Sunmul | Verified source quest stage 5 works as an outbound destination, but no return provider currently exists. The optional add-on exposes it from all three public captains and marks every occurrence one-way. |
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
- Sunmul (Baan Malur stage 5, from all three public captains)

The carriage network has a separate destination-only classification based on
CFTO's placed carriage drivers plus LoreRim's installed **Wait Carriage in Inns**
service. These nine CFTO destinations have neither a physical driver nor an
eligible inn from which a return carriage can be requested:

- Darkwater Crossing
- Mixwater Mill
- Half-Moon Mill
- Karthwasten
- Soljund's Sinkhole
- Shor's Stone
- Heartwood Mill
- Stonehills
- Thalmor Embassy

Rorikstead is not one-way: Frostfruit Inn is an eligible request origin. The
same inn-return rule covers Kynesgrove, Riverwood, Old Hroldan, Dragon Bridge,
Ivarstead, and Nightgate Inn. Lakeview Manor, Heljarchen Hall, and Windstad
Manor have conditional return service through their hireable Hearthfire
carriages. Without `WaitCarriageInns.esp`, the seven inn-only origins above are
destination-only under CFTO itself; the beta classification is therefore
explicitly LoreRim/WCI-aware.

All four are now structurally implemented with explicit `available_from`
provider lists and no source actor. Gameplay verification remains before the
beta package is promoted.

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

The release harness is implemented at `test-harness/state-gated-release` as a
plugin-free MO2 mod containing only console batch files. Its commands use
stable EditorIDs, never `prid` or load-order-prefixed FormIDs, and deliberately
provide no restore batch. The only supported restore operation is reloading the
pre-command disposable save. The full matrix and log oracle are documented in
`docs/STATE_GATED_RELEASE_TEST.md`.

## Recommended implementation order

1. **Implemented:** four CFTO one-way destinations, restricted to their original providers.
2. **Implemented:** three private-property services delegated to CFTO's live
   placed-ref enable state.
3. **Implemented:** Castle Volkihar availability, extra outbound fare, free
   return, and distinct Enthralled Ferryman using CFTO's live globals.
4. **Optional add-on:** Captain Remyris's three public merchant stops are
   packaged in a separate ESP-FE so the main release never acquires a Journey
   to Baan Malur master.
5. **Optional add-on:** Raven Rock, Baan Malur, and Cormaris -> Sunmul stage 5
   are exposed as one-way. The
   other five Baan Malur ports remain deferred until their areas, original
   unlock conditions, and return services are complete and verified.
