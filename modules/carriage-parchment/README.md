# Carriage parchment adapter

This module is a thin Papyrus/UI adapter over the native flat carriage
catalogue. It does not own a route graph, calculate road paths, or keep a second
fare table.

The beta sheet exposes all 28 destinations with a native CFTO handoff: the nine
hold capitals, fifteen minor Skyrim stops, three HearthFires homesteads, and the
destination-only Thalmor Embassy stop. A
single native request resolves the origin, evaluates live availability, quotes
each direct trip from the configured distance policy, and draws only available
destinations. Selection returns a stable destination ID to
`DNT_TravelCoordinator.PurchaseFromOrigin`, which asks the same native catalogue
to revalidate the quote and resolve CFTO's ground-level arrival reference,
charges only after that resolution succeeds, and immediately travels. The beta
no longer arms CFTO's driver or waits for a carriage-seat link; clicking the
marker is the travel action.

The public carriage defaults are 475 gold per normalized map unit, a 50-gold
minimum, and 50-gold rounding. This produces a 50–400-gold fare envelope from
the nine physical drivers. Approximate hours and all carriage pricing controls
are read once from `SKSE/Plugins/DiegeticTravel.ini` at game startup.

The beta deliberately has no variable route or route-segment presentation. It
does not draw straight spokes or imply a road path that CFTO does not expose.
Carriage stops use exact NORDIC UI discovered-map symbols under outobugi's
published open-art permission. Capitals retain their unique NORDIC UI capital
symbols; smaller stops use NORDIC UI's Town, Settlement, Wood Mill, Mine, or
Farm symbol according to destination type. The assets were extracted from the
installed downstream Norden UI SWF, and their legacy `norden-*` runtime names
remain unchanged for compatibility. Helgen and Granite Hill remain omitted because the
installed CFTO plugin has no native executable handoff for them.

The ordinary CFTO-derived destination dialogue is retained behind the
default-off diagnostic compatibility global; it is not a parallel public fare
path.

The carriage module itself has no BCD master or runtime dependency. LoreRim's
BCD adapters intercept the same dialogue and therefore require the separate
coexistence ESL to leave this parchment authoritative while BCD stays loaded.
The module reuses the generic native parchment runtime and references the same
external Skyrim Paper Map/FWMF
`textures/terrain/tamriel/skyrim.dds` illustration used by the wizard provider.
The carriage sheet defaults to NORDIC UI destination symbols and the exact
Norden UI round-trip loading symbol as its selection ring. No background map
artwork is packaged.
