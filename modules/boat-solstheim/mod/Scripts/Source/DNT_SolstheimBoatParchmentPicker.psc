Scriptname DNT_SolstheimBoatParchmentPicker extends Quest

DNT_SolstheimBoatTravelService Property Service Auto

ObjectReference CurrentSource
String ActiveSourceId = ""
String ActiveRequest = ""
Int RequestSerial = 0

Function OpenMap(ObjectReference SourceRef)
    If ActiveRequest != ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=solstheim source=" + SourceRef + " reason=already_open", 1)
        Return
    EndIf

    ActiveSourceId = Service.GetSourceId(SourceRef)
    If ActiveSourceId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=solstheim source=" + SourceRef + " reason=invalid_provider", 1)
        Return
    EndIf

    ActiveRequest = "opening"
    CurrentSource = SourceRef
    Utility.Wait(0.1)

    Bool DialogueWasOpen = UI.IsMenuOpen("Dialogue Menu")
    If DialogueWasOpen
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_CLOSE_REQUEST lane=solstheim source=" + ActiveSourceId)
        If !DNT_ParchmentNative.RequestDialogueClose()
            AbortOpen("dialogue_close_request_failed")
            Return
        EndIf
    Else
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_ALREADY_CLOSED lane=solstheim source=" + ActiveSourceId)
    EndIf

    Int DialogueWaitTicks = 0
    While UI.IsMenuOpen("Dialogue Menu") && DialogueWaitTicks < 50
        Utility.Wait(0.1)
        DialogueWaitTicks += 1
    EndWhile
    If UI.IsMenuOpen("Dialogue Menu")
        Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_TIMEOUT lane=solstheim source=" + ActiveSourceId + " waitTicks=" + DialogueWaitTicks, 1)
        AbortOpen("dialogue_timeout")
        Return
    EndIf
    Debug.Trace("[DNT] BOAT_DIALOGUE_HANDOFF_COMPLETE lane=solstheim source=" + ActiveSourceId + " closeRequested=" + DialogueWasOpen + " waitTicks=" + DialogueWaitTicks)
    Utility.Wait(0.15)

    If !DNT_ParchmentNative.IsAvailable()
        AbortOpen("native_unavailable")
        Return
    EndIf

    RequestSerial += 1
    ActiveRequest = "boat-solstheim-" + RequestSerial
    RegisterForModEvent("DNT_ParchmentResult", "OnParchmentResult")
    ; Keep presentation constants inside executable code. Auto-property values
    ; persist in existing saves and otherwise make visual revisions look stale.
    String MapTexturePath = "Data/textures/dlc02/clutter/dlc2mapsolstheim02.dds"
    Float MapAspectRatio = 1.0
    If !DNT_ParchmentNative.BeginRequest(ActiveRequest, "boat", SourceRef, MapTexturePath, MapAspectRatio, 0.5, 0.0, 1.0, 1.0)
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
    Debug.Trace("[DNT] BOAT_PARCHMENT_OPEN lane=solstheim source=" + ActiveSourceId + " request=" + ActiveRequest)
EndFunction

Bool Function AddLaneDestinations()
    Int Fare = Service.GetFare("raven_rock")
    Bool AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, GetSourceLabel(ActiveSourceId))
    If Fare < 0 || !AddedAll
        Return False
    EndIf

    If ActiveSourceId == "raven_rock"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.239171, 0.676223)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "tel_mithryn", "Tel Mithryn ", Fare, 0.705729, 0.771395) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "skaal_village", "Skaal Village ", Fare, 0.813066, 0.347056) && AddedAll
        Return AddedAll
    ElseIf ActiveSourceId == "tel_mithryn"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.705729, 0.771395)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "raven_rock", "Raven Rock ", Fare, 0.239171, 0.676223) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "skaal_village", "Skaal Village ", Fare, 0.813066, 0.347056) && AddedAll
        Return AddedAll
    ElseIf ActiveSourceId == "skaal_village"
        AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.813066, 0.347056)
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "raven_rock", "Raven Rock ", Fare, 0.239171, 0.676223) && AddedAll
        AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "tel_mithryn", "Tel Mithryn ", Fare, 0.705729, 0.771395) && AddedAll
        Return AddedAll
    EndIf
    Return False
EndFunction

String Function GetSourceLabel(String SourceId)
    If SourceId == "raven_rock"
        Return "Raven Rock"
    ElseIf SourceId == "tel_mithryn"
        Return "Tel Mithryn"
    ElseIf SourceId == "skaal_village"
        Return "Skaal Village"
    EndIf
    Return ""
EndFunction

Function AbortOpen(String Reason)
    Debug.Trace("[DNT] BOAT_PARCHMENT_DENIED lane=solstheim source=" + ActiveSourceId + " request=" + ActiveRequest + " reason=" + Reason, 1)
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
        Debug.Trace("[DNT] BOAT_PARCHMENT_CANCEL lane=solstheim source=" + SourceId + " request=" + FinishedRequest)
        Return
    EndIf

    String DestinationId = GetDestinationId(SourceId, SelectionIndex)
    If DestinationId == ""
        Debug.Trace("[DNT] BOAT_PARCHMENT_REJECT lane=solstheim source=" + SourceId + " request=" + FinishedRequest + " reason=unknown_index index=" + SelectionIndex, 1)
        Return
    EndIf

    Debug.Trace("[DNT] BOAT_PARCHMENT_SELECT lane=solstheim source=" + SourceId + " request=" + FinishedRequest + " destination=" + DestinationId)
    Service.RequestTravel(DestinationId, SourceRef)
EndEvent

String Function GetDestinationId(String SourceId, Int SelectionIndex)
    If SourceId == "raven_rock"
        If SelectionIndex == 0
            Return "tel_mithryn"
        ElseIf SelectionIndex == 1
            Return "skaal_village"
        EndIf
    ElseIf SourceId == "tel_mithryn"
        If SelectionIndex == 0
            Return "raven_rock"
        ElseIf SelectionIndex == 1
            Return "skaal_village"
        EndIf
    ElseIf SourceId == "skaal_village"
        If SelectionIndex == 0
            Return "raven_rock"
        ElseIf SelectionIndex == 1
            Return "tel_mithryn"
        EndIf
    EndIf
    Return ""
EndFunction
