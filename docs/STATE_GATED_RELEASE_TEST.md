# State-gated release test

This is the release-blocking matrix for CFTO private services, Hearthfire
carriage destinations, and Apparition Travel time handling.

## Safety and setup

1. Use a disposable copy of the gameplay save.
2. Enable `DiegeticTravel - State Gate Test Harness` in the
   `UltraDiegeticTravel` MO2 profile. It has no plugin and therefore no right
   pane entry.
3. Never save after running a harness batch.
4. Reload the pre-command save between scenarios. Do not try to restore the
   state by applying the inverse batch: the harness does not know the save's
   original quest state.
5. Start the monitored run with:

   `powershell -ExecutionPolicy Bypass -File tools\Run-StateGatedReleaseTest.ps1`

The harness uses stable EditorIDs. It does not use fixed load-order prefixes,
`prid`, quest stages, ownership mutations, or ConsoleUtil as a runtime
dependency.

## Scenario A: all gates locked

Run `bat dnt_gates_lock_all`, then close and reopen each relevant dialogue.

Expected:

- Honeyside is absent from the Lake Honrich parchment map.
- Lakeview Manor is absent from the Lake Ilinalta parchment map.
- Windstad Manor and Icewater Jetty are absent from the north-coast map.
- Lakeview Manor, Windstad Manor, and Heljarchen Hall are absent from the
  carriage map.
- No fare is deducted for an unavailable destination.
- No private-service marker remains clickable because of stale menu state.

Reload the disposable save.

## Scenario B: all gates unlocked

Run `bat dnt_gates_unlock_all`, then close and reopen each relevant dialogue.

Expected:

- Honeyside, Lakeview Manor, Windstad Manor, and Icewater Jetty appear only on
  their correct ferry maps.
- Lakeview Manor, Windstad Manor, and Heljarchen Hall appear on the carriage
  map.
- A private ferry trip charges the live CFTO fare exactly once and lands at
  the intended marker.
- Icewater outbound travel charges `KmodFerryCostExtra`; travel from the
  Enthralled Ferryman remains free.
- A Hearthfire carriage trip charges the displayed fare exactly once and
  lands at the configured arrival.

Convenience arrival teleports are `bat dnt_goto_honeyside_ferry`,
`dnt_goto_lakeview_ferry`, `dnt_goto_windstad_ferry`, and
`dnt_goto_icewater_ferry`.

Reload the disposable save.

## Scenario C: Apparition Travel off

Record the in-game hour, complete one representative wizard or ferry trip,
and record the hour again.

Expected:

- The log contains `TRAVEL_MODE ... apparition=False`.
- The configured travel time advances normally.
- Fare, sound, arrival, and menu cleanup still pass.

Reload the disposable save.

## Scenario D: Apparition Travel on

Run `bat dnt_apparition_add`, equip the **Apparition Travel** lesser power, and
activate it. Record the in-game hour, complete the same trip, and record the
hour again.

Expected:

- The log contains `TRAVEL_MODE ... apparition=True`.
- No travel time is added by Diegetic Travel.
- Fare, sound, arrival, and menu cleanup behave exactly as in the normal-time
  case.

Reload the disposable save.

## Save lifecycle regression

After the controlled gate matrix passes:

1. Verify a genuinely new game can see a public wizard and public carriage
   entry without console repair.
2. Verify the current existing save sees the same public services.
3. Save and reload once after an ordinary trip, then reopen each map and make
   one more trip.

The release candidate fails if a quest must be restarted, a menu requires an
extra Escape press, a destination persists after its gate is removed, or the
native log reports a warning/error/critical line.
