Scriptname DNT_WizardTravelFragment extends TopicInfo Hidden

DNT_WizardTravelService Property Service Auto
String Property DestinationId Auto

Function Fragment_0(ObjectReference akSpeakerRef)
    Service.RequestTravel(DestinationId, akSpeakerRef)
EndFunction
