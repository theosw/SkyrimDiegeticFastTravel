Scriptname DNT_WizardParchmentPicker extends Quest

DNT_WizardTravelService Property Service Auto
Form Property MirabelleBase Auto

String MirabellePresentationVoice = "Voice/Skyrim.esm/FemaleUniqueMirabelleErvine/mg01__000d67d1_1.fuz"
String MirabellePresentationSubtitle = "Very good. Then we're done here."
Float MirabellePresentationDurationSeconds = 2.147846

; LoreRim already supplies this loose BC7 texture through Skyrim Paper Map by
; Caro Tuts for FWMF. The picker references it but never redistributes it.
String Property TexturePath = "Data/textures/terrain/tamriel/skyrim.dds" Auto
Float Property ArtAspectRatio = 1.414075 Auto
; The source is square. These bounds isolate the 1728x1222 map illustration
; inside its black texture padding.
Float Property TextureUvMinX = 0.088379 Auto
Float Property TextureUvMinY = 0.187012 Auto
Float Property TextureUvMaxX = 0.932129 Auto
Float Property TextureUvMaxY = 0.783691 Auto

ObjectReference CurrentSource
String ActiveRequest = ""
Int RequestSerial = 0

Function OpenMap(ObjectReference SourceRef)
    If ActiveRequest != ""
        Debug.Trace("[DNT] WIZARD_PARCHMENT_DENIED source=" + SourceRef + " reason=already_open", 1)
        Return
    EndIf

    ActiveRequest = "opening"
    CurrentSource = SourceRef
    Bool VoiceStarted = False
    Float PresentationDelay = 0.0

    ; Mirabelle's dedicated INFO is subtitle-only, so waiting for the Dialogue
    ; Menu to close would first play that entire silent response. Queue the
    ; proven actor-targeted FUZ immediately from OnBegin instead. The native
    ; task pauses the current silent response, queues its normal subtitle, and
    ; returns the measured payload duration plus one short task margin.
    If SourceRef != None && MirabelleBase != None && SourceRef.GetBaseObject() == MirabelleBase
        PresentationDelay = DNT_ParchmentNative.PlayPresentation(SourceRef, MirabellePresentationVoice, MirabellePresentationSubtitle, MirabellePresentationDurationSeconds)
        VoiceStarted = PresentationDelay > 0.0
        If VoiceStarted
            Debug.Trace("[DNT] WIZARD_PARCHMENT_PRESENTATION_QUEUED source=" + SourceRef + " timing=info_on_begin mapSuppressed=false presentationSeconds=" + PresentationDelay)
        Else
            Debug.Trace("[DNT] WIZARD_PARCHMENT_PRESENTATION_REJECT source=" + SourceRef + " timing=info_on_begin mapSuppressed=false fallback=map", 2)
        EndIf
    EndIf

    ; The dialogue fragment runs OnBegin. Let the terminal response close the
    ; Dialogue Menu before opening the blocking native window, and absorb the
    ; input release that selected this dialogue line. Mirabelle first receives
    ; her measured voice/subtitle presentation window.
    If PresentationDelay > 0.0
        Utility.Wait(PresentationDelay)
    EndIf
    Utility.Wait(0.1)
    Int DialogueWaitTicks = 0
    While UI.IsMenuOpen("Dialogue Menu") && DialogueWaitTicks < 50
        Utility.Wait(0.1)
        DialogueWaitTicks += 1
    EndWhile
    If UI.IsMenuOpen("Dialogue Menu")
        AbortOpen("dialogue_timeout")
        Return
    EndIf
    Utility.Wait(0.15)

    If !DNT_ParchmentNative.IsAvailable()
        Debug.Trace("[DNT] WIZARD_PARCHMENT_DENIED source=" + SourceRef + " reason=native_unavailable", 1)
        Debug.Notification("The travel map is unavailable. Use the destination dialogue instead.")
        ActiveRequest = ""
        CurrentSource = None
        Return
    EndIf

    RequestSerial += 1
    ActiveRequest = "wizard-" + RequestSerial
    RegisterForModEvent("DNT_ParchmentResult", "OnParchmentResult")

    ; Use the artwork profile explicitly so an existing save cannot retain the
    ; previous 4:3/0.75 auto-property values.
    String EffectiveTexturePath = "Data/textures/terrain/tamriel/skyrim.dds"
    Float EffectiveArtAspectRatio = 1.414075
    Float EffectiveTextureUvMinX = 0.088379
    Float EffectiveTextureUvMinY = 0.187012
    Float EffectiveTextureUvMaxX = 0.932129
    Float EffectiveTextureUvMaxY = 0.783691
    If !DNT_ParchmentNative.BeginRequest(ActiveRequest, "college", SourceRef, EffectiveTexturePath, EffectiveArtAspectRatio, EffectiveTextureUvMinX, EffectiveTextureUvMinY, EffectiveTextureUvMaxX, EffectiveTextureUvMaxY)
        AbortOpen("begin_failed")
        Return
    EndIf

    ; Papyrus interns string constants case-insensitively. The trailing space
    ; keeps each display label distinct from its lowercase service ID; the
    ; native boundary trims it before rendering.
    ; Formal wizard and carriage maps default to Norden's discovered-map
    ; language. Vanilla hold markers remain packaged as a future/fallback
    ; theme, but every live wizard destination uses the Norden symbol set.
    Bool AddedAll = DNT_ParchmentNative.SetMarkerTextures(ActiveRequest, "Data/textures/DiegeticTravel/norden-town.dds", "Data/textures/DiegeticTravel/norden-town.dds")
    AddedAll = DNT_ParchmentNative.SetOriginMarkerTexture(ActiveRequest, "Data/textures/DiegeticTravel/norden-winterhold-capital.dds") && AddedAll
    AddedAll = DNT_ParchmentNative.SetSelectionRingTexture(ActiveRequest, "Data/textures/DiegeticTravel/thin-circle-selection-ring.dds") && AddedAll
    AddedAll = DNT_ParchmentNative.SetSourceLabel(ActiveRequest, "College of Winterhold") && AddedAll
    AddedAll = DNT_ParchmentNative.SetPaymentLabelPosition(ActiveRequest, 0.616470, 0.924230) && AddedAll
    ; Positions are calculated from the FWMF Tamriel quad and the exact vanilla
    ; map-marker world coordinates, then normalized into the crop above.
    AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.750802, 0.167836) && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "whiterun", "Whiterun ", Service.GetFare("whiterun"), 0.532756, 0.548290) && AddedAll
    AddedAll = DNT_ParchmentNative.SetDestinationMarkerTexture(ActiveRequest, "whiterun", "Data/textures/DiegeticTravel/norden-whiterun-capital.dds") && AddedAll
    AddedAll = ApplyDestinationSelectionRingStyle("whiterun") && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "riften", "Riften ", Service.GetFare("riften"), 0.880078, 0.833512) && AddedAll
    AddedAll = DNT_ParchmentNative.SetDestinationMarkerTexture(ActiveRequest, "riften", "Data/textures/DiegeticTravel/norden-riften-capital.dds") && AddedAll
    AddedAll = ApplyDestinationSelectionRingStyle("riften") && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "solitude", "Solitude ", Service.GetFare("solitude"), 0.365471, 0.191247) && AddedAll
    AddedAll = DNT_ParchmentNative.SetDestinationMarkerTexture(ActiveRequest, "solitude", "Data/textures/DiegeticTravel/norden-solitude-capital.dds") && AddedAll
    AddedAll = ApplyDestinationSelectionRingStyle("solitude") && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "windhelm", "Windhelm ", Service.GetFare("windhelm"), 0.793249, 0.410699) && AddedAll
    AddedAll = DNT_ParchmentNative.SetDestinationMarkerTexture(ActiveRequest, "windhelm", "Data/textures/DiegeticTravel/norden-windhelm-capital.dds") && AddedAll
    AddedAll = ApplyDestinationSelectionRingStyle("windhelm") && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "markarth", "Markarth ", Service.GetFare("markarth"), 0.094238, 0.507741) && AddedAll
    AddedAll = DNT_ParchmentNative.SetDestinationMarkerTexture(ActiveRequest, "markarth", "Data/textures/DiegeticTravel/norden-markarth-capital.dds") && AddedAll
    AddedAll = ApplyDestinationSelectionRingStyle("markarth") && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "dawnstar", "Dawnstar ", Service.GetFare("dawnstar"), 0.557529, 0.185081) && AddedAll
    AddedAll = DNT_ParchmentNative.SetDestinationMarkerTexture(ActiveRequest, "dawnstar", "Data/textures/DiegeticTravel/norden-dawnstar-capital.dds") && AddedAll
    AddedAll = ApplyDestinationSelectionRingStyle("dawnstar") && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "morthal", "Morthal ", Service.GetFare("morthal"), 0.400452, 0.311110) && AddedAll
    AddedAll = DNT_ParchmentNative.SetDestinationMarkerTexture(ActiveRequest, "morthal", "Data/textures/DiegeticTravel/norden-morthal-capital.dds") && AddedAll
    AddedAll = ApplyDestinationSelectionRingStyle("morthal") && AddedAll

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
    Debug.Trace("[DNT] WIZARD_PARCHMENT_OPEN source=" + SourceRef + " request=" + ActiveRequest + " presentationVoice=" + VoiceStarted)
EndFunction

Bool Function ApplyDestinationSelectionRingStyle(String DestinationId)
    If !DNT_ParchmentNative.SetDestinationMarkerScale(ActiveRequest, DestinationId, GetDestinationMarkerScale(DestinationId))
        Return False
    EndIf
    If DestinationId == "whiterun"
        Return DNT_ParchmentNative.SetDestinationSelectionRingStyle(ActiveRequest, DestinationId, 0.0316, -0.0474, 0.88)
    ElseIf DestinationId == "riften"
        Return DNT_ParchmentNative.SetDestinationSelectionRingStyle(ActiveRequest, DestinationId, 0.0, -0.0580, 0.88)
    ElseIf DestinationId == "solitude"
        Return DNT_ParchmentNative.SetDestinationSelectionRingStyle(ActiveRequest, DestinationId, 0.0, -0.0474, 0.85)
    ElseIf DestinationId == "windhelm"
        Return DNT_ParchmentNative.SetDestinationSelectionRingStyle(ActiveRequest, DestinationId, 0.0316, -0.1001, 0.89)
    ElseIf DestinationId == "markarth"
        Return DNT_ParchmentNative.SetDestinationSelectionRingStyle(ActiveRequest, DestinationId, 0.0, -0.1107, 0.89)
    ElseIf DestinationId == "dawnstar"
        Return DNT_ParchmentNative.SetDestinationSelectionRingStyle(ActiveRequest, DestinationId, 0.0, -0.0474, 0.86)
    ElseIf DestinationId == "morthal"
        Return DNT_ParchmentNative.SetDestinationSelectionRingStyle(ActiveRequest, DestinationId, 0.0, -0.0896, 0.92)
    EndIf
    Return True
EndFunction

Float Function GetDestinationMarkerScale(String DestinationId)
    If DestinationId == "whiterun"
        Return 1.0
    ElseIf DestinationId == "riften"
        Return 0.99
    ElseIf DestinationId == "solitude"
        Return 1.0
    ElseIf DestinationId == "windhelm"
        Return 0.93
    ElseIf DestinationId == "markarth"
        Return 0.95
    ElseIf DestinationId == "morthal"
        Return 0.95
    ElseIf DestinationId == "dawnstar"
        Return 1.01
    EndIf
    Return 1.0
EndFunction

Function AbortOpen(String Reason)
    Debug.Trace("[DNT] WIZARD_PARCHMENT_DENIED source=" + CurrentSource + " request=" + ActiveRequest + " reason=" + Reason, 1)
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    CurrentSource = None
    Debug.Notification("The travel map could not be opened. Use the destination dialogue instead.")
EndFunction

Event OnParchmentResult(String EventName, String StringArg, Float NumberArg, Form Sender)
    If EventName != "DNT_ParchmentResult" || StringArg != ActiveRequest
        Return
    EndIf

    Int SelectionIndex = NumberArg as Int
    ObjectReference SourceRef = CurrentSource
    String FinishedRequest = ActiveRequest
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    CurrentSource = None

    If SelectionIndex < 0
        Debug.Trace("[DNT] WIZARD_PARCHMENT_CANCEL source=" + SourceRef + " request=" + FinishedRequest)
        Return
    EndIf

    String DestinationId = GetDestinationId(SelectionIndex)
    If DestinationId == ""
        Debug.Trace("[DNT] WIZARD_PARCHMENT_REJECT source=" + SourceRef + " request=" + FinishedRequest + " reason=unknown_index index=" + SelectionIndex, 1)
        Return
    EndIf

    Debug.Trace("[DNT] WIZARD_PARCHMENT_SELECT source=" + SourceRef + " request=" + FinishedRequest + " destination=" + DestinationId)
    Service.RequestTravel(DestinationId, SourceRef)
EndEvent

String Function GetDestinationId(Int SelectionIndex)
    If SelectionIndex == 0
        Return "whiterun"
    ElseIf SelectionIndex == 1
        Return "riften"
    ElseIf SelectionIndex == 2
        Return "solitude"
    ElseIf SelectionIndex == 3
        Return "windhelm"
    ElseIf SelectionIndex == 4
        Return "markarth"
    ElseIf SelectionIndex == 5
        Return "dawnstar"
    ElseIf SelectionIndex == 6
        Return "morthal"
    EndIf
    Return ""
EndFunction
