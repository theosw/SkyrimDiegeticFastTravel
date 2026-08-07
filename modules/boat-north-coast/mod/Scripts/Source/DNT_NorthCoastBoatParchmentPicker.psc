Scriptname DNT_NorthCoastBoatParchmentPicker extends Quest

DNT_NorthCoastBoatTravelService Property Service Auto

ObjectReference CurrentSource
String ActiveSourceId = ""
String ActiveRequest = ""
Int RequestSerial = 0
Int SelectionCount = 0
String Selection0 = ""
String Selection1 = ""
String Selection2 = ""
String Selection3 = ""
String Selection4 = ""
String Selection5 = ""

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
    ClearSelections()
    Bool AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, GetSourceLabel(ActiveSourceId))
    AddedAll = DNT_ParchmentNative.SetPaymentLabelPosition(ActiveRequest, 0.569053, 0.905747) && AddedAll
    AddedAll = SetRouteOrigin(ActiveSourceId) && AddedAll
    AddedAll = AddStop("dawnstar", "Dawnstar", 0.562613, 0.139944) && AddedAll
    AddedAll = AddStop("solitude", "Solitude", 0.343646, 0.176873) && AddedAll
    AddedAll = AddStop("windhelm", "Windhelm", 0.825231, 0.399423) && AddedAll
    AddedAll = AddStop("morthal", "Morthal", 0.404470, 0.256564) && AddedAll
    AddedAll = AddStop("solitude_lighthouse", "Solitude Lighthouse", 0.380140, 0.082606) && AddedAll
    AddedAll = AddStop("winterhold", "Winterhold", 0.730059, 0.137028) && AddedAll
    AddedAll = AddStop("dragon_bridge", "Dragon Bridge", 0.243465, 0.226437) && AddedAll
    AddedAll = AddInactiveMainlandLandmarks() && AddedAll
    If !AddedAll || SelectionCount != 6
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
    Bool AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.897461, 0.824934)
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.812988, 0.805703) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.688477, 0.724801) && AddedAll
    ; Lake Ilinalta route.
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.448478, 0.683198) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.396241, 0.692916) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteLandmark(ActiveRequest, 0.501218, 0.685304) && AddedAll
    Return AddedAll
EndFunction

Bool Function AddNorthCoastNetwork()
    Bool AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.248535, 0.218833, 0.248535, 0.218170)
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.248535, 0.218170, 0.251953, 0.222812) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.251953, 0.222812, 0.261230, 0.224801) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.261230, 0.224801, 0.281250, 0.216180) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.281250, 0.216180, 0.310059, 0.211538) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.310059, 0.211538, 0.318359, 0.206897) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.318359, 0.206897, 0.337891, 0.187003) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.337891, 0.187003, 0.339844, 0.179708) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.339844, 0.179708, 0.334961, 0.168435) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.339844, 0.179708, 0.347168, 0.177719) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.347168, 0.177719, 0.367676, 0.155836) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.367676, 0.155836, 0.385742, 0.135942) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.385742, 0.135942, 0.396973, 0.131300) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.396973, 0.131300, 0.405273, 0.110080) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.405273, 0.110080, 0.402344, 0.093501) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.402344, 0.093501, 0.398438, 0.086870) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.398438, 0.086870, 0.383789, 0.085544) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.402344, 0.093501, 0.405762, 0.108753) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.405762, 0.108753, 0.418457, 0.104111) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.418457, 0.104111, 0.435059, 0.092838) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.435059, 0.092838, 0.470703, 0.079576) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.470703, 0.079576, 0.499512, 0.075597) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.499512, 0.075597, 0.567383, 0.067639) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.567383, 0.067639, 0.649902, 0.053714) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.649902, 0.053714, 0.661133, 0.053050) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.661133, 0.053050, 0.666504, 0.062334) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.666504, 0.062334, 0.687988, 0.076923) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.687988, 0.076923, 0.706055, 0.113395) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.706055, 0.113395, 0.715332, 0.125332) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.715332, 0.125332, 0.730469, 0.133952) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.418457, 0.104111, 0.406250, 0.108090) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.406250, 0.108090, 0.396973, 0.131300) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.396973, 0.131300, 0.399414, 0.134615) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.399414, 0.134615, 0.402344, 0.163130) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.402344, 0.163130, 0.413086, 0.184350) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.413086, 0.184350, 0.415039, 0.199602) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.415039, 0.199602, 0.414551, 0.213528) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.414551, 0.213528, 0.404785, 0.235411) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.404785, 0.235411, 0.402832, 0.250000) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.402832, 0.250000, 0.404297, 0.263263) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.567383, 0.067639, 0.557129, 0.070955) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.557129, 0.070955, 0.549805, 0.104111) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.549805, 0.104111, 0.550781, 0.122679) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.550781, 0.122679, 0.556641, 0.133952) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.556641, 0.133952, 0.562012, 0.130000) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.730469, 0.133952, 0.711426, 0.122016) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.711426, 0.122016, 0.687988, 0.076923) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.687988, 0.076923, 0.666016, 0.061671) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.666016, 0.061671, 0.661133, 0.053050) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.661133, 0.053050, 0.665527, 0.045093) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.665527, 0.045093, 0.729004, 0.029178) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.729004, 0.029178, 0.754395, 0.029841) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.754395, 0.029841, 0.805176, 0.051061) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.805176, 0.051061, 0.819824, 0.065650) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.819824, 0.065650, 0.829102, 0.091512) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.829102, 0.091512, 0.845703, 0.130637) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.845703, 0.130637, 0.880371, 0.181698) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.880371, 0.181698, 0.886719, 0.201592) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.886719, 0.201592, 0.893555, 0.228117) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.893555, 0.228117, 0.895996, 0.257294) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.895996, 0.257294, 0.892090, 0.297082) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.892090, 0.297082, 0.884766, 0.313660) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.884766, 0.313660, 0.879883, 0.318966) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.879883, 0.318966, 0.867188, 0.332891) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.867188, 0.332891, 0.859375, 0.346817) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.859375, 0.346817, 0.840332, 0.391247) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.840332, 0.391247, 0.831055, 0.399204) && AddedAll
    AddedAll = DNT_ParchmentNative.AddRouteSegment(ActiveRequest, 0.831055, 0.399204, 0.820312, 0.403183) && AddedAll
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
    EndIf
    Return False
EndFunction

Bool Function AddStop(String DestinationId, String DestinationName, Float MapX, Float MapY)
    If DestinationId == ActiveSourceId
        Return True
    EndIf
    Int Fare = Service.GetFare(DestinationId)
    If Fare < 0 || !RecordSelection(DestinationId)
        Return False
    EndIf
    Return DNT_ParchmentNative.AddDestination(ActiveRequest, DestinationId, DestinationName + " ", Fare, MapX, MapY)
EndFunction

Function ClearSelections()
    SelectionCount = 0
    Selection0 = ""
    Selection1 = ""
    Selection2 = ""
    Selection3 = ""
    Selection4 = ""
    Selection5 = ""
EndFunction

Bool Function RecordSelection(String DestinationId)
    If SelectionCount == 0
        Selection0 = DestinationId
    ElseIf SelectionCount == 1
        Selection1 = DestinationId
    ElseIf SelectionCount == 2
        Selection2 = DestinationId
    ElseIf SelectionCount == 3
        Selection3 = DestinationId
    ElseIf SelectionCount == 4
        Selection4 = DestinationId
    ElseIf SelectionCount == 5
        Selection5 = DestinationId
    Else
        Return False
    EndIf
    SelectionCount += 1
    Return True
EndFunction

String Function SelectionAt(Int SelectionIndex)
    If SelectionIndex == 0
        Return Selection0
    ElseIf SelectionIndex == 1
        Return Selection1
    ElseIf SelectionIndex == 2
        Return Selection2
    ElseIf SelectionIndex == 3
        Return Selection3
    ElseIf SelectionIndex == 4
        Return Selection4
    ElseIf SelectionIndex == 5
        Return Selection5
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
