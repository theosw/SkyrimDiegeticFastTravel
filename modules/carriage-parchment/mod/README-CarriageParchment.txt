Diegetic Travel - carriage parchment, 27-stop CFTO beta sheet

Requires:
- DiegeticTravel.esp carriage alpha and its JContainers runtime data
- Carriage and Ferry Travel Overhaul / CFTO.esp
- Diegetic Travel Parchment Picker runtime
- the existing battlemap01.dds supplied by the configured map artwork mod

The adapter draws every currently available destination with a native CFTO
handoff: nine hold capitals, fifteen minor Skyrim stops, and three HearthFires
homesteads. Fare and travel time come from one batched live hazard-aware quote
refresh. Selection returns the stable destination ID to DNT_TravelCoordinator,
which revalidates payment and performs the existing CFTO carriage handoff.

The beta does not draw route segments or synthetic straight-line spokes. Hold
capitals use vanilla hold icons; minor destinations use the vanilla town icon
provided by the shared parchment-picker package.

The original destination dialogue remains the fallback. This package contains
no map artwork, voice audio, BCD records, or BCD assets.
