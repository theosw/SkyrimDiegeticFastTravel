Scriptname DNT_WizardTravelService extends Quest

Actor Property PlayerRef Auto
MiscObject Property Gold001 Auto

ObjectReference Property CollegeMarker Auto
ObjectReference Property WhiterunMarker Auto
ObjectReference Property RiftenMarker Auto

Int Property FarePerHop = 250 Auto

Int Function GetFare(String DestinationId)
    If GetDestinationMarker(DestinationId) == None
        Return -1
    EndIf

    Return FarePerHop
EndFunction

Bool Function CanTravel(String DestinationId)
    If GetDestinationMarker(DestinationId) == None
        Return False
    EndIf

    Return PlayerRef.GetItemCount(Gold001) >= FarePerHop
EndFunction

Bool Function RequestTravel(String DestinationId)
    ObjectReference DestinationMarker = GetDestinationMarker(DestinationId)
    If DestinationMarker == None
        Debug.Trace("[DNT] WIZARD_TRAVEL_DENIED destination=" + DestinationId + " reason=unknown_destination", 1)
        Debug.Notification("Wizard travel is unavailable.")
        Return False
    EndIf

    Int AvailableGold = PlayerRef.GetItemCount(Gold001)
    If AvailableGold < FarePerHop
        Debug.Trace("[DNT] WIZARD_TRAVEL_DENIED destination=" + DestinationId + " reason=gold required=" + FarePerHop + " available=" + AvailableGold)
        Debug.Notification("You need " + FarePerHop + " gold for this journey.")
        Return False
    EndIf

    GoToState("Travelling")
    PlayerRef.RemoveItem(Gold001, FarePerHop, True)
    Debug.Trace("[DNT] WIZARD_TRAVEL_START destination=" + DestinationId + " fare=" + FarePerHop)
    Utility.Wait(1.0)
    PlayerRef.MoveTo(DestinationMarker)
    Debug.Trace("[DNT] WIZARD_TRAVEL_COMPLETE destination=" + DestinationId + " fare=" + FarePerHop)
    GoToState("")
    Return True
EndFunction

ObjectReference Function GetDestinationMarker(String DestinationId)
    If DestinationId == "college"
        Return CollegeMarker
    ElseIf DestinationId == "whiterun"
        Return WhiterunMarker
    ElseIf DestinationId == "riften"
        Return RiftenMarker
    EndIf

    Return None
EndFunction

State Travelling
    Bool Function RequestTravel(String DestinationId)
        Debug.Trace("[DNT] WIZARD_TRAVEL_DENIED destination=" + DestinationId + " reason=already_travelling", 1)
        Return False
    EndFunction
EndState
