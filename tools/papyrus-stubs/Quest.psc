; Minimal compile-time header for environments without Creation Kit sources.
Scriptname Quest extends Form Hidden

Bool Function IsCompleted() Native
Bool Function UpdateCurrentInstanceGlobal(GlobalVariable value) Native
Alias Function GetAlias(Int index) Native
Bool Function SetCurrentStageID(Int aiStage) Native

Bool Function SetStage(Int aiStage)
    Return SetCurrentStageID(aiStage)
EndFunction
