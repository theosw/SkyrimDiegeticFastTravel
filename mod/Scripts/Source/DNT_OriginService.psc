Scriptname DNT_OriginService extends Quest

GlobalVariable Property KmodCarriageDestination Auto
Faction Property KmodCarriageFreeFaction Auto
Actor Property PlayerRef Auto
MiscObject Property Gold001 Auto

String Property OriginId Auto

Bool Function IsFreeRideForSpeaker(Actor speaker)
    Return KmodCarriageFreeFaction && speaker && speaker.IsInFaction(KmodCarriageFreeFaction)
EndFunction

ObjectReference Function GetCarriageDestinationMarker(String destinationId)
    ; These are CFTO's own ground-level XMarkerHeading arrival references.
    ; Resolve them dynamically so the beta does not serialize 27 new quest
    ; properties into existing saves and does not depend on a driver's VMAD.
    If destinationId == "windhelm"
        Return Game.GetFormFromFile(0x0A7B39, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "darkwater_crossing"
        Return Game.GetFormFromFile(0x0B6E4B, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "kynesgrove"
        Return Game.GetFormFromFile(0x0B6E4C, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "mixwater_mill"
        Return Game.GetFormFromFile(0x0B6E4D, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "falkreath"
        Return Game.GetFormFromFile(0x0B6E43, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "riverwood"
        Return Game.GetFormFromFile(0x0B6E4E, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "halfmoon_mill"
        Return Game.GetFormFromFile(0x0B6E4F, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "lakeview_manor"
        Return Game.GetFormFromFile(0x0CB326, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "markarth"
        Return Game.GetFormFromFile(0x0B6E44, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "karthwasten"
        Return Game.GetFormFromFile(0x0B6E50, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "soljunds_sinkhole"
        Return Game.GetFormFromFile(0x0B6E51, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "old_hroldan"
        Return Game.GetFormFromFile(0x0B6E52, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "solitude"
        Return Game.GetFormFromFile(0x0B6E45, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "dragon_bridge"
        Return Game.GetFormFromFile(0x0B6E53, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "whiterun"
        Return Game.GetFormFromFile(0x0B6E46, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "rorikstead"
        Return Game.GetFormFromFile(0x0B6E55, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "winterhold"
        Return Game.GetFormFromFile(0x0B6E47, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "riften"
        Return Game.GetFormFromFile(0x0B6E48, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "ivarstead"
        Return Game.GetFormFromFile(0x0B6E56, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "shors_stone"
        Return Game.GetFormFromFile(0x0B6E57, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "heartwood_mill"
        Return Game.GetFormFromFile(0x0B6E58, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "dawnstar"
        Return Game.GetFormFromFile(0x0B6E49, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "nightgate_inn"
        Return Game.GetFormFromFile(0x0B6E59, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "heljarchen_hall"
        Return Game.GetFormFromFile(0x0CB328, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "morthal"
        Return Game.GetFormFromFile(0x0B6E4A, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "stonehills"
        Return Game.GetFormFromFile(0x0B6E5A, "CFTO.esp") as ObjectReference
    ElseIf destinationId == "winstad_manor"
        Return Game.GetFormFromFile(0x0CB327, "CFTO.esp") as ObjectReference
    EndIf
    Return None
EndFunction

Function ExecuteDirectCarriageTravel(ObjectReference destinationMarker)
    ImageSpaceModifier fadeOut = Game.GetFormFromFile(0x0F756D, "Skyrim.esm") as ImageSpaceModifier
    ImageSpaceModifier fadeHold = Game.GetFormFromFile(0x0F756E, "Skyrim.esm") as ImageSpaceModifier
    ImageSpaceModifier fadeBack = Game.GetFormFromFile(0x0F756F, "Skyrim.esm") as ImageSpaceModifier

    If fadeOut
        fadeOut.Apply()
        Utility.Wait(2.0)
        If fadeHold
            fadeOut.PopTo(fadeHold)
        EndIf
    EndIf

    ; CFTO and the proven ferry modules temporarily lift encumbrance so the
    ; engine's fast-travel call still works for an overloaded passenger.
    Float carryWeight = PlayerRef.GetActorValue("CarryWeight")
    Float inventoryWeight = PlayerRef.GetActorValue("InventoryWeight")
    Float deltaWeight = (inventoryWeight + 1.0) - carryWeight
    If deltaWeight > 0.0
        PlayerRef.ModActorValue("CarryWeight", deltaWeight)
    EndIf

    Bool UsedApparition = DNT_TravelCompatibility.Travel(PlayerRef, destinationMarker)
    Debug.Trace("[DNT] CARRIAGE_TRAVEL_MODE apparition=" + UsedApparition)

    If fadeHold
        If fadeBack
            fadeHold.PopTo(fadeBack)
        EndIf
        fadeHold.Remove()
    EndIf
    If deltaWeight > 0.0
        PlayerRef.ModActorValue("CarryWeight", -deltaWeight)
    EndIf
EndFunction

Bool Function CommitDestination(String destinationId, Actor speaker, Int cftoDestination = 0)
    Return CommitDestinationFromOrigin(destinationId, speaker, OriginId, cftoDestination)
EndFunction

Bool Function CommitDestinationFromOrigin(String destinationId, Actor speaker, String sourceOriginId, Int cftoDestination = 0)
    If !speaker
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + sourceOriginId + " reason=speaker_none", 2)
        Return False
    EndIf

    Bool freeRide = KmodCarriageFreeFaction && speaker.IsInFaction(KmodCarriageFreeFaction)
    Int fare = DNT_ParchmentNative.GetCarriageFare(sourceOriginId, destinationId, freeRide)
    Float hours = DNT_ParchmentNative.GetCarriageHours(sourceOriginId, destinationId)
    If fare < 0 || hours < 0.0
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + sourceOriginId + " destination=" + destinationId + " reason=native_quote", 2)
        Debug.Notification("Carriage travel to that destination is unavailable.")
        Return False
    EndIf

    ObjectReference destinationMarker = GetCarriageDestinationMarker(destinationId)
    If !destinationMarker
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + sourceOriginId + " destination=" + destinationId + " reason=destination_marker", 2)
        Debug.Notification("Carriage travel to that destination is unavailable.")
        Return False
    EndIf

    If !freeRide && PlayerRef.GetItemCount(Gold001) < fare
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + sourceOriginId + " destination=" + destinationId + " reason=gold fare=" + fare)
        Debug.Notification("You do not have enough gold.")
        Return False
    EndIf

    If !freeRide
        PlayerRef.RemoveItem(Gold001, fare, True, None)
        Sound paymentSound = Game.GetFormFromFile(0x0334AB, "Skyrim.esm") as Sound
        If paymentSound
            paymentSound.PlayAndWait(PlayerRef)
        EndIf
    EndIf

    KmodCarriageDestination.SetValueInt(0)
    Debug.Trace("[DNT] PURCHASE_COMMITTED origin=" + sourceOriginId + " destination=" + destinationId + " fare=" + fare + " free=" + freeRide + " cfto_destination=" + cftoDestination + " execution=direct speaker=" + speaker)
    ExecuteDirectCarriageTravel(destinationMarker)
    Debug.Trace("[DNT] CARRIAGE_TRAVEL_COMPLETE origin=" + sourceOriginId + " destination=" + destinationId + " fare=" + fare + " free=" + freeRide + " marker=" + destinationMarker)
    Return True
EndFunction

Bool Function PurchaseDestination(String destinationId, Actor speaker)
    ; The parchment picker already returns a validated native-catalogue ID.
    ; Do not route it back through the legacy dialogue manifest/index layer.
    Return CommitDestination(destinationId, speaker)
EndFunction
