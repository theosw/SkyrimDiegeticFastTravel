Diegetic Travel - Wizard Guides (Phase 1)

Requires:
- Skyrim Special Edition
- Update.esm

Load DiegeticTravelWizardGuides.esp after its masters.

This phase exposes the first College-centred travel star:
- Farengar Secret-Fire -> College of Winterhold
- Wylandriah -> College of Winterhold
- Sybille Stentor -> College of Winterhold
- Wuunferth the Unliving -> College of Winterhold
- Calcelmo -> College of Winterhold
- permanent College faculty -> Whiterun, Riften, Solitude, Windhelm, or Markarth

Every hop costs 250 gold. Travel is immediate and does not advance time or
provide rest/recovery.

This module is independent of CFTO and Better Carriage Destinations. It does not
override vanilla dialogue records.

Terminal replies reuse short voiced vanilla response data: Farengar says
"Yes.", while Wylandriah, Sybille, Wuunferth, Calcelmo, and College faculty say
"Of course." after a destination is chosen. The service is available to
permanent College members at faction rank 3 or higher; students are excluded.
Mirabelle's unique voice does not ship this generic line, so her confirmation is subtitle-only. The
branching hub uses the owned forced subtitle "Where do you need to go?" so its
custom submenu advances reliably. Destination fragments run on begin, wait one
second for the conversation to close, then call the central payment and
teleport service. Insufficient funds show an explicit message and charge
nothing. The insufficient-funds message uses the normal top-left notification
area rather than a modal box. A successful payment plays Skyrim's vanilla
ITMGoldDown transaction sound. Papyrus travel traces include the initiating
speaker reference.

Use a fresh test game or a save made before this plugin was installed so the
start-game-enabled dialogue quest is initialized from its shipped SEQ file.
