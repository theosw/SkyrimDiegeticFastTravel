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
    Bool AddedAll = AddLaneDestinations()
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
    Int Fare = Service.GetFare("riften")
    Bool AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, GetSourceLabel(ActiveSourceId))
    If Fare < 0 || !AddedAll
        Return False
    EndIf
    AddedAll = AddInactiveMainlandLandmarks() && AddedAll

    If ActiveSourceId == "riften"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.897461, 0.824934)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "heartwood_mill", "Heartwood Mill ", Fare, 0.812988, 0.805703) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "ivarstead", "Ivarstead ", Fare, 0.688477, 0.724801) && AddedAll
        Return AddedAll
    ElseIf ActiveSourceId == "heartwood_mill"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.812988, 0.805703)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "riften", "Riften ", Fare, 0.897461, 0.824934) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "ivarstead", "Ivarstead ", Fare, 0.688477, 0.724801) && AddedAll
        Return AddedAll
    ElseIf ActiveSourceId == "ivarstead"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.688477, 0.724801)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "riften", "Riften ", Fare, 0.897461, 0.824934) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "heartwood_mill", "Heartwood Mill ", Fare, 0.812988, 0.805703) && AddedAll
        Return AddedAll
    EndIf
    Return False
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
    EndIf
    Return ""
EndFunction

Bool Function AddLaneNetwork()
    Bool AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.688477, 0.724801, 0.715820, 0.734085)
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.715820, 0.734085, 0.723145, 0.740716) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.723145, 0.740716, 0.737305, 0.748674) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.737305, 0.748674, 0.744141, 0.755968) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.744141, 0.755968, 0.750977, 0.783820) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.750977, 0.783820, 0.761719, 0.793767) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.761719, 0.793767, 0.771973, 0.793767) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.771973, 0.793767, 0.787109, 0.781830) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.787109, 0.781830, 0.796875, 0.783156) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.796875, 0.783156, 0.805664, 0.789788) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.805664, 0.789788, 0.812988, 0.805703) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.812988, 0.805703, 0.816895, 0.810345) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.816895, 0.810345, 0.822266, 0.828249) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.822266, 0.828249, 0.825195, 0.832228) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.825195, 0.832228, 0.833496, 0.834881) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.833496, 0.834881, 0.870605, 0.844164) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.870605, 0.844164, 0.882324, 0.844164) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.882324, 0.844164, 0.889648, 0.838859) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.889648, 0.838859, 0.895996, 0.832891) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.895996, 0.832891, 0.897461, 0.824934) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.895996, 0.832891, 0.886719, 0.842175) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.886719, 0.842175, 0.865723, 0.842838) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.865723, 0.842838, 0.834473, 0.836207) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.834473, 0.836207, 0.822754, 0.829576) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.822754, 0.829576, 0.816895, 0.810345) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.816895, 0.810345, 0.801758, 0.785809) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.801758, 0.785809, 0.787109, 0.781830) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.787109, 0.781830, 0.768555, 0.795093) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.768555, 0.795093, 0.754883, 0.789788) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.754883, 0.789788, 0.749512, 0.779841) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.749512, 0.779841, 0.745117, 0.757958) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.745117, 0.757958, 0.741211, 0.751989) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.741211, 0.751989, 0.715820, 0.734085) && AddedAll
    Return AddedAll
EndFunction

Function AbortOpen(String Reason)
    Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=lake_honrich source=" + ActiveSourceId + " request=" + ActiveRequest + " reason=" + Reason, 1)
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    ActiveSourceId = ""
    CurrentSource = None
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
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    ActiveSourceId = ""
    CurrentSource = None

    If SelectionIndex < 0
        Debug.Trace("[DNT] BOAT_PARCHMENT_CANCEL lane=lake_honrich source=" + SourceId + " request=" + FinishedRequest)
        Return
    EndIf

    String DestinationId = GetDestinationId(SourceId, SelectionIndex)
    If DestinationId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_REJECT lane=lake_honrich source=" + SourceId + " request=" + FinishedRequest + " reason=unknown_index index=" + SelectionIndex, 1)
        Return
    EndIf

    Debug.Trace("[DNT] BOAT_PARCHMENT_SELECT lane=lake_honrich source=" + SourceId + " request=" + FinishedRequest + " destination=" + DestinationId)
    Service.RequestTravel(DestinationId, SourceRef)
EndEvent

String Function GetDestinationId(String SourceId, Int SelectionIndex)
    If SourceId == "riften"
        If SelectionIndex == 0
            Return "heartwood_mill"
        ElseIf SelectionIndex == 1
            Return "ivarstead"
        EndIf
    ElseIf SourceId == "heartwood_mill"
        If SelectionIndex == 0
            Return "riften"
        ElseIf SelectionIndex == 1
            Return "ivarstead"
        EndIf
    ElseIf SourceId == "ivarstead"
        If SelectionIndex == 0
            Return "riften"
        ElseIf SelectionIndex == 1
            Return "heartwood_mill"
        EndIf
    EndIf
    Return ""
EndFunction
