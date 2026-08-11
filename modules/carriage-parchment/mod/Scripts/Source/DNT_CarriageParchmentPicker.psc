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
    Float OpenStartedAt = DNT_ParchmentNative.GetMonotonicSeconds()
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
    Float HandoffCompletedAt = DNT_ParchmentNative.GetMonotonicSeconds()
    Utility.Wait(0.15)

    If !DNT_ParchmentNative.IsAvailable()
        AbortOpen("native_unavailable")
        Return
    EndIf

    RequestSerial += 1
    ActiveRequest = "carriage-sheet-" + RequestSerial
    RegisterForModEvent("DNT_ParchmentResult", "OnParchmentResult")
    Float NativeBuildStartedAt = DNT_ParchmentNative.GetMonotonicSeconds()
    Bool FreeRide = Service.IsFreeRideForSpeaker(Speaker)
    SelectionCount = DNT_ParchmentNative.BuildCarriageRequest(ActiveRequest, Service.OriginId, SourceRef, FreeRide)
    If SelectionCount <= 0
        AbortOpen("native_request_failed")
        Return
    EndIf
    If !DNT_ParchmentNative.Show(ActiveRequest)
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("show_failed")
        Return
    EndIf
    Float OpenCompletedAt = DNT_ParchmentNative.GetMonotonicSeconds()
    Debug.Trace("[DNT] CARRIAGE_PARCHMENT_OPEN origin=" + Service.OriginId + " destinations=" + SelectionCount + " request=" + ActiveRequest + " total_ms=" + ((OpenCompletedAt - OpenStartedAt) * 1000.0) + " handoff_ms=" + ((HandoffCompletedAt - OpenStartedAt) * 1000.0) + " native_build_ms=" + ((OpenCompletedAt - NativeBuildStartedAt) * 1000.0))
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
    If ActiveRequest != "" && ActiveRequest != "opening"
        DNT_ParchmentNative.ConsumeCarriageSelectionId(ActiveRequest, -1)
    EndIf
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
    String DestinationId = DNT_ParchmentNative.ConsumeCarriageSelectionId(FinishedRequest, SelectionIndex)
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
