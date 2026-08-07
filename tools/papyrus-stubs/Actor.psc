; Minimal compile-time header for environments without Creation Kit sources.
Scriptname Actor extends ObjectReference Hidden

Bool Function IsInFaction(Faction targetFaction) Native
Bool Function IsDead() Native
Int Function GetItemCount(Form item) Native
Function RemoveItem(Form item, Int count = 1, Bool silent = False, ObjectReference otherContainer = None) Native
Float Function GetActorValue(String actorValueName) Native
Function ModActorValue(String actorValueName, Float amount) Native
