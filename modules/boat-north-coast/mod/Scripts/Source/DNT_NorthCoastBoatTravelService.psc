Scriptname DNT_NorthCoastBoatTravelService extends Quest

String CftoPlugin = "CFTO.esp"

Int DawnstarFerrymanForm = 0x00AA07
Int SolitudeFerrymanForm = 0x00AA08
Int WindhelmFerrymanForm = 0x00AA09
Int MorthalFerrymanForm = 0x00AA0B
Int LighthouseFerrymanForm = 0x014C5A
Int WinterholdFerrymanForm = 0x158FFC
Int DragonBridgeFerrymanForm = 0x2D4C09

Int DawnstarMarkerForm = 0x00FB1F
Int SolitudeMarkerForm = 0x00FB1E
Int WindhelmMarkerForm = 0x00FB1D
Int MorthalMarkerForm = 0x00FB17
Int LighthouseMarkerForm = 0x019DB2
Int WinterholdMarkerForm = 0x038413
Int DragonBridgeMarkerForm = 0x29D0A4
Int FerryCostForm = 0x00AA12

Int Gold001Form = 0x00000F
Int FarePaymentSoundForm = 0x0334AB
Int FadeToBlackImodForm = 0x0F756D
Int FadeToBlackHoldImodForm = 0x0F756E
Int FadeToBlackBackImodForm = 0x0F756F

Int Function GetFare(String DestinationId)
    If GetDestinationMarker(DestinationId) == None
        Return -1
    EndIf

    GlobalVariable FareGlobal = Game.GetFormFromFile(FerryCostForm, CftoPlugin) as GlobalVariable
    If FareGlobal == None
        Return -1
    EndIf
    Return FareGlobal.GetValueInt()
EndFunction

String Function GetSourceId(ObjectReference SourceRef)
    If SourceRef == None
        Return ""
    EndIf

    Form SourceBase = SourceRef.GetBaseObject()
    If SourceBase == Game.GetFormFromFile(DawnstarFerrymanForm, CftoPlugin)
        Return "dawnstar"
    ElseIf SourceBase == Game.GetFormFromFile(SolitudeFerrymanForm, CftoPlugin)
        Return "solitude"
    ElseIf SourceBase == Game.GetFormFromFile(WindhelmFerrymanForm, CftoPlugin)
        Return "windhelm"
    ElseIf SourceBase == Game.GetFormFromFile(MorthalFerrymanForm, CftoPlugin)
        Return "morthal"
    ElseIf SourceBase == Game.GetFormFromFile(LighthouseFerrymanForm, CftoPlugin)
        Return "solitude_lighthouse"
    ElseIf SourceBase == Game.GetFormFromFile(WinterholdFerrymanForm, CftoPlugin)
        Return "winterhold"
    ElseIf SourceBase == Game.GetFormFromFile(DragonBridgeFerrymanForm, CftoPlugin)
        Return "dragon_bridge"
    EndIf
    Return ""
EndFunction

Bool Function CanOfferService(ObjectReference SourceRef)
    Return GetSourceId(SourceRef) != ""
EndFunction

Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef)
    String SourceId = GetSourceId(SourceRef)
    ObjectReference DestinationMarker = GetDestinationMarker(DestinationId)
    If SourceId == ""
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=north_coast source=" + SourceRef + " destination=" + DestinationId + " reason=invalid_provider", 1)
        Return False
    EndIf
    If DestinationMarker == None
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=north_coast source=" + SourceId + " destination=" + DestinationId + " reason=unknown_destination", 1)
        Return False
    EndIf
    If SourceId == DestinationId
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=north_coast source=" + SourceId + " destination=" + DestinationId + " reason=same_stop", 1)
        Return False
    EndIf

    Int Fare = GetFare(DestinationId)
    Actor PlayerRef = Game.GetPlayer()
    MiscObject Gold001 = Game.GetFormFromFile(Gold001Form, "Skyrim.esm") as MiscObject
    If Fare < 0 || Gold001 == None
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=north_coast source=" + SourceId + " destination=" + DestinationId + " reason=service_unavailable", 1)
        Debug.Notification("Ferry travel is unavailable.")
        Return False
    EndIf

    Int AvailableGold = PlayerRef.GetItemCount(Gold001)
    If AvailableGold < Fare
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=north_coast source=" + SourceId + " destination=" + DestinationId + " reason=gold required=" + Fare + " available=" + AvailableGold)
        Debug.Notification("You need " + Fare + " gold for this ferry.")
        Return False
    EndIf

    GoToState("Travelling")
    PlayerRef.RemoveItem(Gold001, Fare, True)
    Debug.Trace("[DNT] BOAT_TRAVEL_START lane=north_coast source=" + SourceId + " destination=" + DestinationId + " fare=" + Fare)

    Sound PaymentSound = Game.GetFormFromFile(FarePaymentSoundForm, "Skyrim.esm") as Sound
    If PaymentSound != None
        PaymentSound.PlayAndWait(PlayerRef)
    EndIf

    ExecuteCftoStyleTravel(DestinationMarker, PlayerRef)
    Debug.Trace("[DNT] BOAT_TRAVEL_COMPLETE lane=north_coast source=" + SourceId + " destination=" + DestinationId + " fare=" + Fare)
    GoToState("")
    Return True
EndFunction

Function ExecuteCftoStyleTravel(ObjectReference DestinationMarker, Actor PlayerRef)
    ImageSpaceModifier FadeToBlackImod = Game.GetFormFromFile(FadeToBlackImodForm, "Skyrim.esm") as ImageSpaceModifier
    ImageSpaceModifier FadeToBlackHoldImod = Game.GetFormFromFile(FadeToBlackHoldImodForm, "Skyrim.esm") as ImageSpaceModifier
    ImageSpaceModifier FadeToBlackBackImod = Game.GetFormFromFile(FadeToBlackBackImodForm, "Skyrim.esm") as ImageSpaceModifier

    If FadeToBlackImod != None
        FadeToBlackImod.Apply()
        Utility.Wait(2.0)
        If FadeToBlackHoldImod != None
            FadeToBlackImod.PopTo(FadeToBlackHoldImod)
        EndIf
    EndIf

    Float CarryWeight = PlayerRef.GetActorValue("CarryWeight")
    Float InventoryWeight = PlayerRef.GetActorValue("InventoryWeight")
    Float DeltaWeight = (InventoryWeight + 1.0) - CarryWeight
    If DeltaWeight > 0.0
        PlayerRef.ModActorValue("CarryWeight", DeltaWeight)
    EndIf

    Game.FastTravel(DestinationMarker)

    If FadeToBlackHoldImod != None
        If FadeToBlackBackImod != None
            FadeToBlackHoldImod.PopTo(FadeToBlackBackImod)
        EndIf
        FadeToBlackHoldImod.Remove()
    EndIf
    If DeltaWeight > 0.0
        PlayerRef.ModActorValue("CarryWeight", -DeltaWeight)
    EndIf
EndFunction

ObjectReference Function GetDestinationMarker(String DestinationId)
    If DestinationId == "dawnstar"
        Return Game.GetFormFromFile(DawnstarMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "solitude"
        Return Game.GetFormFromFile(SolitudeMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "windhelm"
        Return Game.GetFormFromFile(WindhelmMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "morthal"
        Return Game.GetFormFromFile(MorthalMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "solitude_lighthouse"
        Return Game.GetFormFromFile(LighthouseMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "winterhold"
        Return Game.GetFormFromFile(WinterholdMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "dragon_bridge"
        Return Game.GetFormFromFile(DragonBridgeMarkerForm, CftoPlugin) as ObjectReference
    EndIf
    Return None
EndFunction

State Travelling
    Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef)
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=north_coast source=" + SourceRef + " destination=" + DestinationId + " reason=already_travelling", 1)
        Return False
    EndFunction
EndState
