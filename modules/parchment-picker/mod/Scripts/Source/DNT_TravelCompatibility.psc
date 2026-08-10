Scriptname DNT_TravelCompatibility Hidden

Bool Function IsApparitionTravelActive(Actor PlayerRef) Global
    If PlayerRef == None
        Return False
    EndIf

    MagicEffect ApparitionHolder = Game.GetFormFromFile(0x000808, "WizardingTraversal.esl") as MagicEffect
    Bool HasHolder = ApparitionHolder != None && PlayerRef.HasMagicEffect(ApparitionHolder)
    Float TravelSpeed = Game.GetGameSettingFloat("fFastTravelSpeedMult")
    Bool HasSpeedOverride = TravelSpeed >= 99999.0
    Bool IsActive = HasHolder || HasSpeedOverride
    Debug.Trace("[DNT] APPARITION_CHECK holder=" + ApparitionHolder + " hasHolder=" + HasHolder + " speed=" + TravelSpeed + " active=" + IsActive)
    Return IsActive
EndFunction

; Returns True when the zero-time Apparition path was used. Normal services
; retain Game.FastTravel and therefore their established time passage.
Bool Function Travel(Actor PlayerRef, ObjectReference DestinationMarker) Global
    If PlayerRef == None || DestinationMarker == None
        Return False
    EndIf

    If IsApparitionTravelActive(PlayerRef)
        Debug.Trace("[DNT] TRAVEL_COMPAT mode=apparition plugin=WizardingTraversal.esl")
        PlayerRef.MoveTo(DestinationMarker)
        Return True
    EndIf

    Debug.Trace("[DNT] TRAVEL_COMPAT mode=fast_travel")
    Game.FastTravel(DestinationMarker)
    Return False
EndFunction
