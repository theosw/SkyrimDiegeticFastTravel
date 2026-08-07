Scriptname DNT_BaanMalurBoatTravelService extends Quest

String SourcePlugin = "Journey to Baan Malur.esp"

Int RavenRockCaptainForm = 0x0010F3BE
Int BaanMalurCaptainForm = 0x000FFB6B
Int CormarisCaptainForm = 0x0010F414
Int FerryQuestForm = 0x0033708F

Int Fare = 30
Int BaanMalurStage = 1
Int CormarisStage = 2
Int RavenRockStage = 3

Int Function GetFare(String DestinationId)
    If GetDestinationStage(DestinationId) < 0
        Return -1
    EndIf
    Return Fare
EndFunction

String Function GetSourceId(ObjectReference SourceRef)
    If SourceRef == None
        Return ""
    EndIf

    Form SourceBase = SourceRef.GetBaseObject()
    If SourceBase == Game.GetFormFromFile(RavenRockCaptainForm, SourcePlugin)
        Return "raven_rock"
    ElseIf SourceBase == Game.GetFormFromFile(BaanMalurCaptainForm, SourcePlugin)
        Return "baan_malur"
    ElseIf SourceBase == Game.GetFormFromFile(CormarisCaptainForm, SourcePlugin)
        Return "cormaris"
    EndIf
    Return ""
EndFunction

Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef)
    String SourceId = GetSourceId(SourceRef)
    Int DestinationStage = GetDestinationStage(DestinationId)
    If SourceId == ""
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=baan_malur source=" + SourceRef + " destination=" + DestinationId + " reason=invalid_provider", 1)
        Return False
    EndIf
    If DestinationStage < 0
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=baan_malur source=" + SourceId + " destination=" + DestinationId + " reason=unknown_destination", 1)
        Return False
    EndIf
    If SourceId == DestinationId
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=baan_malur source=" + SourceId + " destination=" + DestinationId + " reason=same_stop", 1)
        Return False
    EndIf

    Quest FerryQuest = Game.GetFormFromFile(FerryQuestForm, SourcePlugin) as Quest
    If FerryQuest == None
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=baan_malur source=" + SourceId + " destination=" + DestinationId + " reason=source_quest_missing", 1)
        Debug.Notification("Merchant ferry travel is unavailable.")
        Return False
    EndIf

    GoToState("Travelling")
    Debug.Trace("[DNT] BOAT_TRAVEL_DELEGATE lane=baan_malur source=" + SourceId + " destination=" + DestinationId + " stage=" + DestinationStage)
    FerryQuest.SetStage(DestinationStage)
    Utility.Wait(0.25)
    GoToState("")
    Return True
EndFunction

Int Function GetDestinationStage(String DestinationId)
    If DestinationId == "baan_malur"
        Return BaanMalurStage
    ElseIf DestinationId == "cormaris"
        Return CormarisStage
    ElseIf DestinationId == "raven_rock"
        Return RavenRockStage
    EndIf
    Return -1
EndFunction

State Travelling
    Bool Function RequestTravel(String DestinationId, ObjectReference SourceRef)
        Debug.Trace("[DNT] BOAT_TRAVEL_DENIED lane=baan_malur source=" + SourceRef + " destination=" + DestinationId + " reason=already_travelling", 1)
        Return False
    EndFunction
EndState
