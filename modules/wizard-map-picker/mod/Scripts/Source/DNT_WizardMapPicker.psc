Scriptname DNT_WizardMapPicker extends Quest

DNT_WizardTravelService Property Service Auto
FormList Property DestinationWhitelist Auto

ObjectReference Property WhiterunMapMarker Auto
ObjectReference Property RiftenMapMarker Auto
ObjectReference Property SolitudeMapMarker Auto
ObjectReference Property WindhelmMapMarker Auto
ObjectReference Property MarkarthMapMarker Auto

ObjectReference CurrentSource
Bool PickerActive = False
Bool SelectionHandled = False

Function OpenMap(ObjectReference SourceRef)
    If PickerActive
        Debug.Trace("[DNT] WIZARD_MAP_DENIED source=" + SourceRef + " reason=already_open", 1)
        Return
    EndIf

    PickerActive = True
    SelectionHandled = False
    CurrentSource = SourceRef
    RegisterForModEvent("BCD_SetDestination", "OnDestinationSelected")
    Debug.Trace("[DNT] WIZARD_MAP_OPEN source=" + SourceRef)
    BCD_Utils.OpenTheMap(DestinationWhitelist, True)

    ; BCD queues the MapMenu transition. Give the UI one frame before polling.
    Utility.Wait(0.1)
    While UI.IsMenuOpen("MapMenu")
        Utility.Wait(0.1)
    EndWhile

    UnregisterForModEvent("BCD_SetDestination")
    If !SelectionHandled
        Debug.Trace("[DNT] WIZARD_MAP_CANCEL source=" + CurrentSource)
    EndIf
    PickerActive = False
    CurrentSource = None
EndFunction

Event OnDestinationSelected(String EventName, String StringArg, Float NumberArg, Form Sender)
    If !PickerActive || SelectionHandled
        Return
    EndIf

    ObjectReference SelectedMarker = BCD_Utils.GetMapMarkerByIndex(NumberArg as Int)
    String DestinationId = GetDestinationId(SelectedMarker)
    If DestinationId == ""
        Debug.Trace("[DNT] WIZARD_MAP_REJECT source=" + CurrentSource + " reason=unknown_marker marker=" + SelectedMarker, 1)
        Return
    EndIf

    SelectionHandled = True
    ObjectReference SourceRef = CurrentSource
    Debug.Trace("[DNT] WIZARD_MAP_SELECT source=" + SourceRef + " destination=" + DestinationId + " marker=" + SelectedMarker)
    BCD_Utils.CloseTheMap()
    Utility.Wait(0.1)
    Service.RequestTravel(DestinationId, SourceRef)
EndEvent

String Function GetDestinationId(ObjectReference Marker)
    If Marker == WhiterunMapMarker
        Return "whiterun"
    ElseIf Marker == RiftenMapMarker
        Return "riften"
    ElseIf Marker == SolitudeMapMarker
        Return "solitude"
    ElseIf Marker == WindhelmMapMarker
        Return "windhelm"
    ElseIf Marker == MarkarthMapMarker
        Return "markarth"
    EndIf

    Return ""
EndFunction
