# Baan Malur public merchant ferry adapter

This optional ESP-FE add-on adds a parchment picker to the three unrestricted
captains in Journey to Baan Malur:

- Captain Remyris at Raven Rock
- the Baan Malur captain
- the Cormaris captain

The picker delegates selections to `SOMRFerrySystemMain` stages 1, 2, and 3.
Those mappings were proved from the source mod's compiled TIF and quest
fragments. Journey to Baan Malur therefore remains responsible for its own
30-septim check, feedback, and arrival logic.

For those three supported captains, the add-on hides Journey's parallel native
destination prompt by default. The override is provider-scoped: Journey's
prompt remains unchanged for every captain outside the add-on's provider list.
No Papyrus is used for this gate. For conflict diagnosis, restore the native
prompt for the current game with
`set DNT_ShowBaanMalurNativeDialogue to 1`; set it back to `0` afterward.

The module references the installed Solstheim and Baan Malur Paper Map for
FWMF texture. It does not package that DDS. The verified stage-5 trip to Sunmul
is also offered from all three public captains, marked with the one-way
bottom-arrow selection ring. Its absent return service is not invented. The other five
unfinished/faction-unlocked mainland ports remain deferred.

The add-on is intentionally isolated from the consolidated release. The main
`DiegeticTravel.esp` has no Journey to Baan Malur master and works unchanged
when this add-on and both of its external dependencies are absent. Users must
install the main Diegetic Fast Travel file first, then install this optional
archive only when `Journey to Baan Malur.esp` and the external paper map are
present.
