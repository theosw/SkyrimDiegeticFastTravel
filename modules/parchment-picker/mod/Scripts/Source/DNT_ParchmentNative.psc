Scriptname DNT_ParchmentNative Hidden

Bool Function IsAvailable() Global Native

Bool Function BeginRequest(String RequestId, String ProviderId, ObjectReference SourceRef, String TexturePath, Float ArtAspectRatio, Float TextureUvMinX, Float TextureUvMinY, Float TextureUvMaxX, Float TextureUvMaxY) Global Native

Bool Function SetRouteOrigin(String RequestId, Float NormalizedX, Float NormalizedY) Global Native

Bool Function AddDestination(String RequestId, String DestinationId, String Label, Int Fare, Float NormalizedX, Float NormalizedY) Global Native

Bool Function Show(String RequestId) Global Native

Bool Function Cancel(String RequestId) Global Native
