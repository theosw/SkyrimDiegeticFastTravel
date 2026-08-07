Scriptname DNT_CarriageParchmentPicker extends Quest

DNT_TravelCoordinator Property Coordinator Auto

String Property TexturePath = "Data/textures/dungeons/imperial/battlemap01.dds" Auto
Float Property ArtAspectRatio = 1.358090 Auto
Float Property TextureUvMinX = 0.0 Auto
Float Property TextureUvMinY = 0.0 Auto
Float Property TextureUvMaxX = 1.0 Auto
Float Property TextureUvMaxY = 0.736328 Auto

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
    If !DNT_ParchmentNative.BeginRequest(ActiveRequest, "carriage", SourceRef, TexturePath, ArtAspectRatio, TextureUvMinX, TextureUvMinY, TextureUvMaxX, TextureUvMaxY)
        AbortOpen("begin_failed")
        Return
    EndIf

    ClearSelections()
    Bool AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, GetSourceLabel(Service.OriginId))
    AddedAll = DNT_ParchmentNative.SetPaymentLabelPosition(ActiveRequest, 0.631072, 0.912903) && AddedAll
    AddedAll = DNT_ParchmentNative.SetMarkerTextures(ActiveRequest, "Data/textures/DiegeticTravel/norden-town.dds", "Data/textures/DiegeticTravel/norden-town.dds") && AddedAll
    AddedAll = AddStop(Service, "windhelm", "Windhelm", 0.808415, 0.375613) && AddedAll
    AddedAll = AddStop(Service, "darkwater_crossing", "Darkwater Crossing", 0.788602, 0.602873) && AddedAll
    AddedAll = AddStop(Service, "kynesgrove", "Kynesgrove", 0.820442, 0.459519) && AddedAll
    AddedAll = AddStop(Service, "mixwater_mill", "Mixwater Mill", 0.759449, 0.515862) && AddedAll
    AddedAll = AddStop(Service, "falkreath", "Falkreath", 0.417708, 0.780867) && AddedAll
    AddedAll = AddStop(Service, "riverwood", "Riverwood", 0.540788, 0.643839) && AddedAll
    AddedAll = AddStop(Service, "halfmoon_mill", "Half-Moon Mill", 0.397672, 0.692430) && AddedAll
    AddedAll = AddStop(Service, "lakeview_manor", "Lakeview Manor", 0.478909, 0.713975) && AddedAll
    AddedAll = AddStop(Service, "markarth", "Markarth", 0.079000, 0.474000) && AddedAll
    AddedAll = AddStop(Service, "karthwasten", "Karthwasten", 0.174411, 0.369782) && AddedAll
    AddedAll = AddStop(Service, "soljunds_sinkhole", "Soljund's Sinkhole", 0.213053, 0.475712) && AddedAll
    AddedAll = AddStop(Service, "old_hroldan", "Old Hroldan", 0.223189, 0.515493) && AddedAll
    AddedAll = AddStop(Service, "solitude", "Solitude", 0.331839, 0.148204) && AddedAll
    AddedAll = AddStop(Service, "dragon_bridge", "Dragon Bridge", 0.242391, 0.225951) && AddedAll
    AddedAll = AddStop(Service, "whiterun", "Whiterun", 0.550806, 0.506810) && AddedAll
    AddedAll = AddStop(Service, "rorikstead", "Rorikstead", 0.288904, 0.474497) && AddedAll
    AddedAll = AddStop(Service, "winterhold", "Winterhold", 0.754746, 0.170557) && AddedAll
    AddedAll = AddStop(Service, "riften", "Riften", 0.917183, 0.809050) && AddedAll
    AddedAll = AddStop(Service, "ivarstead", "Ivarstead", 0.670308, 0.700205) && AddedAll
    AddedAll = AddStop(Service, "shors_stone", "Shor's Stone", 0.875679, 0.700205) && AddedAll
    AddedAll = AddStop(Service, "heartwood_mill", "Heartwood Mill", 0.819148, 0.792529) && AddedAll
    AddedAll = AddStop(Service, "dawnstar", "Dawnstar", 0.571558, 0.157923) && AddedAll
    AddedAll = AddStop(Service, "nightgate_inn", "Nightgate Inn", 0.671551, 0.349567) && AddedAll
    AddedAll = AddStop(Service, "heljarchen_hall", "Heljarchen Hall", 0.569411, 0.372698) && AddedAll
    AddedAll = AddStop(Service, "morthal", "Morthal", 0.403397, 0.290092) && AddedAll
    AddedAll = AddStop(Service, "stonehills", "Stonehills", 0.475788, 0.291388) && AddedAll
    AddedAll = AddStop(Service, "winstad_manor", "Windstad Manor", 0.434172, 0.179170) && AddedAll

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
    If !DNT_ParchmentNative.AddDestination(ActiveRequest, DestinationId, BuildLabel(DestinationName, Hours), Fare, MapX, MapY)
        Return False
    EndIf
    String MarkerTexture = GetDestinationMarkerTexture(DestinationId)
    If MarkerTexture != ""
        Return DNT_ParchmentNative.SetDestinationMarkerTexture(ActiveRequest, DestinationId, MarkerTexture)
    EndIf
    Return True
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
