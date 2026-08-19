Scriptname DNT_TravelCoordinator extends Quest

Form Property DawnstarDriver Auto
DNT_OriginService Property DawnstarService Auto
Form Property FalkreathDriver Auto
DNT_OriginService Property FalkreathService Auto
Form Property MarkarthDriver Auto
DNT_OriginService Property MarkarthService Auto
Form Property MorthalDriver Auto
DNT_OriginService Property MorthalService Auto
Form Property RiftenDriver Auto
DNT_OriginService Property RiftenService Auto
Form Property SolitudeDriver Auto
DNT_OriginService Property SolitudeService Auto
Form Property WhiterunDriver Auto
DNT_OriginService Property WhiterunService Auto
Form Property WindhelmDriver Auto
DNT_OriginService Property WindhelmService Auto
Form Property WinterholdDriver Auto
DNT_OriginService Property WinterholdService Auto

DNT_OriginService Function GetOriginService(Actor speaker, Bool traceFailure = True)
    If !speaker
        If traceFailure
            Debug.Trace("[DNT] ORIGIN_LOOKUP_FAILED reason=speaker_none", 2)
        EndIf
        Return None
    EndIf

    Form speakerBase = speaker.GetBaseObject()
    If DawnstarDriver == speaker || DawnstarDriver == speakerBase
        Return DawnstarService
    ElseIf FalkreathDriver == speaker || FalkreathDriver == speakerBase
        Return FalkreathService
    ElseIf MarkarthDriver == speaker || MarkarthDriver == speakerBase
        Return MarkarthService
    ElseIf MorthalDriver == speaker || MorthalDriver == speakerBase
        Return MorthalService
    ElseIf RiftenDriver == speaker || RiftenDriver == speakerBase
        Return RiftenService
    ElseIf SolitudeDriver == speaker || SolitudeDriver == speakerBase
        Return SolitudeService
    ElseIf WhiterunDriver == speaker || WhiterunDriver == speakerBase
        Return WhiterunService
    ElseIf WindhelmDriver == speaker || WindhelmDriver == speakerBase
        Return WindhelmService
    ElseIf WinterholdDriver == speaker || WinterholdDriver == speakerBase
        Return WinterholdService
    EndIf

    If traceFailure
        Debug.Trace("[DNT] ORIGIN_LOOKUP_FAILED reason=unconfigured speaker=" + speaker + " base=" + speakerBase, 2)
    EndIf
    Return None
EndFunction

Bool Function IsWciInnDriver(Actor speaker)
    If !speaker
        Return False
    EndIf

    Form speakerBase = speaker.GetBaseObject()
    Return speakerBase == Game.GetFormFromFile(0x000846, "WaitCarriageInns.esp") || speakerBase == Game.GetFormFromFile(0x000848, "WaitCarriageInns.esp") || speakerBase == Game.GetFormFromFile(0x000849, "WaitCarriageInns.esp") || speakerBase == Game.GetFormFromFile(0x00084A, "WaitCarriageInns.esp")
EndFunction

String Function GetWciInnOrigin(Actor speaker)
    If !IsWciInnDriver(speaker)
        Return ""
    EndIf

    Location currentLocation = Game.GetPlayer().GetCurrentLocation()
    If currentLocation == Game.GetFormFromFile(0x01CB8C, "Skyrim.esm")
        Return "riverwood"
    ElseIf currentLocation == Game.GetFormFromFile(0x01F7CB, "Skyrim.esm")
        Return "old_hroldan"
    ElseIf currentLocation == Game.GetFormFromFile(0x01F883, "Skyrim.esm")
        Return "rorikstead"
    ElseIf currentLocation == Game.GetFormFromFile(0x020008, "Skyrim.esm")
        Return "dragon_bridge"
    ElseIf currentLocation == Game.GetFormFromFile(0x020054, "Skyrim.esm")
        Return "nightgate_inn"
    ElseIf currentLocation == Game.GetFormFromFile(0x020A02, "Skyrim.esm")
        Return "kynesgrove"
    ElseIf currentLocation == Game.GetFormFromFile(0x0226AA, "Skyrim.esm")
        Return "ivarstead"
    EndIf

    Debug.Trace("[DNT] WCI_ORIGIN_LOOKUP_FAILED speaker=" + speaker + " location=" + currentLocation, 1)
    Return ""
EndFunction

Bool Function IsFreeRideForSpeaker(Actor speaker)
    Return WhiterunService && WhiterunService.IsFreeRideForSpeaker(speaker)
EndFunction

Bool Function PurchaseFromOrigin(String destinationId, ObjectReference speakerRef, String sourceOriginId)
    If sourceOriginId == "" || !WhiterunService
        Debug.Trace("[DNT] PURCHASE_BLOCKED origin=" + sourceOriginId + " reason=shared_service", 2)
        Return False
    EndIf
    Return WhiterunService.CommitDestinationFromOrigin(destinationId, speakerRef as Actor, sourceOriginId)
EndFunction
