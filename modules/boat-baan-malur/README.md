# Baan Malur public merchant ferry adapter

This isolated candidate adds a parchment picker to the three unrestricted
captains in Journey to Baan Malur:

- Captain Remyris at Raven Rock
- the Baan Malur captain
- the Cormaris captain

The picker delegates selections to `SOMRFerrySystemMain` stages 1, 2, and 3.
Those mappings were proved from the source mod's compiled TIF and quest
fragments. Journey to Baan Malur therefore remains responsible for its own
30-septim check, feedback, and arrival logic.

The module references the installed Solstheim and Baan Malur Paper Map for
FWMF texture. It does not package that DDS. The six faction-unlocked mainland
ports remain deferred until their original unlock conditions are mirrored.
