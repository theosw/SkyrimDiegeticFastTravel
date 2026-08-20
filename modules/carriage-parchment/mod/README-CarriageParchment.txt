Diegetic Travel - carriage parchment development module

The release build consolidates this module into DiegeticTravel.esp. It uses
CFTO's nine carriage drivers, 28 destination markers, and Hearthfire gates. The
native parchment runtime owns destination availability, configurable
direct-distance fare/hour quotes, and marker resolution; Papyrus only closes
dialogue, revalidates and purchases the selected stable ID, and performs the
final world mutation. Ferries—not carriages—continue to use CFTO's live fare
globals by default.

This module has no JContainers, route graph, cached quote, generated globals,
or standalone Papyrus runtime-data dependency.
