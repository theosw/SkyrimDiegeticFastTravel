Scriptname DNT_BoatParchmentPicker extends Quest

DNT_BoatTravelService Property Service Auto

String Property TexturePath = "Data/textures/dungeons/imperial/battlemap01.dds" Auto
Float Property ArtAspectRatio = 1.358090 Auto
Float Property TextureUvMinX = 0.0 Auto
Float Property TextureUvMinY = 0.0 Auto
Float Property TextureUvMaxX = 1.0 Auto
Float Property TextureUvMaxY = 0.736328 Auto

ObjectReference CurrentSource
String ActiveSourceId = ""
String ActiveRequest = ""
Int RequestSerial = 0
Int SelectionCount = 0
String[] SelectionIds

Function OpenMap(ObjectReference SourceRef)
    If ActiveRequest != ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=lake_honrich source=" + SourceRef + " reason=already_open", 1)
        Return
    EndIf

    ActiveSourceId = Service.GetSourceId(SourceRef)
    If ActiveSourceId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=lake_honrich source=" + SourceRef + " reason=invalid_provider", 1)
        Return
    EndIf

    ActiveRequest = "opening"
    CurrentSource = SourceRef
    Utility.Wait(0.1)

    Bool DialogueWasOpen = UI.IsMenuOpen("Dialogue Menu")
    If DialogueWasOpen
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_CLOSE_REQUEST lane=lake_honrich source=" + ActiveSourceId)
        If !DNT_ParchmentNative.RequestDialogueClose()
            AbortOpen("dialogue_close_request_failed")
            Return
        EndIf
    Else
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_ALREADY_CLOSED lane=lake_honrich source=" + ActiveSourceId)
    EndIf

    Int DialogueWaitTicks = 0
    While UI.IsMenuOpen("Dialogue Menu") && DialogueWaitTicks < 50
        Utility.Wait(0.1)
        DialogueWaitTicks += 1
    EndWhile
    If UI.IsMenuOpen("Dialogue Menu")
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_TIMEOUT lane=lake_honrich source=" + ActiveSourceId + " waitTicks=" + DialogueWaitTicks, 1)
        AbortOpen("dialogue_timeout")
        Return
    EndIf
    Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_COMPLETE lane=lake_honrich source=" + ActiveSourceId + " closeRequested=" + DialogueWasOpen + " waitTicks=" + DialogueWaitTicks)
    Utility.Wait(0.15)

    If !DNT_ParchmentNative.IsAvailable()
        AbortOpen("native_unavailable")
        Return
    EndIf

    RequestSerial += 1
    ActiveRequest = "boat-honrich-" + RequestSerial
    RegisterForModEvent("DNT_ParchmentResult", "OnParchmentResult")
    If !DNT_ParchmentNative.BeginRequest(ActiveRequest, "boat", SourceRef, TexturePath, ArtAspectRatio, TextureUvMinX, TextureUvMinY, TextureUvMaxX, TextureUvMaxY)
        AbortOpen("begin_failed")
        Return
    EndIf
    Bool FerryStyleReady = DNT_ParchmentNative.SetMarkerTextures(ActiveRequest, "Data/textures/DiegeticTravel/docks-marker.dds", "Data/textures/DiegeticTravel/docks-marker.dds")
    FerryStyleReady = DNT_ParchmentNative.SetOriginMarkerTexture(ActiveRequest, "Data/textures/DiegeticTravel/shipwreck-marker.dds") && FerryStyleReady
    FerryStyleReady = DNT_ParchmentNative.SetSelectionRingTexture(ActiveRequest, "Data/textures/DiegeticTravel/parchment-thin-selection-ring.dds") && FerryStyleReady
    FerryStyleReady = DNT_ParchmentNative.SetSelectionRingScale(ActiveRequest, 1.88) && FerryStyleReady
    Bool AddedAll = AddLaneDestinations() && FerryStyleReady
    If !AddedAll
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("destination_setup_failed")
        Return
    EndIf
    If !DNT_ParchmentNative.Show(ActiveRequest)
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("show_failed")
        Return
    EndIf
    Debug.Trace("[DNT] BOAT_PARCHMENT_OPEN lane=lake_honrich source=" + ActiveSourceId + " request=" + ActiveRequest)
EndFunction

Bool Function AddLaneDestinations()
    Bool AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, GetSourceLabel(ActiveSourceId))
    AddedAll = DNT_ParchmentNative.SetPaymentLabelPosition(ActiveRequest, 0.647846, 0.899624) && AddedAll
    If !AddedAll
        Return False
    EndIf
    AddedAll = AddInactiveMainlandLandmarks() && AddedAll
    ClearSelections()
    AddedAll = SetRouteOrigin(ActiveSourceId) && AddedAll
    AddedAll = AddStop("riften", "Riften", 0.905132, 0.835295) && AddedAll
    AddedAll = AddStop("heartwood_mill", "Heartwood Mill", 0.812988, 0.805703) && AddedAll
    AddedAll = AddStop("ivarstead", "Ivarstead", 0.688477, 0.724801) && AddedAll
    AddedAll = AddStop("honeyside", "Honeyside", 0.893650, 0.805080) && AddedAll
    Return AddedAll && SelectionCount > 0
EndFunction

Bool Function SetRouteOrigin(String SourceId)
    If SourceId == "riften"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.905132, 0.835295)
    ElseIf SourceId == "heartwood_mill"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.812988, 0.805703)
    ElseIf SourceId == "ivarstead"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.688477, 0.724801)
    ElseIf SourceId == "honeyside"
        Return DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.893650, 0.805080)
    EndIf
    Return False
EndFunction

Bool Function AddStop(String DestinationId, String DestinationName, Float MapX, Float MapY)
    If DestinationId == ActiveSourceId || !Service.CanOfferDestination(DestinationId)
        Return True
    EndIf
    Int Fare = Service.GetFare(DestinationId)
    If Fare < 0 || !RecordSelection(DestinationId)
        Return False
    EndIf
    Return DNT_ParchmentNative.AddDestination(ActiveRequest, DestinationId, DestinationName + " ", Fare, MapX, MapY)
EndFunction

Bool Function AddInactiveMainlandLandmarks()
    ; Northern-coast route.
    Bool AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.562012, 0.130000)
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.334961, 0.168435) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.820312, 0.403183) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.404297, 0.263263) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.383789, 0.085544) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.730469, 0.133952) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.248535, 0.218833) && AddedAll
    ; Lake Ilinalta route.
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.448478, 0.683198) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.396241, 0.692916) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.501218, 0.685304) && AddedAll
    Return AddedAll
EndFunction

String Function GetSourceLabel(String SourceId)
    If SourceId == "riften"
        Return "Riften"
    ElseIf SourceId == "heartwood_mill"
        Return "Heartwood Mill"
    ElseIf SourceId == "ivarstead"
        Return "Ivarstead"
    ElseIf SourceId == "honeyside"
        Return "Honeyside"
    EndIf
    Return ""
EndFunction

Function AbortOpen(String Reason)
    Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=lake_honrich source=" + ActiveSourceId + " request=" + ActiveRequest + " reason=" + Reason, 1)
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
    String DestinationId = GetDestinationId(SelectionIndex)
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    ActiveSourceId = ""
    CurrentSource = None
    ClearSelections()

    If SelectionIndex < 0
        Debug.Trace("[DNT] BOAT_PARCHMENT_CANCEL lane=lake_honrich source=" + SourceId + " request=" + FinishedRequest)
        Return
    EndIf

    If DestinationId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_REJECT lane=lake_honrich source=" + SourceId + " request=" + FinishedRequest + " reason=unknown_index index=" + SelectionIndex, 1)
        Return
    EndIf

    Debug.Trace("[DNT] BOAT_PARCHMENT_SELECT lane=lake_honrich source=" + SourceId + " request=" + FinishedRequest + " destination=" + DestinationId)
    Service.RequestTravel(DestinationId, SourceRef)
EndEvent

Function ClearSelections()
    SelectionCount = 0
    SelectionIds = new String[4]
EndFunction

Bool Function RecordSelection(String DestinationId)
    If SelectionCount < 0 || SelectionCount >= 4
        Return False
    EndIf
    SelectionIds[SelectionCount] = DestinationId
    SelectionCount += 1
    Return True
EndFunction

String Function GetDestinationId(Int SelectionIndex)
    If SelectionIndex >= 0 && SelectionIndex < SelectionCount
        Return SelectionIds[SelectionIndex]
    EndIf
    Return ""
EndFunction
