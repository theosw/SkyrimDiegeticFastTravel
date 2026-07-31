Diegetic Travel - Wizard Map Adapter (alpha)

Requirements:
- DiegeticTravelWizardGuides.esp
- Better Carriage Destinations 1.0.10 or compatible
- SKSE and the Better Carriage Destinations DLL/interface assets

This optional adapter adds a second College-faculty dialogue option:
"Can you show me where you can send me? (250 gold per trip)"

The map is restricted to Whiterun, Riften, Solitude, Windhelm, and Markarth.
Selecting a marker is translated to the core wizard service's stable
destination ID. The adapter does not use BCD pricing or BCD travel; the core
service still validates the destination, charges 250 gold, logs the trip, and
moves the player to the proven interior arrival marker.

The original five-choice dialogue menu remains available as a fallback.

This build is statically audited but not yet gameplay-proven. Keep it separate
from the released LoreRim stack and test it only in UltraDiegeticTravel.
