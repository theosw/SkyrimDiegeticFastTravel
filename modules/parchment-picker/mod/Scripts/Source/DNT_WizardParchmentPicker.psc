Scriptname DNT_WizardParchmentPicker extends Quest

DNT_WizardTravelService Property Service Auto

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

    ; The dialogue fragment runs OnBegin. Let the terminal response close the
    ; Dialogue Menu before opening the blocking native window and absorb the
    ; input release that selected this dialogue line. Mirabelle's exact-speaker
    ; fallback is deliberately subtitle-only and does not add a timing window.
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

    ; Build the static College map in one native call. This avoids dozens of
    ; Papyrus/native scheduling boundaries while preserving the same ordered
    ; destination indices consumed by GetDestinationId below.
    Int Fare = Service.GetFare("whiterun")
    Int DestinationCount = DNT_ParchmentNative.BuildWizardRequest(ActiveRequest, SourceRef, Fare)
    If DestinationCount != 7
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("request_build_failed")
        Return
    EndIf

    If !DNT_ParchmentNative.Show(ActiveRequest)
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("show_failed")
        Return
    EndIf
    Debug.Trace("[DNT] WIZARD_PARCHMENT_OPEN source=" + SourceRef + " request=" + ActiveRequest + " destinations=" + DestinationCount)
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
