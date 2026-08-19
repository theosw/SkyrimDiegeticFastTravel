Scriptname DNT_OriginService extends Quest

GlobalVariable Property KmodCarriageDestination Auto
Faction Property KmodCarriageFreeFaction Auto
Actor Property PlayerRef Auto
MiscObject Property Gold001 Auto

String Property OriginId Auto

Bool Function IsFreeRideForSpeaker(Actor speaker)
    Return KmodCarriageFreeFaction && speaker && speaker.IsInFaction(KmodCarriageFreeFaction)
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

Bool Function CommitDestinationFromOrigin(String destinationId, Actor speaker, String sourceOriginId, Int cftoDestination = 0)
    If !speaker
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + sourceOriginId + " reason=speaker_none", 2)
        Return False
    EndIf

    Bool freeRide = KmodCarriageFreeFaction && speaker.IsInFaction(KmodCarriageFreeFaction)
    Int fare = DNT_ParchmentNative.GetCarriageFare(sourceOriginId, destinationId, freeRide)
    If fare < 0
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + sourceOriginId + " destination=" + destinationId + " reason=native_quote", 2)
        Debug.Notification("Carriage travel to that destination is unavailable.")
        Return False
    EndIf

    ObjectReference destinationMarker = DNT_ParchmentNative.ResolveCarriageDestinationMarker(destinationId)
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
