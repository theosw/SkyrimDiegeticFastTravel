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

- The log contains `APPARITION_CHECK ... active=False` followed by
  `TRAVEL_COMPAT mode=fast_travel`.
- The configured travel time advances normally.
- Fare, sound, arrival, and menu cleanup still pass.

Reload the disposable save.

## Scenario D: Apparition Travel on

Run `bat dnt_apparition_add`, equip the **Apparition Travel** lesser power, and
activate it. LoreRim's Requiem patch raises the activation cost to 600
magicka, so use `tgm` for the cast when the disposable test character cannot
pay that cost. Wait for `Apparition Travel in effect!`, run
`getgs fFastTravelSpeedMult`, record the in-game hour, complete the same trip,
and record the hour again.

Expected:

- `getgs fFastTravelSpeedMult` reports `100000` before travel.
- The log contains `APPARITION_CHECK ... active=TRUE` followed by
  `TRAVEL_COMPAT mode=apparition`.
- No travel time is added by Diegetic Travel.
- Fare, sound, arrival, and menu cleanup behave exactly as in the normal-time
  case.

Do not reload yet; continue directly into Scenario E.

## Scenario E: Apparition Travel toggled off

Equip and activate **Apparition Travel** a second time. Use `tgm` for this cast
if necessary. Wait for `Apparition Travel dispelled!`, then run
`getgs fFastTravelSpeedMult`. Only after the dispel message appears may
`bat dnt_apparition_remove` be used to unlearn the test power. Complete the
same trip once more and compare the clock.

Expected:

- `getgs fFastTravelSpeedMult` reports its normal value (`1` in the LoreRim
  release profile).
- The log contains `APPARITION_CHECK ... hasHolder=False speed=1.000000
  active=False` and normal fast-travel mode.
- Travel time advances normally again.
- Fare, sound, arrival, and menu cleanup still pass.

`player.removespell` is not a supported substitute for toggling the power off.
Removing the learned power while its holder effect is active can bypass
Wizarding Traversal's cleanup: the holder disappears but
`fFastTravelSpeedMult` remains at `100000`. If that diagnostic case is tested,
record the log and reload the disposable pre-test save immediately; do not use
the resulting state for another release assertion.

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

## Controller regression

Run this once on a provider with several spread-out destinations, using the
intended LoreRim controller stack and `No Delete Controller` compatibility mod.

1. Open the parchment without touching the mouse. Confirm that no destination
   is selected initially.
2. Press each D-pad direction and confirm the selection ring moves spatially
   between markers. Repeat with discrete left-stick tilts; a held tilt must not
   race through multiple destinations before returning through the dead zone.
3. Press A on a funded destination. Confirm only the ringed destination is
   purchased and reached, with one charge and one result event.
4. Reload, reopen the parchment, move controller focus, then press B. Confirm
   inert cancellation: no charge, no travel, and full HUD restoration.
5. Reopen, focus with the controller, then move the mouse. The controller ring
   must clear immediately; mouse hover and release-inside activation must still
   behave as before.

Expected native evidence includes `PARCHMENT_CONTROLLER_FOCUS` for each
accepted navigation step, `PARCHMENT_SELECT ... reason=gamepad_a` for confirm,
and `PARCHMENT_CANCEL ... reason=gamepad_b` for cancel. The release candidate
fails if focus appears before the first navigation input, snaps back after the
mouse takes over, moves more than once per stick tilt, or activates an
unfocused destination.
