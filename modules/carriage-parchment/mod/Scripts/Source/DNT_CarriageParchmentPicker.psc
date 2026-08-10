Scriptname DNT_CarriageParchmentPicker extends Quest

DNT_TravelCoordinator Property Coordinator Auto

String Property TexturePath = "Data/textures/terrain/tamriel/skyrim.dds" Auto
Float Property ArtAspectRatio = 1.414075 Auto
Float Property TextureUvMinX = 0.088379 Auto
Float Property TextureUvMinY = 0.187012 Auto
Float Property TextureUvMaxX = 0.932129 Auto
Float Property TextureUvMaxY = 0.783691 Auto

ObjectReference CurrentSource
String ActiveRequest = ""
Int RequestSerial = 0
Int SelectionCount = 0
String[] SelectionIds

Function OpenMap(ObjectReference SourceRef)
    If ActiveRequest != ""
        Debug.Trace("[DNT] CARRIAGE_PARCHMENT_DENIED source=" + SourceRef + " reason=already_open", 1)
        Return
    EndIf

    Actor Speaker = SourceRef as Actor
    DNT_OriginService Service = Coordinator.GetOriginService(Speaker)
    If Service == None
        Debug.Trace("[DNT] CARRIAGE_PARCHMENT_DENIED source=" + SourceRef + " reason=invalid_provider", 1)
        Return
    EndIf

    ActiveRequest = "opening"
    CurrentSource = SourceRef
    Utility.Wait(0.1)

    Bool DialogueWasOpen = UI.IsMenuOpen("Dialogue Menu")
    If DialogueWasOpen
        Debug.Trace("[DNT] CARRIAGE_DIALOGUE_HANDOFF_CLOSE_REQUEST origin=" + Service.OriginId)
        If !DNT_ParchmentNative.RequestDialogueClose()
            AbortOpen("dialogue_close_request_failed")
            Return
        EndIf
    Else
        Debug.Trace("[DNT] CARRIAGE_DIALOGUE_HANDOFF_ALREADY_CLOSED origin=" + Service.OriginId)
    EndIf

    Int DialogueWaitTicks = 0
    While UI.IsMenuOpen("Dialogue Menu") && DialogueWaitTicks < 50
        Utility.Wait(0.1)
        DialogueWaitTicks += 1
    EndWhile
    If UI.IsMenuOpen("Dialogue Menu")
        Debug.Trace("[DNT] CARRIAGE_DIALOGUE_HANDOFF_TIMEOUT origin=" + Service.OriginId + " waitTicks=" + DialogueWaitTicks, 1)
        AbortOpen("dialogue_timeout")
        Return
    EndIf
    Debug.Trace("[DNT] CARRIAGE_DIALOGUE_HANDOFF_COMPLETE origin=" + Service.OriginId + " closeRequested=" + DialogueWasOpen + " waitTicks=" + DialogueWaitTicks)
    Utility.Wait(0.15)

    If !Coordinator.EnsureQuotesForSpeaker(SourceRef)
        AbortOpen("quote_preparation_failed")
        Return
    EndIf

    If !DNT_ParchmentNative.IsAvailable()
        AbortOpen("native_unavailable")
        Return
    EndIf

    RequestSerial += 1
    ActiveRequest = "carriage-sheet-" + RequestSerial
    RegisterForModEvent("DNT_ParchmentResult", "OnParchmentResult")
    ; Keep the formal carriage chart independent of values serialized into an
    ; older save when this provider still used the rough battle-map parchment.
    If !DNT_ParchmentNative.BeginRequest(ActiveRequest, "carriage", SourceRef, "Data/textures/terrain/tamriel/skyrim.dds", 1.414075, 0.088379, 0.187012, 0.932129, 0.783691)
        AbortOpen("begin_failed")
        Return
    EndIf

    ClearSelections()
    Bool AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, GetSourceLabel(Service.OriginId))
    AddedAll = DNT_ParchmentNative.SetPaymentLabelPosition(ActiveRequest, 0.615551, 0.922189) && AddedAll
    AddedAll = DNT_ParchmentNative.SetMarkerTextures(ActiveRequest, "Data/textures/DiegeticTravel/norden-town.dds", "Data/textures/DiegeticTravel/norden-town.dds") && AddedAll
    AddedAll = DNT_ParchmentNative.SetSelectionRingTexture(ActiveRequest, "Data/textures/DiegeticTravel/thin-circle-selection-ring.dds") && AddedAll
    AddedAll = AddStop(Service, "windhelm", "Windhelm", 0.793249, 0.410699) && AddedAll
    AddedAll = AddStop(Service, "darkwater_crossing", "Darkwater Crossing", 0.759376, 0.633099) && AddedAll
    AddedAll = AddStop(Service, "kynesgrove", "Kynesgrove", 0.794486, 0.488185) && AddedAll
    AddedAll = AddStop(Service, "mixwater_mill", "Mixwater Mill", 0.735146, 0.545280) && AddedAll
    AddedAll = AddStop(Service, "falkreath", "Falkreath", 0.417011, 0.800385) && AddedAll
    AddedAll = AddStop(Service, "riverwood", "Riverwood", 0.536900, 0.667780) && AddedAll
    AddedAll = AddStop(Service, "halfmoon_mill", "Half-Moon Mill", 0.390284, 0.710628) && AddedAll
    AddedAll = AddStop(Service, "lakeview_manor", "Lakeview Manor", 0.464420, 0.746222) && AddedAll
    AddedAll = AddStop(Service, "markarth", "Markarth", 0.094238, 0.507741) && AddedAll
    AddedAll = AddStop(Service, "karthwasten", "Karthwasten", 0.192772, 0.401553) && AddedAll
    AddedAll = AddStop(Service, "soljunds_sinkhole", "Soljund's Sinkhole", 0.225058, 0.504729) && AddedAll
    AddedAll = AddStop(Service, "old_hroldan", "Old Hroldan", 0.231397, 0.546434) && AddedAll
    AddedAll = AddStop(Service, "solitude", "Solitude", 0.365471, 0.191247) && AddedAll
    AddedAll = AddStop(Service, "dragon_bridge", "Dragon Bridge", 0.264061, 0.259819) && AddedAll
    AddedAll = AddStop(Service, "whiterun", "Whiterun", 0.532756, 0.548290) && AddedAll
    AddedAll = AddStop(Service, "rorikstead", "Rorikstead", 0.300256, 0.502491) && AddedAll
    AddedAll = AddStop(Service, "winterhold", "Winterhold", 0.741325, 0.195923) && AddedAll
    AddedAll = AddStop(Service, "riften", "Riften", 0.880078, 0.833512) && AddedAll
    AddedAll = AddStop(Service, "ivarstead", "Ivarstead", 0.658517, 0.729967) && AddedAll
    AddedAll = AddStop(Service, "shors_stone", "Shor's Stone", 0.853720, 0.717995) && AddedAll
    AddedAll = AddStop(Service, "heartwood_mill", "Heartwood Mill", 0.784775, 0.830702) && AddedAll
    AddedAll = AddStop(Service, "dawnstar", "Dawnstar", 0.557529, 0.185081) && AddedAll
    AddedAll = AddStop(Service, "nightgate_inn", "Nightgate Inn", 0.658606, 0.377530) && AddedAll
    AddedAll = AddStop(Service, "heljarchen_hall", "Heljarchen Hall", 0.562709, 0.401255) && AddedAll
    AddedAll = AddStop(Service, "morthal", "Morthal", 0.400452, 0.311110) && AddedAll
    AddedAll = AddStop(Service, "stonehills", "Stonehills", 0.476818, 0.319312) && AddedAll
    AddedAll = AddStop(Service, "winstad_manor", "Windstad Manor", 0.441794, 0.206062) && AddedAll

    If !AddedAll || SelectionCount == 0
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("destination_setup_failed")
        Return
    EndIf
    If !DNT_ParchmentNative.Show(ActiveRequest)
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("show_failed")
        Return
    EndIf
    Debug.Trace("[DNT] CARRIAGE_PARCHMENT_OPEN origin=" + Service.OriginId + " destinations=" + SelectionCount + " request=" + ActiveRequest)
EndFunction

String Function GetSourceLabel(String OriginId)
    If OriginId == "dawnstar"
        Return "Dawnstar"
    ElseIf OriginId == "falkreath"
        Return "Falkreath"
    ElseIf OriginId == "markarth"
        Return "Markarth"
    ElseIf OriginId == "morthal"
        Return "Morthal"
    ElseIf OriginId == "riften"
        Return "Riften"
    ElseIf OriginId == "solitude"
        Return "Solitude"
    ElseIf OriginId == "whiterun"
        Return "Whiterun"
    ElseIf OriginId == "windhelm"
        Return "Windhelm"
    ElseIf OriginId == "winterhold"
        Return "Winterhold"
    EndIf
    Return ""
EndFunction

Bool Function AddStop(DNT_OriginService Service, String DestinationId, String DestinationName, Float MapX, Float MapY)
    If DestinationId == Service.OriginId
        Return True
    EndIf
    Int Fare = Service.GetPublishedFare(DestinationId)
    Float Hours = Service.GetPublishedHours(DestinationId)
    If Fare < 0 || Hours < 0.0
        Debug.Trace("[DNT] CARRIAGE_PARCHMENT_ROUTE_SKIPPED origin=" + Service.OriginId + " destination=" + DestinationId + " reason=unavailable")
        Return True
    EndIf

    If !RecordSelection(DestinationId)
        Return False
    EndIf
    Bool Added = DNT_ParchmentNative.AddStyledDestination(ActiveRequest, DestinationId, BuildLabel(DestinationName, Hours), Fare, MapX, MapY, GetDestinationMarkerTexture(DestinationId), GetDestinationMarkerScale(DestinationId), GetDestinationSelectionRingOffsetX(DestinationId), GetDestinationSelectionRingOffsetY(DestinationId), GetDestinationSelectionRingScale(DestinationId))
    If Added && IsOneWayDestination(DestinationId)
        Added = DNT_ParchmentNative.SetDestinationSelectionRingTexture(ActiveRequest, DestinationId, "Data/textures/DiegeticTravel/thin-circle-oneway-selection-ring.dds")
    EndIf
    Return Added
EndFunction

Bool Function IsOneWayDestination(String DestinationId)
    Return DestinationId == "darkwater_crossing" || DestinationId == "mixwater_mill" || DestinationId == "halfmoon_mill" || DestinationId == "karthwasten" || DestinationId == "soljunds_sinkhole" || DestinationId == "shors_stone" || DestinationId == "heartwood_mill" || DestinationId == "stonehills"
EndFunction

Float Function GetDestinationSelectionRingOffsetX(String DestinationId)
    If DestinationId == "whiterun" || DestinationId == "windhelm" || DestinationId == "falkreath"
        Return 0.0316
    ElseIf DestinationId == "winterhold"
        Return 0.0211
    ElseIf DestinationId == "mixwater_mill" || DestinationId == "halfmoon_mill" || DestinationId == "heartwood_mill" || DestinationId == "soljunds_sinkhole"
        Return -0.0105
    ElseIf DestinationId == "lakeview_manor" || DestinationId == "heljarchen_hall" || DestinationId == "winstad_manor"
        Return -0.0422
    ElseIf DestinationId == "darkwater_crossing" || DestinationId == "kynesgrove" || DestinationId == "karthwasten" || DestinationId == "shors_stone" || DestinationId == "stonehills"
        Return 0.0105
    ElseIf DestinationId != "riften" && DestinationId != "solitude" && DestinationId != "markarth" && DestinationId != "dawnstar" && DestinationId != "morthal"
        Return 0.0211
    EndIf
    Return 0.0
EndFunction

Float Function GetDestinationSelectionRingOffsetY(String DestinationId)
    If DestinationId == "whiterun" || DestinationId == "solitude" || DestinationId == "dawnstar"
        Return -0.0474
    ElseIf DestinationId == "riften" || DestinationId == "winterhold"
        Return -0.0580
    ElseIf DestinationId == "windhelm"
        Return -0.1001
    ElseIf DestinationId == "markarth" || DestinationId == "falkreath"
        Return -0.1107
    ElseIf DestinationId == "morthal"
        Return -0.0896
    ElseIf DestinationId == "mixwater_mill" || DestinationId == "halfmoon_mill" || DestinationId == "heartwood_mill" || DestinationId == "soljunds_sinkhole"
        Return 0.0791
    ElseIf DestinationId == "lakeview_manor" || DestinationId == "heljarchen_hall" || DestinationId == "winstad_manor"
        Return -0.0158
    ElseIf DestinationId == "darkwater_crossing" || DestinationId == "kynesgrove" || DestinationId == "karthwasten" || DestinationId == "shors_stone" || DestinationId == "stonehills"
        Return 0.1107
    EndIf
    Return 0.1529
EndFunction

Float Function GetDestinationSelectionRingScale(String DestinationId)
    If DestinationId == "whiterun" || DestinationId == "riften"
        Return 0.88
    ElseIf DestinationId == "solitude"
        Return 0.85
    ElseIf DestinationId == "windhelm" || DestinationId == "markarth" || DestinationId == "falkreath" || DestinationId == "winterhold"
        Return 0.89
    ElseIf DestinationId == "dawnstar"
        Return 0.86
    ElseIf DestinationId == "morthal"
        Return 0.92
    ElseIf DestinationId == "mixwater_mill" || DestinationId == "halfmoon_mill" || DestinationId == "heartwood_mill"
        Return 1.09
    ElseIf DestinationId == "soljunds_sinkhole"
        Return 1.02
    ElseIf DestinationId == "lakeview_manor" || DestinationId == "heljarchen_hall" || DestinationId == "winstad_manor"
        Return 1.04
    EndIf
    Return 1.0
EndFunction

Float Function GetDestinationMarkerScale(String DestinationId)
    If DestinationId == "whiterun" || DestinationId == "solitude"
        Return 1.0
    ElseIf DestinationId == "riften"
        Return 0.99
    ElseIf DestinationId == "windhelm"
        Return 0.93
    ElseIf DestinationId == "markarth" || DestinationId == "morthal"
        Return 0.95
    ElseIf DestinationId == "falkreath" || DestinationId == "winterhold"
        Return 0.96
    ElseIf DestinationId == "mixwater_mill" || DestinationId == "halfmoon_mill" || DestinationId == "heartwood_mill"
        Return 0.73
    ElseIf DestinationId == "soljunds_sinkhole"
        Return 0.78
    ElseIf DestinationId == "lakeview_manor" || DestinationId == "heljarchen_hall" || DestinationId == "winstad_manor"
        Return 0.78
    ElseIf DestinationId == "darkwater_crossing" || DestinationId == "kynesgrove" || DestinationId == "karthwasten" || DestinationId == "shors_stone" || DestinationId == "stonehills"
        Return 0.80
    ElseIf DestinationId == "dawnstar"
        Return 1.01
    EndIf
    Return 0.80
EndFunction

String Function GetDestinationMarkerTexture(String DestinationId)
    If DestinationId == "dawnstar"
        Return "Data/textures/DiegeticTravel/norden-dawnstar-capital.dds"
    ElseIf DestinationId == "falkreath"
        Return "Data/textures/DiegeticTravel/norden-falkreath-capital.dds"
    ElseIf DestinationId == "markarth"
        Return "Data/textures/DiegeticTravel/norden-markarth-capital.dds"
    ElseIf DestinationId == "morthal"
        Return "Data/textures/DiegeticTravel/norden-morthal-capital.dds"
    ElseIf DestinationId == "riften"
        Return "Data/textures/DiegeticTravel/norden-riften-capital.dds"
    ElseIf DestinationId == "solitude"
        Return "Data/textures/DiegeticTravel/norden-solitude-capital.dds"
    ElseIf DestinationId == "whiterun"
        Return "Data/textures/DiegeticTravel/norden-whiterun-capital.dds"
    ElseIf DestinationId == "windhelm"
        Return "Data/textures/DiegeticTravel/norden-windhelm-capital.dds"
    ElseIf DestinationId == "winterhold"
        Return "Data/textures/DiegeticTravel/norden-winterhold-capital.dds"
    ElseIf DestinationId == "mixwater_mill" || DestinationId == "halfmoon_mill" || DestinationId == "heartwood_mill"
        Return "Data/textures/DiegeticTravel/norden-wood-mill.dds"
    ElseIf DestinationId == "soljunds_sinkhole"
        Return "Data/textures/DiegeticTravel/norden-mine.dds"
    ElseIf DestinationId == "lakeview_manor" || DestinationId == "heljarchen_hall" || DestinationId == "winstad_manor"
        Return "Data/textures/DiegeticTravel/norden-farm.dds"
    ElseIf DestinationId == "darkwater_crossing" || DestinationId == "kynesgrove" || DestinationId == "karthwasten" || DestinationId == "shors_stone" || DestinationId == "stonehills"
        Return "Data/textures/DiegeticTravel/norden-settlement.dds"
    EndIf
    Return "Data/textures/DiegeticTravel/norden-town.dds"
EndFunction

String Function BuildLabel(String DestinationName, Float Hours)
    Int Tenths = ((Hours * 10.0) + 0.5) as Int
    Int WholeHours = Tenths / 10
    Int DecimalHours = Tenths % 10
    Return DestinationName + " (" + WholeHours + "." + DecimalHours + " hours) "
EndFunction

Function ClearSelections()
    SelectionCount = 0
    SelectionIds = new String[27]
EndFunction

Bool Function RecordSelection(String DestinationId)
    If SelectionCount < 0 || SelectionCount >= 27
        Return False
    EndIf
    SelectionIds[SelectionCount] = DestinationId
    SelectionCount += 1
    Return True
EndFunction

String Function GetSelectionId(Int SelectionIndex)
    If SelectionIndex >= 0 && SelectionIndex < SelectionCount
        Return SelectionIds[SelectionIndex]
    EndIf
    Return ""
EndFunction

Function AbortOpen(String Reason)
    Debug.Trace("[DNT] CARRIAGE_PARCHMENT_DENIED source=" + CurrentSource + " request=" + ActiveRequest + " reason=" + Reason, 1)
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    CurrentSource = None
    ClearSelections()
    Debug.Notification("The carriage map could not be opened. Ask for the usual destinations instead.")
EndFunction

Event OnParchmentResult(String EventName, String StringArg, Float NumberArg, Form Sender)
    If EventName != "DNT_ParchmentResult" || StringArg != ActiveRequest
        Return
    EndIf

    Int SelectionIndex = NumberArg as Int
    ObjectReference SourceRef = CurrentSource
    String FinishedRequest = ActiveRequest
    String DestinationId = GetSelectionId(SelectionIndex)
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    CurrentSource = None
    ClearSelections()

    If SelectionIndex < 0
        Debug.Trace("[DNT] CARRIAGE_PARCHMENT_CANCEL source=" + SourceRef + " request=" + FinishedRequest)
        Return
    EndIf
    If DestinationId == ""
        Debug.Trace("[DNT] CARRIAGE_PARCHMENT_REJECT source=" + SourceRef + " request=" + FinishedRequest + " reason=unknown_index index=" + SelectionIndex, 1)
        Return
    EndIf

    Debug.Trace("[DNT] CARRIAGE_PARCHMENT_SELECT source=" + SourceRef + " request=" + FinishedRequest + " destination=" + DestinationId)
    Coordinator.Purchase(DestinationId, SourceRef)
EndEvent
