Scriptname DNT_WizardTravelService extends Quest

Actor Property PlayerRef Auto
MiscObject Property Gold001 Auto
Sound Property FarePaymentSound Auto

ObjectReference Property CollegeMarker Auto
ObjectReference Property WhiterunMarker Auto
ObjectReference Property RiftenMarker Auto
ObjectReference Property SolitudeMarker Auto
ObjectReference Property WindhelmMarker Auto
ObjectReference Property MarkarthMarker Auto
ObjectReference Property DawnstarMarker Auto
ObjectReference Property MorthalMarker Auto

Int Property FarePerHop = 250 Auto

Int Function GetFare(String DestinationId)
    If GetDestinationMarker(DestinationId) == None
        Return -1
    EndIf

    Return DNT_ParchmentNative.GetWizardFare(FarePerHop)
EndFunction

Bool Function CanTravel(String DestinationId)
    If GetDestinationMarker(DestinationId) == None
        Return False
    EndIf

    Int Fare = GetFare(DestinationId)
    Return Fare >= 0 && PlayerRef.GetItemCount(Gold001) >= Fare
EndFunction

Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef = None)
    ObjectReference DestinationMarker = GetDestinationMarker(DestinationId)
    If DestinationMarker == None
        Debug.Trace("[DNT] WIZARD_TRAVEL_DENIED source=" + SourceRef + " destination=" + DestinationId + " reason=unknown_destination", 1)
        Debug.MessageBox("Wizard travel is unavailable.")
        Return False
    EndIf

    Int Fare = GetFare(DestinationId)
    Int AvailableGold = PlayerRef.GetItemCount(Gold001)
    If Fare < 0
        Debug.Trace("[DNT] WIZARD_TRAVEL_DENIED source=" + SourceRef + " destination=" + DestinationId + " reason=fare_unavailable", 1)
        Debug.MessageBox("Wizard travel is unavailable.")
        Return False
    EndIf
    If AvailableGold < Fare
        Debug.Trace("[DNT] WIZARD_TRAVEL_DENIED source=" + SourceRef + " destination=" + DestinationId + " reason=gold required=" + Fare + " available=" + AvailableGold)
        Debug.Notification("You need " + Fare + " gold for this journey.")
        Return False
    EndIf

    GoToState("Travelling")
    If Fare > 0
        PlayerRef.RemoveItem(Gold001, Fare, True)
    EndIf
    Debug.Trace("[DNT] WIZARD_TRAVEL_START source=" + SourceRef + " destination=" + DestinationId + " fare=" + Fare)
    ; Every reused confirmation is at most 1.11 seconds. Keep the transaction
    ; cue out of that window so it cannot mask the first word, then wait for the
    ; cue itself before MoveTo changes cells.
    Utility.Wait(1.5)
    If FarePaymentSound != None
        FarePaymentSound.PlayAndWait(PlayerRef)
    EndIf
    PlayerRef.MoveTo(DestinationMarker)
    Debug.Trace("[DNT] WIZARD_TRAVEL_COMPLETE source=" + SourceRef + " destination=" + DestinationId + " fare=" + Fare)
    GoToState("")
    Return True
EndFunction

ObjectReference Function GetDestinationMarker(String DestinationId)
    If DestinationId == "college"
        Return GetCollegeMarker()
    ElseIf DestinationId == "whiterun"
        Return WhiterunMarker
    ElseIf DestinationId == "riften"
        Return RiftenMarker
    ElseIf DestinationId == "solitude"
        Return SolitudeMarker
    ElseIf DestinationId == "windhelm"
        Return WindhelmMarker
    ElseIf DestinationId == "markarth"
        Return MarkarthMarker
    ElseIf DestinationId == "dawnstar"
        Return GetDawnstarMarker()
    ElseIf DestinationId == "morthal"
        Return GetMorthalMarker()
    EndIf

    Return None
EndFunction

ObjectReference Function GetDawnstarMarker()
    ; New script properties are serialized into an active quest instance.
    ; Resolve and repair this property at runtime for upgraded saves.
    ObjectReference ServiceMarker = Game.GetFormFromFile(554932, "Skyrim.esm") as ObjectReference
    If ServiceMarker != None && DawnstarMarker != ServiceMarker
        DawnstarMarker = ServiceMarker
        Debug.Trace("[DNT] WIZARD_TRAVEL_MIGRATE property=DawnstarMarker marker=" + DawnstarMarker)
    EndIf

    Return DawnstarMarker
EndFunction

ObjectReference Function GetMorthalMarker()
    ; The city map marker can sit on rebuilt geometry. Skyrim's dedicated
    ; east carriage destination is a ground-level arrival reference and has
    ; no winning override in the tested LoreRim Morthal stack.
    ObjectReference ArrivalMarker = Game.GetFormFromFile(964556, "Skyrim.esm") as ObjectReference
    If ArrivalMarker != None && MorthalMarker != ArrivalMarker
        MorthalMarker = ArrivalMarker
        Debug.Trace("[DNT] WIZARD_TRAVEL_MIGRATE property=MorthalMarker marker=" + MorthalMarker)
    EndIf

    Return MorthalMarker
EndFunction

ObjectReference Function GetCollegeMarker()
    ; Quest script properties are serialized into existing saves. Resolve the
    ; new exterior hub once at runtime so an upgraded save cannot retain the
    ; former MGPhinisSleepMarker value indefinitely.
    ObjectReference ExteriorCollegeMarker = Game.GetFormFromFile(289759, "Skyrim.esm") as ObjectReference
    If ExteriorCollegeMarker != None && CollegeMarker != ExteriorCollegeMarker
        CollegeMarker = ExteriorCollegeMarker
        Debug.Trace("[DNT] WIZARD_TRAVEL_MIGRATE property=CollegeMarker marker=" + CollegeMarker)
    EndIf

    Return CollegeMarker
EndFunction

State Travelling
    Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef = None)
        Debug.Trace("[DNT] WIZARD_TRAVEL_DENIED source=" + SourceRef + " destination=" + DestinationId + " reason=already_travelling", 1)
        Return False
    EndFunction
EndState
