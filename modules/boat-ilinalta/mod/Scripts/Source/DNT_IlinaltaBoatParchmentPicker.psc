Scriptname DNT_IlinaltaBoatParchmentPicker extends Quest

DNT_IlinaltaBoatTravelService Property Service Auto

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
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=lake_ilinalta source=" + SourceRef + " reason=already_open", 1)
        Return
    EndIf

    ActiveSourceId = Service.GetSourceId(SourceRef)
    If ActiveSourceId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=lake_ilinalta source=" + SourceRef + " reason=invalid_provider", 1)
        Return
    EndIf

    ActiveRequest = "opening"
    CurrentSource = SourceRef
    Utility.Wait(0.1)

    Bool DialogueWasOpen = UI.IsMenuOpen("Dialogue Menu")
    If DialogueWasOpen
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_CLOSE_REQUEST lane=lake_ilinalta source=" + ActiveSourceId)
        If !DNT_ParchmentNative.RequestDialogueClose()
            AbortOpen("dialogue_close_request_failed")
            Return
        EndIf
    Else
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_ALREADY_CLOSED lane=lake_ilinalta source=" + ActiveSourceId)
    EndIf

    Int DialogueWaitTicks = 0
    While UI.IsMenuOpen("Dialogue Menu") && DialogueWaitTicks < 50
        Utility.Wait(0.1)
        DialogueWaitTicks += 1
    EndWhile
    If UI.IsMenuOpen("Dialogue Menu")
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_TIMEOUT lane=lake_ilinalta source=" + ActiveSourceId + " waitTicks=" + DialogueWaitTicks, 1)
        AbortOpen("dialogue_timeout")
        Return
    EndIf
    Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_COMPLETE lane=lake_ilinalta source=" + ActiveSourceId + " closeRequested=" + DialogueWasOpen + " waitTicks=" + DialogueWaitTicks)
    Utility.Wait(0.15)

    If !DNT_ParchmentNative.IsAvailable()
        AbortOpen("native_unavailable")
        Return
    EndIf

    RequestSerial += 1
    ActiveRequest = "boat-ilinalta-" + RequestSerial
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
    Debug.Trace("[DNT] BOAT_PARCHMENT_OPEN lane=lake_ilinalta source=" + ActiveSourceId + " request=" + ActiveRequest)
EndFunction

Bool Function AddLaneDestinations()
    Int Fare = Service.GetFare("brittleshin_pass")
    Bool AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, GetSourceLabel(ActiveSourceId))
    AddedAll = DNT_ParchmentNative.SetPaymentLabelPosition(ActiveRequest, 0.655229, 0.913675) && AddedAll
    If Fare < 0 || !AddedAll
        Return False
    EndIf
    AddedAll = AddInactiveMainlandLandmarks() && AddedAll

    If ActiveSourceId == "brittleshin_pass"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.448478, 0.683198)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "half_moon_mill", "Half-Moon Mill ", Fare, 0.396241, 0.692916) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "guardian_stones", "Guardian Stones ", Fare, 0.501218, 0.685304) && AddedAll
        Return AddedAll
    ElseIf ActiveSourceId == "half_moon_mill"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.396241, 0.692916)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "brittleshin_pass", "Brittleshin Pass ", Fare, 0.448478, 0.683198) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "guardian_stones", "Guardian Stones ", Fare, 0.501218, 0.685304) && AddedAll
        Return AddedAll
    ElseIf ActiveSourceId == "guardian_stones"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.501218, 0.685304)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "brittleshin_pass", "Brittleshin Pass ", Fare, 0.448478, 0.683198) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "half_moon_mill", "Half-Moon Mill ", Fare, 0.396241, 0.692916) && AddedAll
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
    ; Lake Honrich route.
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.897461, 0.824934) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.812988, 0.805703) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.688477, 0.724801) && AddedAll
    Return AddedAll
EndFunction

String Function GetSourceLabel(String SourceId)
    If SourceId == "brittleshin_pass"
        Return "Brittleshin Pass"
    ElseIf SourceId == "half_moon_mill"
        Return "Half-Moon Mill"
    ElseIf SourceId == "guardian_stones"
        Return "Guardian Stones"
    EndIf
    Return ""
EndFunction

Function AbortOpen(String Reason)
    Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=lake_ilinalta source=" + ActiveSourceId + " request=" + ActiveRequest + " reason=" + Reason, 1)
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
        Debug.Trace("[DNT] BOAT_PARCHMENT_CANCEL lane=lake_ilinalta source=" + SourceId + " request=" + FinishedRequest)
        Return
    EndIf

    String DestinationId = GetDestinationId(SourceId, SelectionIndex)
    If DestinationId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_REJECT lane=lake_ilinalta source=" + SourceId + " request=" + FinishedRequest + " reason=unknown_index index=" + SelectionIndex, 1)
        Return
    EndIf

    Debug.Trace("[DNT] BOAT_PARCHMENT_SELECT lane=lake_ilinalta source=" + SourceId + " request=" + FinishedRequest + " destination=" + DestinationId)
    Service.RequestTravel(DestinationId, SourceRef)
EndEvent

String Function GetDestinationId(String SourceId, Int SelectionIndex)
    If SourceId == "brittleshin_pass"
        If SelectionIndex == 0
            Return "half_moon_mill"
        ElseIf SelectionIndex == 1
            Return "guardian_stones"
        EndIf
    ElseIf SourceId == "half_moon_mill"
        If SelectionIndex == 0
            Return "brittleshin_pass"
        ElseIf SelectionIndex == 1
            Return "guardian_stones"
        EndIf
    ElseIf SourceId == "guardian_stones"
        If SelectionIndex == 0
            Return "brittleshin_pass"
        ElseIf SelectionIndex == 1
            Return "half_moon_mill"
        EndIf
    EndIf
    Return ""
EndFunction
