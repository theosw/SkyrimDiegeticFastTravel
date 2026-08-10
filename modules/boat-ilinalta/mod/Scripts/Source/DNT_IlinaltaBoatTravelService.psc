Scriptname DNT_IlinaltaBoatTravelService extends Quest

String CftoPlugin = "CFTO.esp"

Int BrittleshinFerrymanForm = 0x02E1E6
Int HalfMoonFerrymanForm = 0x0332ED
Int GuardianFerrymanForm = 0x0332F5
Int LakeviewFerrymanForm = 0x014C80
Int LakeviewFerrymanRefForm = 0x014C81

Int BrittleshinMarkerForm = 0x014C8F
Int BrittleshinHorseMarkerForm = 0x195C32
Int HalfMoonMarkerForm = 0x014C95
Int GuardianMarkerForm = 0x0332F7
Int GuardianFollowerMarkerForm = 0x195C33
Int GuardianHorseMarkerForm = 0x195C34
Int IlinataMarkerForm = 0x03840E
Int IlinataFollowerMarkerForm = 0x195C43
Int IlinataHorseMarkerForm = 0x195C35
Int LakeviewMarkerForm = 0x014C7E
Int LakeviewFollowerMarkerForm = 0x195C30
Int LakeviewHorseMarkerForm = 0x195C31
Int FerryCostLocalForm = 0x0BBF93
Int FerryCostRegionalForm = 0x00AA12

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

    Int FareForm = FerryCostLocalForm
    If DestinationId == "ilinatas_deep"
        FareForm = FerryCostRegionalForm
    EndIf
    GlobalVariable FareGlobal = Game.GetFormFromFile(FareForm, CftoPlugin) as GlobalVariable
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
    If SourceBase == Game.GetFormFromFile(BrittleshinFerrymanForm, CftoPlugin)
        Return "brittleshin_pass"
    ElseIf SourceBase == Game.GetFormFromFile(HalfMoonFerrymanForm, CftoPlugin)
        Return "half_moon_mill"
    ElseIf SourceBase == Game.GetFormFromFile(GuardianFerrymanForm, CftoPlugin)
        Return "guardian_stones"
    ElseIf SourceBase == Game.GetFormFromFile(LakeviewFerrymanForm, CftoPlugin)
        Return "lakeview_manor"
    EndIf
    Return ""
EndFunction

Bool Function CanOfferService(ObjectReference SourceRef)
    Return GetSourceId(SourceRef) != ""
EndFunction

Bool Function CanOfferDestination(String DestinationId)
    If DestinationId != "lakeview_manor"
        Return GetDestinationMarker(DestinationId) != None
    EndIf

    ObjectReference FerrymanRef = Game.GetFormFromFile(LakeviewFerrymanRefForm, CftoPlugin) as ObjectReference
    Return FerrymanRef != None && !FerrymanRef.IsDisabled()
EndFunction

Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef)
    String SourceId = GetSourceId(SourceRef)
    ObjectReference DestinationMarker = GetDestinationMarker(DestinationId)
    If SourceId == ""
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_ilinalta source=" + SourceRef + " destination=" + DestinationId + " reason=invalid_provider", 1)
        Return False
    EndIf
    If DestinationMarker == None
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_ilinalta source=" + SourceId + " destination=" + DestinationId + " reason=unknown_destination", 1)
        Return False
    EndIf
    If SourceId == DestinationId
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_ilinalta source=" + SourceId + " destination=" + DestinationId + " reason=same_stop", 1)
        Return False
    EndIf
    If !CanOfferDestination(DestinationId)
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_ilinalta source=" + SourceId + " destination=" + DestinationId + " reason=private_service_locked", 1)
        Return False
    EndIf

    Int Fare = GetFare(DestinationId)
    Actor PlayerRef = Game.GetPlayer()
    MiscObject Gold001 = Game.GetFormFromFile(Gold001Form, "Skyrim.esm") as MiscObject
    If Fare < 0 || Gold001 == None
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_ilinalta source=" + SourceId + " destination=" + DestinationId + " reason=service_unavailable", 1)
        Debug.Notification("Ferry travel is unavailable.")
        Return False
    EndIf

    Int AvailableGold = PlayerRef.GetItemCount(Gold001)
    If AvailableGold < Fare
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_ilinalta source=" + SourceId + " destination=" + DestinationId + " reason=gold required=" + Fare + " available=" + AvailableGold)
        Debug.Notification("You need " + Fare + " gold for this ferry.")
        Return False
    EndIf

    GoToState("Travelling")
    PlayerRef.RemoveItem(Gold001, Fare, True)
    Debug.Trace("[DNT] BOAT_TRAVEL_START lane=lake_ilinalta source=" + SourceId + " destination=" + DestinationId + " fare=" + Fare)

    Sound PaymentSound = Game.GetFormFromFile(FarePaymentSoundForm, "Skyrim.esm") as Sound
    If PaymentSound != None
        PaymentSound.PlayAndWait(PlayerRef)
    EndIf

    ExecuteCftoStyleTravel(DestinationId, DestinationMarker, PlayerRef)
    Debug.Trace("[DNT] BOAT_TRAVEL_COMPLETE lane=lake_ilinalta source=" + SourceId + " destination=" + DestinationId + " fare=" + Fare)
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

    Bool UsedApparition = DNT_TravelCompatibility.Travel(PlayerRef, DestinationMarker)
    Debug.Trace("[DNT] BOAT_TRAVEL_MODE lane=lake_ilinalta destination=" + DestinationId + " apparition=" + UsedApparition)
    If DestinationId == "brittleshin_pass"
        MoveHorseTo(BrittleshinHorseMarkerForm)
    ElseIf DestinationId == "guardian_stones"
        MoveFollowerAndHorseToGuardian()
    ElseIf DestinationId == "ilinatas_deep"
        MoveFollowerAndHorseToIlinata()
    ElseIf DestinationId == "lakeview_manor"
        MoveFollowerAndHorseTo(LakeviewFollowerMarkerForm, LakeviewHorseMarkerForm)
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

Function MoveHorseTo(Int MarkerForm)
    ObjectReference HorseMarker = Game.GetFormFromFile(MarkerForm, CftoPlugin) as ObjectReference
    Quest StablesQuest = Game.GetFormFromFile(StablesQuestForm, "Skyrim.esm") as Quest
    If StablesQuest != None && HorseMarker != None
        ReferenceAlias HorseAlias = StablesQuest.GetAlias(PlayersHorseAliasIndex) as ReferenceAlias
        If HorseAlias != None && HorseAlias.GetReference() != None
            HorseAlias.GetReference().MoveTo(HorseMarker)
        EndIf
    EndIf
EndFunction

Function MoveFollowerAndHorseToGuardian()
    ObjectReference FollowerMarker = Game.GetFormFromFile(GuardianFollowerMarkerForm, CftoPlugin) as ObjectReference
    Quest FollowerQuest = Game.GetFormFromFile(FollowerQuestForm, "Skyrim.esm") as Quest
    If FollowerQuest != None && FollowerMarker != None
        ReferenceAlias FollowerAlias = FollowerQuest.GetAlias(FollowerAliasIndex) as ReferenceAlias
        If FollowerAlias != None && FollowerAlias.GetReference() != None
            FollowerAlias.GetReference().MoveTo(FollowerMarker)
        EndIf
    EndIf
    MoveHorseTo(GuardianHorseMarkerForm)
EndFunction

Function MoveFollowerAndHorseToIlinata()
    ObjectReference FollowerMarker = Game.GetFormFromFile(IlinataFollowerMarkerForm, CftoPlugin) as ObjectReference
    Quest FollowerQuest = Game.GetFormFromFile(FollowerQuestForm, "Skyrim.esm") as Quest
    If FollowerQuest != None && FollowerMarker != None
        ReferenceAlias FollowerAlias = FollowerQuest.GetAlias(FollowerAliasIndex) as ReferenceAlias
        If FollowerAlias != None && FollowerAlias.GetReference() != None
            FollowerAlias.GetReference().MoveTo(FollowerMarker)
        EndIf
    EndIf
    MoveHorseTo(IlinataHorseMarkerForm)
EndFunction

Function MoveFollowerAndHorseTo(Int FollowerMarkerForm, Int HorseMarkerForm)
    ObjectReference FollowerMarker = Game.GetFormFromFile(FollowerMarkerForm, CftoPlugin) as ObjectReference
    Quest FollowerQuest = Game.GetFormFromFile(FollowerQuestForm, "Skyrim.esm") as Quest
    If FollowerQuest != None && FollowerMarker != None
        ReferenceAlias FollowerAlias = FollowerQuest.GetAlias(FollowerAliasIndex) as ReferenceAlias
        If FollowerAlias != None && FollowerAlias.GetReference() != None
            FollowerAlias.GetReference().MoveTo(FollowerMarker)
        EndIf
    EndIf
    MoveHorseTo(HorseMarkerForm)
EndFunction

ObjectReference Function GetDestinationMarker(String DestinationId)
    If DestinationId == "brittleshin_pass"
        Return Game.GetFormFromFile(BrittleshinMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "half_moon_mill"
        Return Game.GetFormFromFile(HalfMoonMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "guardian_stones"
        Return Game.GetFormFromFile(GuardianMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "ilinatas_deep"
        Return Game.GetFormFromFile(IlinataMarkerForm, CftoPlugin) as ObjectReference
    ElseIf DestinationId == "lakeview_manor"
        Return Game.GetFormFromFile(LakeviewMarkerForm, CftoPlugin) as ObjectReference
    EndIf
    Return None
EndFunction

State Travelling
    Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef)
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=lake_ilinalta source=" + SourceRef + " destination=" + DestinationId + " reason=already_travelling", 1)
        Return False
    EndFunction
EndState
