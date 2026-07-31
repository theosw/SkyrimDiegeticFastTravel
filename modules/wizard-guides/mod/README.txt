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

The prototype replies are unvoiced, forced subtitles. Phinis's root response
opens the two destination topics; the destination fragments run on begin, wait
one second for the conversation to close, then call the central payment and
teleport service. Insufficient funds show an explicit message and charge
nothing.

Use a fresh test game or a save made before this plugin was installed so the
start-game-enabled dialogue quest is initialized from its shipped SEQ file.
