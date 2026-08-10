Diegetic Travel - carriage parchment, 27-stop CFTO beta sheet

Requires:
- DiegeticTravel.esp carriage alpha and its JContainers runtime data
- Carriage and Ferry Travel Overhaul / CFTO.esp
- Diegetic Travel Parchment Picker runtime
- Skyrim Paper Map by Caro Tuts for FWMF, supplying
  textures/terrain/tamriel/skyrim.dds

The adapter draws every currently available destination with a native CFTO
handoff: nine hold capitals, fifteen minor Skyrim stops, and three HearthFires
homesteads. Fare and travel time come from one batched live hazard-aware quote
refresh. Selection returns the stable destination ID to DNT_TravelCoordinator,
which revalidates payment and performs the existing CFTO carriage handoff.

The beta does not draw route segments or synthetic straight-line spokes.
Destinations default to exact Norden UI discovered-map symbols; the exact
Norden round-trip loading symbol marks the current selection. Skyrim-derived
hold/town symbols remain packaged as offline fallback assets.

The original destination dialogue remains the fallback. This package contains
no map artwork, voice audio, BCD records, or BCD assets.
