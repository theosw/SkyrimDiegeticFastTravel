Scriptname DNT_TravelCoordinator extends Quest

String Property DialoguePath = "Data/SKSE/Plugins/DiegeticTravel/dialogue_runtime.json" Auto

Int _dialogue
Actor _preparedSpeaker
Bool _quotesReady = False

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

DNT_OriginService Function GetOriginService(Actor speaker, Bool traceFailure = True)
    If !speaker
        If traceFailure
            Debug.Trace("[DNT] ORIGIN_LOOKUP_FAILED reason=speaker_none", 2)
        EndIf
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

    If traceFailure
        Debug.Trace("[DNT] ORIGIN_LOOKUP_FAILED reason=unconfigured speaker=" + speaker + " base=" + speakerBase, 2)
    EndIf
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

Bool Function PreloadForSpeaker(ObjectReference speakerRef)
    Actor speaker = speakerRef as Actor
    DNT_OriginService service = GetOriginService(speaker, False)
    If !service
        _preparedSpeaker = None
        _quotesReady = False
        Return False
    EndIf

    ClearDestinationGlobals()
    Int availableCount = service.RefreshQuotesForSpeaker(speaker)
    _preparedSpeaker = speaker
    _quotesReady = True
    Debug.Trace("[DNT] MENU_QUOTES_READY origin=" + service.OriginId + " available=" + availableCount + " speaker=" + speaker)
    Return True
EndFunction

Function PrepareForSpeaker(ObjectReference speakerRef)
    Actor speaker = speakerRef as Actor
    If speaker && _quotesReady && _preparedSpeaker == speaker
        Debug.Trace("[DNT] MENU_QUOTES_REUSED speaker=" + speaker)
        Return
    EndIf

    Debug.Trace("[DNT] MENU_QUOTES_FALLBACK speaker=" + speaker)
    PreloadForSpeaker(speakerRef)
EndFunction

Bool Function Purchase(String destinationId, ObjectReference speakerRef)
    DNT_OriginService service = GetOriginService(speakerRef as Actor)
    If !service
        Return False
    EndIf
    Return service.PurchaseDestination(destinationId, speakerRef as Actor)
EndFunction
