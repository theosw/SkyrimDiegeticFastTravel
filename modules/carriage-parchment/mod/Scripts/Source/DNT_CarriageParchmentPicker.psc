Scriptname DNT_CarriageParchmentPicker extends Quest

DNT_TravelCoordinator Property Coordinator Auto

ObjectReference CurrentSource
String ActiveRequest = ""
Int RequestSerial = 0

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

    Float HandoffCompletedAt = DNT_ParchmentNative.GetMonotonicSeconds()
    Debug.Trace("[DNT] CARRIAGE_DIALOGUE_HANDOFF_COMPLETE origin=" + Service.OriginId + " closeRequested=" + DialogueWasOpen + " waitTicks=" + DialogueWaitTicks)
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
    Int DestinationCount = DNT_ParchmentNative.BuildCarriageRequest(ActiveRequest, Service.OriginId, SourceRef, FreeRide)
    If DestinationCount <= 0
        AbortOpen("native_request_failed")
        Return
    EndIf
    If !DNT_ParchmentNative.Show(ActiveRequest)
        DNT_ParchmentNative.Cancel(ActiveRequest)
        AbortOpen("show_failed")
        Return
    EndIf

    Float OpenCompletedAt = DNT_ParchmentNative.GetMonotonicSeconds()
    Debug.Trace("[DNT] CARRIAGE_PARCHMENT_OPEN origin=" + Service.OriginId + " destinations=" + DestinationCount + " request=" + ActiveRequest + " total_ms=" + ((OpenCompletedAt - OpenStartedAt) * 1000.0) + " handoff_ms=" + ((HandoffCompletedAt - OpenStartedAt) * 1000.0) + " native_build_ms=" + ((OpenCompletedAt - NativeBuildStartedAt) * 1000.0))
EndFunction

Function AbortOpen(String Reason)
    Debug.Trace("[DNT] CARRIAGE_PARCHMENT_DENIED source=" + CurrentSource + " request=" + ActiveRequest + " reason=" + Reason, 1)
    If ActiveRequest != "" && ActiveRequest != "opening"
        DNT_ParchmentNative.ConsumeCarriageSelectionId(ActiveRequest, -1)
    EndIf
    UnregisterForModEvent("DNT_ParchmentResult")
    ActiveRequest = ""
    CurrentSource = None
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
