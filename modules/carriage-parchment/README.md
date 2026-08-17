# Carriage parchment adapter

This module is a thin UI adapter over the existing carriage alpha. It does not
calculate routes, charge gold, or execute travel itself.

The beta sheet exposes all 27 destinations with a native CFTO handoff: the nine
hold capitals, fifteen minor Skyrim stops, and three HearthFires homesteads. A
single batched refresh evaluates the matched `DNT_OriginService` against live
hazard state; the adapter then reads the cached fare and time and draws only
currently available destinations. Selection returns a stable destination ID to
`DNT_TravelCoordinator.Purchase`, which revalidates the quote, resolves CFTO's
ground-level arrival reference, charges only after that resolution succeeds,
and immediately calls `Game.FastTravel`. The beta no longer arms CFTO's driver
or waits for a carriage-seat link; clicking the marker is the travel action.

The beta deliberately has no variable route or route-segment presentation. It
does not draw straight spokes or imply a road path that CFTO does not expose.
Carriage stops use exact NORDIC UI discovered-map symbols under outobugi's
published open-art permission. Capitals retain their unique NORDIC UI capital
symbols; smaller stops use NORDIC UI's Town, Settlement, Wood Mill, Mine, or
Farm symbol according to destination type. The assets were extracted from the
installed downstream Norden UI SWF, and their legacy `norden-*` runtime names
remain unchanged for compatibility. Helgen and Granite Hill remain omitted because the
installed CFTO plugin has no native executable handoff for them.

The ordinary CFTO-derived destination dialogue remains the fallback.

No BCD integration is required. The module reuses the generic native parchment
runtime and references the same external Skyrim Paper Map/FWMF
`textures/terrain/tamriel/skyrim.dds` illustration used by the wizard provider.
The carriage sheet defaults to NORDIC UI destination symbols and the exact
Norden UI round-trip loading symbol as its selection ring. No background map
artwork is packaged.
