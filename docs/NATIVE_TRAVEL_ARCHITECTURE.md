# Native travel architecture

## Purpose

The native layer removes catalogue lookup, quote calculation, request assembly,
and menu interaction from the Papyrus hot path. Papyrus remains responsible for
gold mutation and movement because those operations are small and easy to
validate in game.

## Catalogue contract

`travel_catalog.tsv` contains one schema row, one carriage policy, 28 stable
locations, and optional direct overrides. A location supplies its stable ID,
display name, normalized map position, plugin-local arrival FormID, and open,
one-way, or quest-locked availability class.

The estimator performs a direct distance calculation plus the provider policy
and optional override. It has no graph search, road edges, hazards, wars,
candidate paths, or variable-rate layer.

## Menu request flow

1. Papyrus resolves the speaking CFTO driver to an origin service.
2. Native code begins one carriage request and enumerates the loaded catalogue.
3. Native code filters live availability, estimates each quote, and adds styled
   destinations directly to the menu.
4. The menu returns an index; native request state translates it back to the
   stable destination ID and is immediately discarded.
5. Papyrus re-queries the authoritative native quote and asks native code for
   the marker from that same catalogue entry. It then charges the player and
   travels. Papyrus contains no duplicate destination/FormID registry.

The request map is protected by a mutex and erased on selection/cancel. No
quote or selection data is persisted into the save.

## Apparition

Wizarding Traversal is soft-detected. Its live
`fFastTravelSpeedMult >= 99999` override is the authoritative enabled signal.
The holder magic effect is logged only for diagnostics because it can remain on
the actor after Apparition is toggled off. Active Apparition uses `MoveTo` and
passes no time; otherwise providers retain `Game.FastTravel`.

## Diagnostics

The supported native events are `TRAVEL_CATALOG_READY`,
`TRAVEL_CATALOG_REJECT`, `CARRIAGE_NATIVE_REQUEST_READY`, request rejection
events, and parchment timing/input events. The former observe-only
`TRAVEL_SHADOW_*` comparison path and Mirabelle voice probe were removed.
