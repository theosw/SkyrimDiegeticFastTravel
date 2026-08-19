Diegetic Travel - Baan Malur public merchant ferry adapter

Requires:
- Diegetic Fast Travel (main file/native parchment runtime)
- Journey to Baan Malur.esp
- Solstheim and Baan Malur Paper Map for FWMF (texture dependency)

This is a separate optional ESP-FE. Do not install or enable it without
Journey to Baan Malur. The main DiegeticTravel.esp does not depend on this
add-on and continues to work when all Baan Malur files are absent.

Public providers:
- Captain Remyris, Raven Rock
- Baan Malur captain
- Cormaris captain

Fare and movement are delegated to Journey to Baan Malur's original ferry
quest. The external map texture is referenced but not bundled.

Journey's original destination prompt is hidden by default only for the three
public providers listed above. Other Journey captains keep their original
dialogue. For conflict diagnosis, restore the native prompt with:

set DNT_ShowBaanMalurNativeDialogue to 1

Set the global back to 0 to return to the release behavior. This visibility
gate uses dialogue conditions and adds no Papyrus polling.

Sunmul is a stage-5 one-way destination from all three public captains. Pryai, Llethrin Fel,
Seyda Neen, Vivec, and Old Silgrad remain deferred until their source areas and
unlock conditions are complete and verified.
