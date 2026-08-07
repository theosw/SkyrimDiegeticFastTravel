# Solstheim public ferry triangle

This isolated candidate gives the three public CFTO Route 4 ferrymen a diegetic
parchment picker:

- Maslyn at Raven Rock
- Bildul at Tel Mithryn
- Gauldis at Skaal Village

The service preserves CFTO's flat `KmodFerryCost` fare (50 gold in the audited
LoreRim build), uses CFTO's arrival markers, and passes time through
`Game.FastTravel` under the same fade/payment contract as the proven lake lanes.

The menu references Dragonborn's existing physical map at
`textures/dlc02/clutter/dlc2mapsolstheim02.dds`; texture replacers such as
RUSTIC MAPS are picked up automatically. The source stores the map in a narrow
1:2 panel whose geography and folds both look horizontally compressed. A live
1.5:1 correction proved too wide, so this candidate presents it square at 1:1
for visual evaluation. No artwork is bundled. A purpose-built tattered
fisherman chart remains the intended
long-term art direction once its asset contract is stable.

Northshore Landing and Bujold's Retreat remain intentionally deferred because
CFTO exposes them as destination-only extensions without public Route 4
ferrymen.
