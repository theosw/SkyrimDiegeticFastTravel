Scriptname DNT_SelectDestination extends TopicInfo Hidden

DNT_TravelCoordinator Property Coordinator Auto
String Property DestinationId Auto

Function Fragment_0(ObjectReference akSpeakerRef)
    Coordinator.Purchase(DestinationId, akSpeakerRef)
EndFunction
