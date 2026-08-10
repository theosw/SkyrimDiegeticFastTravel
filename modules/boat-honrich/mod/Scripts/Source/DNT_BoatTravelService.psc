Scriptname DNT_BoatTravelService extends Quest

String CftoPlugin = "CFTO.esp"

Int RiftenFerrymanForm = 0x00FB28
Int HeartwoodFerrymanForm = 0x00FB24
Int IvarsteadFerrymanForm = 0x014C52
Int HoneysideFerrymanForm = 0x014C8C
Int HoneysideFerrymanRefForm = 0x014C8D

Int RiftenMarkerForm = 0x014C3C
Int HeartwoodMarkerForm = 0x00FB31
Int HeartwoodFollowerMarkerForm = 0x195C2E
Int HeartwoodHorseMarkerForm = 0x195C2F
Int IvarsteadMarkerForm = 0x014C54
Int HoneysideMarkerForm = 0x014C8E
Int FerryCostLocalForm = 0x0BBF93

Int Gold001Form = 0x00000F
Int FarePaymentSoundForm = 0x0334AB
Int FadeToBlackImodForm = 0x0F756D
Int FadeToBlackHoldImodForm = 0x0F756E
Int FadeToBlackBackImodForm = 0x0F756F
Int FollowerQuestForm = 0x0750BA
Int StablesQuestForm = 0x068D73
Int FollowerAliasIndex = 0
Int PlayersHorseAliasIndex = 40

Int Function GetFare(String DestinationId)
    If GetDestinationMarker(DestinationId) == None
        Return -1
    EndIf

    GlobalVariable FareGlobal = Game.GetFormFromFile(FerryCostLocalForm, CftoPlugin) as GlobalVariable
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
    If SourceBase == Game.GetFormFromFile(RiftenFerrymanForm, CftoPlugin)
        Return "riften"
    ElseIf SourceBase == Game.GetFormFromFile(HeartwoodFerrymanForm, CftoPlugin)
        Return "heartwood_mill"
    ElseIf SourceBase == Game.GetFormFromFile(IvarsteadFerrymanForm, CftoPlugin)
        Return "ivarstead"
    ElseIf SourceBase == Game.GetFormFromFile(HoneysideFerrymanForm, CftoPlugin)
        Return "honeyside"
    EndIf
    Return ""
EndFunction

Bool Function CanOfferService(ObjectReference SourceRef)
    Return GetSourceId(SourceRef) != ""
EndFunction

Bool Function CanOfferDestination(String DestinationId)
    If DestinationId != "honeyside"
        Return GetDestinationMarker(DestinationId) != None
    EndIf

    ObjectReference FerrymanRef = Game.GetFormFromFile(HoneysideFerrymanRefForm, CftoPlugin) as ObjectReference
    Return FerrymanRef != None && !FerrymanRef.IsDisabled()
EndFunction

Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef)
    String SourceId = GetSourceId(SourceRef)
    ObjectReference DestinationMarker = GetDestinationMarker(DestinationId)
    If SourceId == ""
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_honrich source=" + SourceRef + " destination=" + DestinationId + " reason=invalid_provider", 1)
        Return False
    EndIf
    If DestinationMarker == None
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_honrich source=" + SourceId + " destination=" + DestinationId + " reason=unknown_destination", 1)
        Return False
    EndIf
    If SourceId == DestinationId
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_honrich source=" + SourceId + " destination=" + DestinationId + " reason=same_stop", 1)
        Return False
    EndIf
    If !CanOfferDestination(DestinationId)
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_honrich source=" + SourceId + " destination=" + DestinationId + " reason=private_service_locked", 1)
        Return False
    EndIf

    Int Fare = GetFare(DestinationId)
    Actor PlayerRef = Game.GetPlayer()
    MiscObject Gold001 = Game.GetFormFromFile(Gold001Form, "Skyrim.esm") as MiscObject
    If Fare < 0 || Gold001 == None
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_honrich source=" + SourceId + " destination=" + DestinationId + " reason=service_unavailable", 1)
        Debug.Notification("Ferry travel is unavailable.")
        Return False
    EndIf

    Int AvailableGold = PlayerRef.GetItemCount(Gold001)
    If AvailableGold < Fare
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_honrich source=" + SourceId + " destination=" + DestinationId + " reason=gold required=" + Fare + " available=" + AvailableGold)
        Debug.Notification("You need " + Fare + " gold for this ferry.")
        Return False
    EndIf

    GoToState("Travelling")
    PlayerRef.RemoveItem(Gold001, Fare, True)
    Debug.Trace("[DNT] BOAT_TRAVEL_START lane=lake_honrich source=" + SourceId + " destination=" + DestinationId + " fare=" + Fare)

    Sound PaymentSound = Game.GetFormFromFile(FarePaymentSoundForm, "Skyrim.esm") as Sound
    If PaymentSound != None
        PaymentSound.PlayAndWait(PlayerRef)
    EndIf

    ExecuteCftoStyleTravel(DestinationId, DestinationMarker, PlayerRef)
    Debug.Trace("[DNT] BOAT_TRAVEL_COMPLETE lane=lake_honrich source=" + SourceId + " destination=" + DestinationId + " fare=" + Fare)
    GoToState("")
    Return True
EndFunction

Function ExecuteCftoStyleTravel(String DestinationId, ObjectReference DestinationMarker, Actor PlayerRef)
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

    ; CFTO's Lake Honrich fragments use Game.FastTravel so time passes. Its
    ; Heartwood fragment additionally moves the current follower and horse to
    ; dedicated jetty markers; the Riften and Ivarstead fragments rely on the
    ; normal fast-travel party handoff.
    Bool UsedApparition = DNT_TravelCompatibility.Travel(PlayerRef, DestinationMarker)
    Debug.Trace("[DNT] BOAT_TRAVEL_MODE lane=lake_honrich destination=" + DestinationId + " apparition=" + UsedApparition)
    If DestinationId == "heartwood_mill"
        MoveCompanionsToHeartwood()
    EndIf

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

Function MoveCompanionsToHeartwood()
    ObjectReference FollowerMarker = Game.GetFormFromFile(HeartwoodFollowerMarkerForm, CftoPlugin) as ObjectReference
    ObjectReference HorseMarker = Game.GetFormFromFile(HeartwoodHorseMarkerForm, CftoPlugin) as ObjectReference
    Quest FollowerQuest = Game.GetFormFromFile(FollowerQuestForm, "Skyrim.esm") as Quest
    Quest StablesQuest = Game.GetFormFromFile(StablesQuestForm, "Skyrim.esm") as Quest

    If FollowerQuest != None && FollowerMarker != None
        ReferenceAlias FollowerAlias = FollowerQuest.GetAlias(FollowerAliasIndex) as ReferenceAlias
        If FollowerAlias != None && FollowerAlias.GetReference() != None
            FollowerAlias.GetReference().MoveTo(FollowerMarker)
        EndIf
    EndIf
    If StablesQuest != None && HorseMarker != None
        ReferenceAlias HorseAlias = StablesQuest.GetAlias(PlayersHorseAliasIndex) as ReferenceAlias
        If HorseAlias != None && HorseAlias.GetReference() != None
            HorseAlias.GetReference().MoveTo(HorseMarker)
        EndIf
    EndIf
EndFunction

ObjectReference Function GetDestinationMarker(String DestinationId)
    If DestinationId == "riften"
        Return Game.GetFormFromFile(RiftenMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "heartwood_mill"
        Return Game.GetFormFromFile(HeartwoodMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "ivarstead"
        Return Game.GetFormFromFile(IvarsteadMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "honeyside"
        Return Game.GetFormFromFile(HoneysideMarkerForm, CftoPlugin) as ObjectReference
    EndIf
    Return None
EndFunction

State Travelling
    Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef)
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_honrich source=" + SourceRef + " destination=" + DestinationId + " reason=already_travelling", 1)
        Return False
    EndFunction
EndState
