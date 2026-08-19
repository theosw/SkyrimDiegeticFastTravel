Diegetic Travel - carriage parchment development module

The release build consolidates this module into DiegeticTravel.esp. It uses
CFTO's nine carriage drivers, 28 destination markers, fare globals, and
Hearthfire gates. The native parchment runtime builds the visible destination
request; Papyrus only closes dialogue, purchases the selected stable ID, and
performs the final world mutation.

This module has no JContainers, route graph, cached quote, generated hours, or
standalone runtime-data dependency.
