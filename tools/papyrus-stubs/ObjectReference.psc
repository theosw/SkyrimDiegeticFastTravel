; Minimal compile-time header for environments without Creation Kit sources.
Scriptname ObjectReference extends Form Hidden

Form Function GetBaseObject() Native
Bool Function IsDisabled() Native
Function RegisterForSingleUpdate(Float seconds) Native
Function MoveTo(ObjectReference target, Float xOffset = 0.0, Float yOffset = 0.0, Float zOffset = 0.0, Bool matchRotation = True) Native
