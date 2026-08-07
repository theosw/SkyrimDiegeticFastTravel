Scriptname DNT_ParchmentNative Hidden

Bool Function IsAvailable() Global Native

Bool Function RequestDialogueClose() Global Native

Bool Function BeginRequest(String RequestId, String ProviderId, ObjectReference SourceRef, String TexturePath, Float ArtAspectRatio, Float TextureUvMinX, Float TextureUvMinY, Float TextureUvMaxX, Float TextureUvMaxY) Global Native

Bool Function SetSourceLabel(String RequestId, String SourceLabel) Global Native
Bool Function SetPaymentLabelPosition(String RequestId, Float NormalizedX, Float NormalizedY) Global Native

Bool Function SetOverlayTexture(String RequestId, String TexturePath) Global Native

Bool Function SetMarkerTextures(String RequestId, String IdleTexturePath, String SelectedTexturePath) Global Native

Bool Function SetOriginMarkerTexture(String RequestId, String TexturePath) Global Native

Bool Function SetRouteOrigin(String RequestId, Float NormalizedX, Float NormalizedY) Global Native

Bool Function AddRouteSegment(String RequestId, Float StartNormalizedX, Float StartNormalizedY, Float EndNormalizedX, Float EndNormalizedY) Global Native

Bool Function AddRouteLandmark(String RequestId, Float NormalizedX, Float NormalizedY) Global Native

Bool Function AddDestination(String RequestId, String DestinationId, String Label, Int Fare, Float NormalizedX, Float NormalizedY) Global Native

Bool Function SetDestinationMarkerTexture(String RequestId, String DestinationId, String TexturePath) Global Native

Bool Function Show(String RequestId) Global Native

Bool Function Cancel(String RequestId) Global Native

Float Function PlayPresentation(ObjectReference SpeakerRef, String VoicePath, String SubtitleText, Float VoiceDurationSeconds) Global Native

; Backward-compatible wrapper for the gameplay-proven Mirabelle probe.
Bool Function PlayVoiceProbe(ObjectReference SpeakerRef, String VoicePath) Global Native
