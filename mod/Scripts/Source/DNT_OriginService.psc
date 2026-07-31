Scriptname DNT_OriginService extends Quest

DNT_RouteService Property RouteService Auto
Quest Property KmodFastTravelQuest Auto
GlobalVariable Property KmodCarriageDestination Auto
Faction Property KmodCarriageFreeFaction Auto
Actor Property PlayerRef Auto
MiscObject Property Gold001 Auto

String Property OriginId Auto
String Property DialoguePath = "Data/SKSE/Plugins/DiegeticTravel/dialogue_runtime.json" Auto

Int _dialogue

Bool Function LoadDialogue()
    If _dialogue != 0
        JValue.release(_dialogue)
        _dialogue = 0
    EndIf

    _dialogue = JValue.readFromFile(DialoguePath)
    If _dialogue == 0
        Debug.Trace("[DNT] Could not load dialogue data: " + DialoguePath, 2)
        Return False
    EndIf

    JValue.retain(_dialogue)
    Return True
EndFunction

Bool Function EnsureDialogue()
    If _dialogue != 0
        Return True
    EndIf
    Return LoadDialogue()
EndFunction

Int Function GetEntries()
    If !EnsureDialogue()
        Return 0
    EndIf

    Int origins = JMap.getObj(_dialogue, "origins")
    Int origin = JMap.getObj(origins, OriginId)
    If origin == 0
        Debug.Trace("[DNT] Dialogue data has no origin: " + OriginId, 2)
        Return 0
    EndIf
    Return JMap.getObj(origin, "entries")
EndFunction

Int Function RefreshQuotes(Bool freeRide = False)
    Int entries = GetEntries()
    If entries == 0
        Return 0
    EndIf

    Int index = 0
    Int availableCount = 0
    While index < JArray.count(entries)
        If RefreshQuote(index, freeRide)
            availableCount += 1
        EndIf
        index += 1
    EndWhile
    Return availableCount
EndFunction

Bool Function RefreshQuote(Int index, Bool freeRide = False)
    Int entries = GetEntries()
    If entries == 0 || index < 0 || index >= JArray.count(entries)
        Return False
    EndIf

    Int entry = JArray.getObj(entries, index)
    GlobalVariable availableGlobal = JMap.getForm(entry, "available_global") as GlobalVariable
    GlobalVariable costGlobal = JMap.getForm(entry, "cost_global") as GlobalVariable
    GlobalVariable hoursGlobal = JMap.getForm(entry, "hours_global") as GlobalVariable
    If !availableGlobal || !costGlobal || !hoursGlobal
        Debug.Trace("[DNT] Dialogue globals are missing for " + OriginId + " index " + index, 2)
        Return False
    EndIf

    Bool available = RouteService.IsDestinationAvailable(JMap.getStr(entry, "destination"))
    If available
        available = RouteService.QuoteCarriageRoute(JMap.getStr(entry, "route"))
    EndIf

    If available
        availableGlobal.SetValueInt(1)
        If freeRide
            costGlobal.SetValueInt(0)
        Else
            costGlobal.SetValueInt(RouteService.GetLastFare())
        EndIf
        hoursGlobal.SetValue(RouteService.GetLastHours())
    Else
        availableGlobal.SetValueInt(0)
        costGlobal.SetValueInt(0)
        hoursGlobal.SetValue(0.0)
    EndIf

    KmodFastTravelQuest.UpdateCurrentInstanceGlobal(costGlobal)
    KmodFastTravelQuest.UpdateCurrentInstanceGlobal(hoursGlobal)
    Return available
EndFunction

Int Function RefreshQuotesForSpeaker(Actor speaker)
    Bool freeRide = KmodCarriageFreeFaction && speaker && speaker.IsInFaction(KmodCarriageFreeFaction)
    Return RefreshQuotes(freeRide)
EndFunction

Bool Function Purchase(Int index, Actor speaker)
    If !speaker
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + OriginId + " reason=speaker_none", 2)
        Return False
    EndIf

    Bool freeRide = KmodCarriageFreeFaction && speaker.IsInFaction(KmodCarriageFreeFaction)
    If !RefreshQuote(index, freeRide)
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + OriginId + " reason=route index=" + index, 2)
        Debug.Notification("That route is not safe enough to run right now.")
        Return False
    EndIf

    Int entries = GetEntries()
    Int entry = JArray.getObj(entries, index)
    String destinationId = JMap.getStr(entry, "destination")
    GlobalVariable costGlobal = JMap.getForm(entry, "cost_global") as GlobalVariable
    Int fare = costGlobal.GetValueInt()
    If !freeRide && PlayerRef.GetItemCount(Gold001) < fare
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + OriginId + " destination=" + destinationId + " reason=gold fare=" + fare)
        Debug.Notification("You do not have enough gold.")
        Return False
    EndIf

    If !freeRide
        PlayerRef.RemoveItem(Gold001, fare, False, None)
    EndIf

    Int cftoDestination = JMap.getInt(entry, "cfto_destination")
    KmodCarriageDestination.SetValueInt(cftoDestination)
    speaker.RegisterForSingleUpdate(1.0)
    Debug.Trace("[DNT] PURCHASE_COMMITTED origin=" + OriginId + " destination=" + destinationId + " fare=" + fare + " free=" + freeRide + " cfto_destination=" + cftoDestination + " speaker=" + speaker)
    Return True
EndFunction

Bool Function PurchaseDestination(String destinationId, Actor speaker)
    Int entries = GetEntries()
    Int index = 0
    While index < JArray.count(entries)
        Int entry = JArray.getObj(entries, index)
        If JMap.getStr(entry, "destination") == destinationId
            Return Purchase(index, speaker)
        EndIf
        index += 1
    EndWhile

    Debug.Trace("[DNT] Destination is not available from " + OriginId + ": " + destinationId, 2)
    Return False
EndFunction
