Scriptname DNT_WizardParchmentPicker extends Quest

DNT_WizardTravelService Property Service Auto
Form Property MirabelleBase Auto

String MirabellePresentationVoice = "Voice/Skyrim.esm/FemaleUniqueMirabelleErvine/mg01__000d67d1_1.fuz"
String MirabellePresentationSubtitle = "Very good. Then we're done here."
Float MirabellePresentationDurationSeconds = 2.147846

; LoreRim already supplies this loose BC7 texture through RUSTIC MAPS. The
; picker references it but never redistributes it.
String Property TexturePath = "Data/textures/dungeons/imperial/battlemap01.dds" Auto
Float Property ArtAspectRatio = 1.358090 Auto
Float Property TextureUvMinX = 0.0 Auto
Float Property TextureUvMinY = 0.0 Auto
Float Property TextureUvMaxX = 1.0 Auto
; The source is square; its useful parchment ends at source row 3016. Cropping
; there excludes the opaque backing strip below the ragged paper edge.
Float Property TextureUvMaxY = 0.736328 Auto

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
    Float EffectiveArtAspectRatio = 1.358090
    Float EffectiveTextureUvMaxY = 0.736328
    If !DNT_ParchmentNative.BeginRequest(ActiveRequest, "college", SourceRef, TexturePath, EffectiveArtAspectRatio, TextureUvMinX, TextureUvMinY, TextureUvMaxX, EffectiveTextureUvMaxY)
        AbortOpen("begin_failed")
        Return
    EndIf

    ; Papyrus interns string constants case-insensitively. The trailing space
    ; keeps each display label distinct from its lowercase service ID; the
    ; native boundary trims it before rendering.
    Bool AddedAll = DNT_ParchmentNative.SetRouteOrigin(ActiveRequest, 0.752, 0.167)
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "whiterun", "Whiterun ", Service.GetFare("whiterun"), 0.554, 0.507) && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "riften", "Riften ", Service.GetFare("riften"), 0.921, 0.806) && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "solitude", "Solitude ", Service.GetFare("solitude"), 0.330, 0.150) && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "windhelm", "Windhelm ", Service.GetFare("windhelm"), 0.812, 0.372) && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "markarth", "Markarth ", Service.GetFare("markarth"), 0.079, 0.474) && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "dawnstar", "Dawnstar ", Service.GetFare("dawnstar"), 0.570, 0.177) && AddedAll
    AddedAll = DNT_ParchmentNative.AddDestination(ActiveRequest, "morthal", "Morthal ", Service.GetFare("morthal"), 0.402, 0.298) && AddedAll

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
