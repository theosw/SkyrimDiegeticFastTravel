Diegetic Travel - Wizard Guides (Phase 1)

Requires:
- Skyrim Special Edition
- Update.esm

Load DiegeticTravelWizardGuides.esp after its masters.

This phase exposes the first College-centred travel star:
- Farengar Secret-Fire -> College of Winterhold
- Wylandriah -> College of Winterhold
- Phinis Gestor -> Whiterun or Riften

Every hop costs 250 gold. Travel is immediate and does not advance time or
provide rest/recovery.

This module is independent of CFTO and Better Carriage Destinations. It does not
override vanilla dialogue records.

Terminal replies reuse short voiced vanilla response data: Farengar says
"Yes.", while Wylandriah and Phinis say "Of course." after a
destination is chosen. Phinis's branching hub uses the owned forced subtitle
"Where do you need to go?" so its custom submenu advances reliably. The
destination fragments run on begin, wait one second for the conversation to
close, then call the central payment and teleport service. Insufficient funds
show an explicit message and charge nothing.

Use a fresh test game or a save made before this plugin was installed so the
start-game-enabled dialogue quest is initialized from its shipped SEQ file.
