Scriptname DNT_TravelCoordinator extends Quest

String Property DialoguePath = "Data/SKSE/Plugins/DiegeticTravel/dialogue_runtime.json" Auto

Int _dialogue

Event OnInit()
    LoadDialogue()
EndEvent

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

DNT_OriginService Function GetOriginService(Actor speaker)
    If !speaker
        Debug.Trace("[DNT] ORIGIN_LOOKUP_FAILED reason=speaker_none", 2)
        Return None
    EndIf
    If !EnsureDialogue()
        Return None
    EndIf

    Form speakerBase = speaker.GetBaseObject()
    Int services = JMap.getObj(_dialogue, "origin_services")
    Int index = 0
    While index < JArray.count(services)
        Int entry = JArray.getObj(services, index)
        Form configuredDriver = JMap.getForm(entry, "driver")
        If configuredDriver == speaker || configuredDriver == speakerBase
            DNT_OriginService service = JMap.getForm(entry, "service") as DNT_OriginService
            Debug.Trace("[DNT] ORIGIN_MATCHED origin=" + service.OriginId + " speaker=" + speaker + " base=" + speakerBase)
            Return service
        EndIf
        index += 1
    EndWhile

    Debug.Trace("[DNT] ORIGIN_LOOKUP_FAILED reason=unconfigured speaker=" + speaker + " base=" + speakerBase, 2)
    Return None
EndFunction

Function ClearDestinationGlobals()
    If !EnsureDialogue()
        Return
    EndIf

    Int destinations = JMap.getObj(_dialogue, "destination_globals")
    Int index = 0
    While index < JArray.count(destinations)
        Int entry = JArray.getObj(destinations, index)
        GlobalVariable availableGlobal = JMap.getForm(entry, "available") as GlobalVariable
        GlobalVariable costGlobal = JMap.getForm(entry, "cost") as GlobalVariable
        GlobalVariable hoursGlobal = JMap.getForm(entry, "hours") as GlobalVariable
        If availableGlobal
            availableGlobal.SetValueInt(0)
        EndIf
        If costGlobal
            costGlobal.SetValueInt(0)
        EndIf
        If hoursGlobal
            hoursGlobal.SetValue(0.0)
        EndIf
        index += 1
    EndWhile
EndFunction

Function RefreshForSpeaker(ObjectReference speakerRef)
    ClearDestinationGlobals()
    DNT_OriginService service = GetOriginService(speakerRef as Actor)
    If service
        service.RefreshQuotesForSpeaker(speakerRef as Actor)
    EndIf
EndFunction

Bool Function Purchase(String destinationId, ObjectReference speakerRef)
    DNT_OriginService service = GetOriginService(speakerRef as Actor)
    If !service
        Return False
    EndIf
    Return service.PurchaseDestination(destinationId, speakerRef as Actor)
EndFunction
