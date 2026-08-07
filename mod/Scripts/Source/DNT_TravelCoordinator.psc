Scriptname DNT_TravelCoordinator extends Quest

String Property DialoguePath = "Data/SKSE/Plugins/DiegeticTravel/dialogue_runtime.json" Auto

Int _dialogue
Actor _preparedSpeaker
Bool _quotesReady = False
Bool _quotesPreparing = False

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
        _quotesPreparing = False
        Return False
    EndIf

    If _quotesPreparing
        Int waitTicks = 0
        While _quotesPreparing && waitTicks < 300
            Utility.Wait(0.1)
            waitTicks += 1
        EndWhile
        If _quotesReady && _preparedSpeaker == speaker
            Debug.Trace("[DNT] MENU_QUOTES_COALESCED speaker=" + speaker + " waitTicks=" + waitTicks)
            Return True
        EndIf
        If _quotesPreparing
            Debug.Trace("[DNT] MENU_QUOTES_TIMEOUT speaker=" + speaker + " waitTicks=" + waitTicks, 1)
            Return False
        EndIf
    EndIf

    _preparedSpeaker = speaker
    _quotesReady = False
    _quotesPreparing = True
    ClearDestinationGlobals()
    Int availableCount = service.RefreshQuotesForSpeaker(speaker)
    _quotesReady = True
    _quotesPreparing = False
    Debug.Trace("[DNT] MENU_QUOTES_READY origin=" + service.OriginId + " available=" + availableCount + " speaker=" + speaker)
    Return True
EndFunction

Bool Function EnsureQuotesForSpeaker(ObjectReference speakerRef)
    Actor speaker = speakerRef as Actor
    If speaker && _quotesReady && _preparedSpeaker == speaker
        Debug.Trace("[DNT] MENU_QUOTES_REUSED speaker=" + speaker)
        Return True
    EndIf
    Return PreloadForSpeaker(speakerRef)
EndFunction

Function PrepareForSpeaker(ObjectReference speakerRef)
    If !EnsureQuotesForSpeaker(speakerRef)
        Debug.Trace("[DNT] MENU_QUOTES_FALLBACK_FAILED speaker=" + (speakerRef as Actor), 1)
    EndIf
EndFunction

Bool Function Purchase(String destinationId, ObjectReference speakerRef)
    DNT_OriginService service = GetOriginService(speakerRef as Actor)
    If !service
        Return False
    EndIf
    Return service.PurchaseDestination(destinationId, speakerRef as Actor)
EndFunction
