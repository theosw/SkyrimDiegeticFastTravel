Scriptname DNT_ParchmentNative Hidden

Bool Function IsAvailable() Global Native
Float Function GetMonotonicSeconds() Global Native
Int Function BuildCarriageRequest(String RequestId, String OriginId, ObjectReference SourceRef, Bool FreeRide) Global Native
String Function ConsumeCarriageSelectionId(String RequestId, Int SelectionIndex) Global Native
Int Function GetCarriageFare(String OriginId, String DestinationId, Bool FreeRide) Global Native
Float Function GetCarriageHours(String OriginId, String DestinationId) Global Native
Int Function GetWizardFare(Int FallbackFare) Global Native
Int Function ResolveFerryFare(String Tier, Int LiveCftoFare) Global Native

Bool Function RequestDialogueClose() Global Native

Bool Function BeginRequest(String RequestId, String ProviderId, ObjectReference SourceRef, String TexturePath, Float ArtAspectRatio, Float TextureUvMinX, Float TextureUvMinY, Float TextureUvMaxX, Float TextureUvMaxY) Global Native

Bool Function SetSourceLabel(String RequestId, String SourceLabel) Global Native
Bool Function SetPaymentLabelPosition(String RequestId, Float NormalizedX, Float NormalizedY) Global Native

Bool Function SetMarkerTextures(String RequestId, String IdleTexturePath, String SelectedTexturePath) Global Native

Bool Function SetOriginMarkerTexture(String RequestId, String TexturePath) Global Native
Bool Function SetSelectionRingTexture(String RequestId, String TexturePath) Global Native
Bool Function SetSelectionRingScale(String RequestId, Float Scale) Global Native

Bool Function SetRouteOrigin(String RequestId, Float NormalizedX, Float NormalizedY) Global Native

Bool Function AddRouteLandmark(String RequestId, Float NormalizedX, Float NormalizedY) Global Native

Bool Function AddDestination(String RequestId, String DestinationId, String Label, Int Fare, Float NormalizedX, Float NormalizedY) Global Native
Bool Function SetDestinationMarkerTexture(String RequestId, String DestinationId, String TexturePath) Global Native
Bool Function SetDestinationMarkerScale(String RequestId, String DestinationId, Float Scale) Global Native
Bool Function SetDestinationSelectionRingStyle(String RequestId, String DestinationId, Float OffsetX, Float OffsetY, Float Scale) Global Native
Bool Function SetDestinationSelectionRingTexture(String RequestId, String DestinationId, String TexturePath) Global Native

Bool Function Show(String RequestId) Global Native

Bool Function Cancel(String RequestId) Global Native

Float Function PlayPresentation(ObjectReference SpeakerRef, String VoicePath, String SubtitleText, Float VoiceDurationSeconds) Global Native
