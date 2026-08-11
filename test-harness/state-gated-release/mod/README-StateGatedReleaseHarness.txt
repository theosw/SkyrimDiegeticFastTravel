Diegetic Travel state-gated release harness

TEST ONLY. Use only on a disposable copy of a save and reload that save after
every scenario. Do not save after running these batches.

Console commands:
  bat dnt_gates_lock_all
  bat dnt_gates_unlock_all
  bat dnt_gate_honeyside_lock / bat dnt_gate_honeyside_unlock
  bat dnt_gate_lakeview_lock  / bat dnt_gate_lakeview_unlock
  bat dnt_gate_windstad_lock  / bat dnt_gate_windstad_unlock
  bat dnt_gate_heljarchen_lock / bat dnt_gate_heljarchen_unlock
  bat dnt_gate_volkihar_lock   / bat dnt_gate_volkihar_unlock

Convenience teleports:
  bat dnt_goto_honeyside_ferry
  bat dnt_goto_lakeview_ferry
  bat dnt_goto_windstad_ferry
  bat dnt_goto_icewater_ferry

Apparition Travel setup:
  bat dnt_apparition_add
  bat dnt_apparition_remove

The add batch teaches the lesser power. Activate Apparition Travel in game to
turn instant travel on; use the power again to turn it off. Wait for the
"Apparition Travel dispelled!" message before running dnt_apparition_remove.
The remove batch only unlearns the power and does not perform the toggle's
cleanup. Removing it while active can leave fFastTravelSpeedMult at 100000.
