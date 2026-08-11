Scriptname DNT_NorthCoastBoatParchmentPicker extends Quest

DNT_NorthCoastBoatTravelService Property Service Auto

ObjectReference CurrentSource
String ActiveSourceId = ""
String ActiveRequest = ""
Int RequestSerial = 0
Int SelectionCount = 0
String[] SelectionIds

Function OpenMap(ObjectReference SourceRef)
    If ActiveRequest != ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=north_coast source=" + SourceRef + " reason=already_open", 1)
        Return
    EndIf

    ActiveSourceId = Service.GetSourceId(SourceRef)
    If ActiveSourceId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=north_coast source=" + SourceRef + " reason=invalid_provider", 1)
        Return
    EndIf

    ActiveRequest = "opening"
    CurrentSource = SourceRef
    Utility.Wait(0.1)

    Bool DialogueWasOpen = UI.IsMenuOpen("Dialogue Menu")
    If DialogueWasOpen
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_CLOSE_REQUEST lane=north_coast source=" + ActiveSourceId)
        If !DNT_ParchmentNative.RequestDialogueClose()
            AbortOpen("dialogue_close_request_failed")
            Return
        EndIf
    Else
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_ALREADY_CLOSED lane=north_coast source=" + ActiveSourceId)
    EndIf

    Int DialogueWaitTicks = 0
    While UI.IsMenuOpen("Dialogue Menu") && DialogueWaitTicks < 50
        Utility.Wait(0.1)
        DialogueWaitTicks += 1
    EndWhile
    If UI.IsMenuOpen("Dialogue Menu")
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_TIMEOUT lane=north_coast source=" + ActiveSourceId + " waitTicks=" + DialogueWaitTicks, 1)
        AbortOpen("dialogue_timeout")
        Return
    EndIf
    Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_COMPLETE lane=north_coast source=" + ActiveSourceId + " closeRequested=" + DialogueWasOpen + " waitTicks=" + DialogueWaitTicks)
    Utility.Wait(0.15)

    If !DNT_ParchmentNative.IsAvailable()
        AbortOpen("native_unavailable")
        Return
    EndIf

    RequestSerial += 1
    ActiveRequest = "boat-north-coast-" + RequestSerial
    RegisterForModEvent("DNT_ParchmentResult", "OnParchmentResult")
    String MapTexturePath = "Data/textures/dungeons/imperial/battlemap01.dds"
    Float MapAspectRatio = 1.358090
    If !DNT_ParchmentNative.BeginRequest(ActiveRequest, "boat", SourceRef, MapTexturePath, MapAspectRatio, 0.0, 0.0, 1.0, 0.736328)
        AbortOpen("begin_failed")
        Return
    EndIf
    Bool FerryStyleReady = DNT_ParchmentNative.SetMarkerTextures(ActiveRequest, "Data/textures/DiegeticTravel/docks-marker.dds", "Data/textures/DiegeticTravel/docks-marker.dds")
    FerryStyleReady = DNT_ParchmentNative.SetOriginMarkerTexture(ActiveRequest, "Data/textures/DiegeticTravel/shipwreck-marker.dds") && FerryStyleReady
    FerryStyleReady = DNT_ParchmentNative.SetSelectionRingTexture(ActiveRequest, "Data/textures/DiegeticTravel/parchment-thin-selection-ring.dds") && FerryStyleReady
    FerryStyleReady = DNT_ParchmentNative.SetSelectionRingScale(ActiveRequest, 1.88) && FerryStyleReady
    ClearSelections()
    Bool AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, GetSourceLabel(ActiveSourceId)) && FerryStyleReady
    AddedAll = DNT_ParchmentNative.SetPaymentLabelPosition(ActiveRequest, 0.647846, 0.899624) && AddedAll
    AddedAll = SetRouteOrigin(ActiveSourceId) && AddedAll
    AddedAll = AddStop("dawnstar", "Dawnstar", 0.562613, 0.139944) && AddedAll
    AddedAll = AddStop("solitude", "Solitude", 0.343646, 0.176873) && AddedAll
    AddedAll = AddStop("windhelm", "Windhelm", 0.825231, 0.399423) && AddedAll
    AddedAll = AddStop("morthal", "Morthal", 0.404470, 0.256564) && AddedAll
    AddedAll = AddStop("solitude_lighthouse", "Solitude Lighthouse", 0.380140, 0.082606) && AddedAll
    AddedAll = AddStop("winterhold", "Winterhold", 0.730059, 0.137028) && AddedAll
    AddedAll = AddStop("dragon_bridge", "Dragon Bridge", 0.243465, 0.226437) && AddedAll
    AddedAll = AddStop("frostflow_lighthouse", "Frostflow Lighthouse", 0.629774, 0.159475) && AddedAll
    AddedAll = AddStop("windstad_manor", "Windstad Manor", 0.427903, 0.159475) && AddedAll
    AddedAll = AddStop("icewater_jetty", "Icewater Jetty", 0.122369, 0.097021) && AddedAll
    AddedAll = AddInactiveMainlandLandmarks() && AddedAll
    If !AddedAll || SelectionCount <= 0
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("destination_setup_failed")
        Return
    EndIf
    If !DNT_ParchmentNative.Show(ActiveRequest)
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("show_failed")
        Return
    EndIf
    Debug.Trace("[DNT] BOAT_PARCHMENT_OPEN lane=north_coast source=" + ActiveSourceId + " destinations=" + SelectionCount + " request=" + ActiveRequest)
EndFunction

Bool Function AddInactiveMainlandLandmarks()
    ; Lake Honrich route.
    Bool AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.905132, 0.835295)
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.812988, 0.805703) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.688477, 0.724801) && AddedAll
    ; Lake Ilinalta route.
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.448478, 0.683198) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.396241, 0.692916) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.501218, 0.685304) && AddedAll
    Return AddedAll
EndFunction

String Function GetSourceLabel(String SourceId)
    If SourceId == "dawnstar"
        Return "Dawnstar"
    ElseIf SourceId == "solitude"
        Return "Solitude"
    ElseIf SourceId == "windhelm"
        Return "Windhelm"
    ElseIf SourceId == "morthal"
        Return "Morthal"
    ElseIf SourceId == "solitude_lighthouse"
        Return "Solitude Lighthouse"
    ElseIf SourceId == "winterhold"
        Return "Winterhold"
    ElseIf SourceId == "dragon_bridge"
        Return "Dragon Bridge"
    ElseIf SourceId == "windstad_manor"
        Return "Windstad Manor"
    ElseIf SourceId == "icewater_jetty"
        Return "Icewater Jetty"
    EndIf
    Return ""
EndFunction

Bool Function SetRouteOrigin(String SourceId)
    If SourceId == "dawnstar"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.562613, 0.139944)
    ElseIf SourceId == "solitude"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.343646, 0.176873)
    ElseIf SourceId == "windhelm"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.825231, 0.399423)
    ElseIf SourceId == "morthal"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.404470, 0.256564)
    ElseIf SourceId == "solitude_lighthouse"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.380140, 0.082606)
    ElseIf SourceId == "winterhold"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.730059, 0.137028)
    ElseIf SourceId == "dragon_bridge"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.243465, 0.226437)
    ElseIf SourceId == "windstad_manor"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.427903, 0.159475)
    ElseIf SourceId == "icewater_jetty"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.122369, 0.097021)
    EndIf
    Return False
EndFunction

Bool Function AddStop(String DestinationId, String DestinationName, Float MapX, Float MapY)
    If DestinationId == ActiveSourceId
        Return True
    EndIf
    If !Service.CanOfferDestination(DestinationId, ActiveSourceId)
        Return True
    EndIf
    Int Fare = Service.GetFareForSource(DestinationId, ActiveSourceId)
    If Fare < 0 || !RecordSelection(DestinationId)
        Return False
    EndIf
    Bool Added = DNT_ParchmentNative.AddDestination(ActiveRequest, DestinationId, DestinationName + " ", Fare, MapX, MapY)
    If Added && DestinationId == "frostflow_lighthouse"
        Added = DNT_ParchmentNative.SetDestinationSelectionRingTexture(ActiveRequest, DestinationId, "Data/textures/DiegeticTravel/parchment-thin-oneway-selection-ring.dds")
    EndIf
    Return Added
EndFunction

Function ClearSelections()
    SelectionCount = 0
    SelectionIds = new String[10]
EndFunction

Bool Function RecordSelection(String DestinationId)
    If SelectionCount < 0 || SelectionCount >= 10
        Return False
    EndIf
    SelectionIds[SelectionCount] = DestinationId
    SelectionCount += 1
    Return True
EndFunction

String Function SelectionAt(Int SelectionIndex)
    If SelectionIndex >= 0 && SelectionIndex < SelectionCount
        Return SelectionIds[SelectionIndex]
    EndIf
    Return ""
EndFunction

Function AbortOpen(String Reason)
    Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=north_coast source=" + ActiveSourceId + " request=" + ActiveRequest + " reason=" + Reason, 1)
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    ActiveSourceId = ""
    CurrentSource = None
    ClearSelections()
    Debug.Notification("The ferry map could not be opened. Ask for the usual destinations instead.")
EndFunction

Event OnParchmentResult(String EventName, String StringArg, Float NumberArg, Form Sender)
    If EventName != "DNT_ParchmentResult" || StringArg != ActiveRequest
        Return
    EndIf

    Int SelectionIndex = NumberArg as Int
    ObjectReference SourceRef = CurrentSource
    String SourceId = ActiveSourceId
    String FinishedRequest = ActiveRequest
    String DestinationId = SelectionAt(SelectionIndex)
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    ActiveSourceId = ""
    CurrentSource = None
    ClearSelections()

    If SelectionIndex < 0
        Debug.Trace("[DNT] BOAT_PARCHMENT_CANCEL lane=north_coast source=" + SourceId + " request=" + FinishedRequest)
        Return
    EndIf
    If DestinationId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_REJECT lane=north_coast source=" + SourceId + " request=" + FinishedRequest + " reason=unknown_index index=" + SelectionIndex, 1)
        Return
    EndIf

    Debug.Trace("[DNT] BOAT_PARCHMENT_SELECT lane=north_coast source=" + SourceId + " request=" + FinishedRequest + " destination=" + DestinationId)
    Service.RequestTravel(DestinationId, SourceRef)
EndEvent
