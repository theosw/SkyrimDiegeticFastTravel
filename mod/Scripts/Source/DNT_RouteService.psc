Scriptname DNT_RouteService extends Quest

Quest Property CW01A Auto
Quest Property CW01B Auto
Quest Property CWResolution01 Auto

String Property RuntimePath = "Data/SKSE/Plugins/DiegeticTravel/runtime.json" Auto

Int _runtime
Int _lastFare = -1
Float _lastHours = 0.0

Event OnInit()
    LoadRuntime()
EndEvent

Bool Function LoadRuntime()
    If _runtime != 0
        JValue.release(_runtime)
        _runtime = 0
    EndIf

    _runtime = JValue.readFromFile(RuntimePath)
    If _runtime == 0
        Debug.Trace("[DNT] Could not load runtime data: " + RuntimePath, 2)
        Return False
    EndIf

    JValue.retain(_runtime)
    Return True
EndFunction

Bool Function EnsureRuntime()
    If _runtime != 0
        Return True
    EndIf
    Return LoadRuntime()
EndFunction

Int Function GetWarStage()
    If CWResolution01 && CWResolution01.IsCompleted()
        Return 3
    EndIf
    If (CW01A && CW01A.IsCompleted()) || (CW01B && CW01B.IsCompleted())
        Return 2
    EndIf
    Return 1
EndFunction

Int Function GetWarMultiplier(Int rules)
    Int multipliers = JMap.getObj(rules, "war_multiplier")
    Int stage = GetWarStage()
    If stage == 3
        Return JMap.getInt(multipliers, "resolved", 1)
    ElseIf stage == 2
        Return JMap.getInt(multipliers, "active", 3)
    EndIf
    Return JMap.getInt(multipliers, "early", 2)
EndFunction

; 0=dormant, 1=active, 2=cleared, 3=unknown.
Int Function GetHazardPhase(Int hazard)
    String hazardClass = JMap.getStr(hazard, "class")
    If hazardClass == "giant_camp"
        Return 1
    EndIf

    Location hazardLocation = JMap.getForm(hazard, "location") as Location
    If hazardLocation && hazardLocation.IsCleared()
        Return 2
    EndIf

    If hazardClass == "cw_fort" && GetWarStage() == 3
        Return 2
    EndIf

    If hazardClass == "dragon_mound"
        ObjectReference activationRef = JMap.getForm(hazard, "activation_ref") as ObjectReference
        If !activationRef
            Return 3
        EndIf
        If JMap.getInt(hazard, "clears_on_death", 0) == 1
            Actor dragon = activationRef as Actor
            If dragon && dragon.IsDead()
                Return 2
            EndIf
        EndIf
        If activationRef.IsDisabled()
            Return 0
        EndIf
        If !hazardLocation
            Return 3
        EndIf
        Return 1
    EndIf

    If !hazardLocation
        Return 3
    EndIf
    Return 1
EndFunction

Bool Function IsDestinationAvailable(String destinationId)
    If !EnsureRuntime()
        Return False
    EndIf

    Int nodes = JMap.getObj(_runtime, "nodes")
    Int node = JMap.getObj(nodes, destinationId)
    If node == 0
        Return False
    EndIf

    String condition = JMap.getStr(node, "condition")
    If condition == ""
        Return True
    EndIf

    ; The generated beta exposes only marker-gated Hearthfire endpoints.
    ObjectReference marker = JMap.getForm(node, "marker") as ObjectReference
    Return marker && !marker.IsDisabled()
EndFunction

Bool Function QuoteCarriageRoute(String routeId)
    _lastFare = -1
    _lastHours = 0.0
    If !EnsureRuntime()
        Return False
    EndIf

    Int rules = JMap.getObj(_runtime, "rules")
    Int providers = JMap.getObj(_runtime, "providers")
    Int carriage = JMap.getObj(providers, "carriage")
    Int routes = JMap.getObj(carriage, "routes")
    Int route = JMap.getObj(routes, routeId)
    If route == 0
        Return False
    EndIf

    Int allHazards = JMap.getObj(_runtime, "hazards")
    Int candidates = JMap.getObj(route, "candidates")
    Int baseCost = JMap.getInt(rules, "base_cost", 50)
    Int hazardCost = JMap.getInt(rules, "hazard_cost", 100)
    Int refuseMultiplier = JMap.getInt(rules, "refuse_multiplier", 2)
    Int warMultiplier = GetWarMultiplier(rules)

    Int candidateIndex = 0
    Int candidateCount = JArray.count(candidates)
    While candidateIndex < candidateCount
        Int candidate = JArray.getObj(candidates, candidateIndex)
        Int fare = (JMap.getFlt(candidate, "base_units") * baseCost * warMultiplier) as Int
        Float hours = JMap.getFlt(candidate, "hours")
        Int candidateHazards = JMap.getObj(candidate, "hazards")
        Int hazardIndex = 0
        Int hazardCount = JArray.count(candidateHazards)
        Bool blocked = False

        While hazardIndex < hazardCount && !blocked
            String hazardId = JArray.getStr(candidateHazards, hazardIndex)
            Int hazard = JMap.getObj(allHazards, hazardId)
            Int phase = GetHazardPhase(hazard)

            ; Unknown is conservative: price it as active and let chokepoints refuse.
            If phase == 1 || phase == 3
                Int multiplier = JMap.getInt(hazard, "mult", 1)
                If JMap.getStr(hazard, "role") == "chokepoint" && multiplier >= refuseMultiplier
                    blocked = True
                Else
                    fare += hazardCost * multiplier
                EndIf
            EndIf
            hazardIndex += 1
        EndWhile

        If !blocked && (_lastFare < 0 || fare < _lastFare || (fare == _lastFare && hours < _lastHours))
            _lastFare = fare
            _lastHours = hours
        EndIf
        candidateIndex += 1
    EndWhile

    Return _lastFare >= 0
EndFunction

Int Function GetLastFare()
    Return _lastFare
EndFunction

Float Function GetLastHours()
    Return _lastHours
EndFunction
