Diegetic Travel - Wizard Guides (Phase 1)

Requires:
- Skyrim Special Edition
- Update.esm

Load DiegeticTravelWizardGuides.esp after its masters.

This phase exposes the first two-way College-centred travel slice:
- Farengar Secret-Fire -> College of Winterhold
- Phinis Gestor -> Whiterun

Every hop costs 250 gold. Travel is immediate and does not advance time or
provide rest/recovery.

This module is independent of CFTO and Better Carriage Destinations. It does not
override vanilla dialogue records.

The prototype replies are unvoiced, forced subtitles. The dialogue fragments
run on begin, wait one second for the conversation to close, then call the
central payment and teleport service.

Use a fresh test game or a save made before this plugin was installed so the
start-game-enabled dialogue quest is initialized from its shipped SEQ file.
