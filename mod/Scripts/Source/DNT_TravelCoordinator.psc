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

Bool Function Purchase(String destinationId, ObjectReference speakerRef)
    DNT_OriginService service = GetOriginService(speakerRef as Actor)
    If !service
        Return False
    EndIf
    Return service.PurchaseDestination(destinationId, speakerRef as Actor)
EndFunction
