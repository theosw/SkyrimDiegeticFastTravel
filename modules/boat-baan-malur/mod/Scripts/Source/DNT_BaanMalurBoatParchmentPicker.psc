Scriptname DNT_BaanMalurBoatParchmentPicker extends Quest

DNT_BaanMalurBoatTravelService Property Service Auto

ObjectReference CurrentSource
String ActiveSourceId = ""
String ActiveRequest = ""
Int RequestSerial = 0

Function OpenMap(ObjectReference SourceRef)
    If ActiveRequest != ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=baan_malur source=" + SourceRef + " reason=already_open", 1)
        Return
    EndIf

    ActiveSourceId = Service.GetSourceId(SourceRef)
    If ActiveSourceId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=baan_malur source=" + SourceRef + " reason=invalid_provider", 1)
        Return
    EndIf

    ActiveRequest = "opening"
    CurrentSource = SourceRef
    Utility.Wait(0.1)

    Bool DialogueWasOpen = UI.IsMenuOpen("Dialogue Menu")
    If DialogueWasOpen
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_CLOSE_REQUEST lane=baan_malur source=" + ActiveSourceId)
        If !DNT_ParchmentNative.RequestDialogueClose()
            AbortOpen("dialogue_close_request_failed")
            Return
        EndIf
    Else
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_ALREADY_CLOSED lane=baan_malur source=" + ActiveSourceId)
    EndIf

    Int DialogueWaitTicks = 0
    While UI.IsMenuOpen("Dialogue Menu") && DialogueWaitTicks < 50
        Utility.Wait(0.1)
        DialogueWaitTicks += 1
    EndWhile
    If UI.IsMenuOpen("Dialogue Menu")
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_TIMEOUT lane=baan_malur source=" + ActiveSourceId + " waitTicks=" + DialogueWaitTicks, 1)
        AbortOpen("dialogue_timeout")
        Return
    EndIf
    Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_COMPLETE lane=baan_malur source=" + ActiveSourceId + " closeRequested=" + DialogueWasOpen + " waitTicks=" + DialogueWaitTicks)
    Utility.Wait(0.15)

    If !DNT_ParchmentNative.IsAvailable()
        AbortOpen("native_unavailable")
        Return
    EndIf

    RequestSerial += 1
    ActiveRequest = "boat-baan-malur-" + RequestSerial
    RegisterForModEvent("DNT_ParchmentResult", "OnParchmentResult")
    String MapTexturePath = "Data/textures/terrain/dlc2solstheimworld/solstheim.dds"
    Float MapAspectRatio = 1.534
    If !DNT_ParchmentNative.BeginRequest(ActiveRequest, "boat", SourceRef, MapTexturePath, MapAspectRatio, 0.0, 0.158447, 1.0, 0.810181)
        AbortOpen("begin_failed")
        Return
    EndIf

    If !AddLaneDestinations()
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("destination_setup_failed")
        Return
    EndIf
    If !DNT_ParchmentNative.Show(ActiveRequest)
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("show_failed")
        Return
    EndIf
    Debug.Trace("[DNT] BOAT_PARCHMENT_OPEN lane=baan_malur source=" + ActiveSourceId + " request=" + ActiveRequest)
EndFunction

Bool Function AddLaneDestinations()
    Int Fare = Service.GetFare("raven_rock")
    Bool AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, GetSourceLabel(ActiveSourceId))
    AddedAll = DNT_ParchmentNative.SetPaymentLabelPosition(ActiveRequest, 0.814330, 0.697376) && AddedAll
    If Fare < 0 || !AddedAll
        Return False
    EndIf

    If ActiveSourceId == "raven_rock"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.572274, 0.405605)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "baan_malur", "Baan Malur ", Fare, 0.510018, 0.640516) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "cormaris", "Cormaris ", Fare, 0.157237, 0.323277) && AddedAll
        Return AddedAll
    ElseIf ActiveSourceId == "baan_malur"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.510018, 0.640516)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "raven_rock", "Raven Rock ", Fare, 0.572274, 0.405605) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "cormaris", "Cormaris ", Fare, 0.157237, 0.323277) && AddedAll
        Return AddedAll
    ElseIf ActiveSourceId == "cormaris"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.157237, 0.323277)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "raven_rock", "Raven Rock ", Fare, 0.572274, 0.405605) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "baan_malur", "Baan Malur ", Fare, 0.510018, 0.640516) && AddedAll
        Return AddedAll
    EndIf
    Return False
EndFunction

String Function GetSourceLabel(String SourceId)
    If SourceId == "raven_rock"
        Return "Raven Rock"
    ElseIf SourceId == "baan_malur"
        Return "Baan Malur"
    ElseIf SourceId == "cormaris"
        Return "Cormaris"
    EndIf
    Return ""
EndFunction

Function AbortOpen(String Reason)
    Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=baan_malur source=" + ActiveSourceId + " request=" + ActiveRequest + " reason=" + Reason, 1)
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    ActiveSourceId = ""
    CurrentSource = None
    Debug.Notification("The merchant's chart could not be opened. Ask for the usual destinations instead.")
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
        Debug.Trace("[DNT] BOAT_PARCHMENT_CANCEL lane=baan_malur source=" + SourceId + " request=" + FinishedRequest)
        Return
    EndIf

    String DestinationId = GetDestinationId(SourceId, SelectionIndex)
    If DestinationId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_REJECT lane=baan_malur source=" + SourceId + " request=" + FinishedRequest + " reason=unknown_index index=" + SelectionIndex, 1)
        Return
    EndIf

    Debug.Trace("[DNT] BOAT_PARCHMENT_SELECT lane=baan_malur source=" + SourceId + " request=" + FinishedRequest + " destination=" + DestinationId)
    Service.RequestTravel(DestinationId, SourceRef)
EndEvent

String Function GetDestinationId(String SourceId, Int SelectionIndex)
    If SourceId == "raven_rock"
        If SelectionIndex == 0
            Return "baan_malur"
        ElseIf SelectionIndex == 1
            Return "cormaris"
        EndIf
    ElseIf SourceId == "baan_malur"
        If SelectionIndex == 0
            Return "raven_rock"
        ElseIf SelectionIndex == 1
            Return "cormaris"
        EndIf
    ElseIf SourceId == "cormaris"
        If SelectionIndex == 0
            Return "raven_rock"
        ElseIf SelectionIndex == 1
            Return "baan_malur"
        EndIf
    EndIf
    Return ""
EndFunction
