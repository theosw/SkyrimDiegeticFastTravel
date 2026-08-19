Diegetic Fast Travel - LoreRim BCD Coexistence

Requires Diegetic Fast Travel and LoreRim's enabled Better Carriage
Destinations, CFTO, and Wait Carriage in Inns adapter chain.

Load DiegeticTravelLoreRimBcdCompat.esp after DiegeticTravel.esp. The patch
keeps BCD installed and loaded but hides its competing carriage, ferry, and WCI
map dialogue so Diegetic Fast Travel's physical parchment remains authoritative.

For diagnostics only, `set DNT_ShowBcdTravelDialogue to 1` restores the three
BCD dialogue entries. The default value is 0.
