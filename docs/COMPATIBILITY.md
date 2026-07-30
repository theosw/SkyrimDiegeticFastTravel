# Compatibility

## Better Carriage Destinations

Better Carriage Destinations (BCD) is a strong candidate for a future map-based
front end, but its CFTO patch is not functionally compatible with this alpha.

BCD's native plugin closes the dialogue menu, opens the map, and optionally
filters its marker collection using a whitelist or blocklist. Its injected
Scaleform dims blocked markers and emits `BCD_SetDestination` only for a valid
selection. Those mechanics are useful and do not inspect CFTO's destination
INFO records themselves:

- [`OpenTheMap` and marker filtering](https://github.com/shazdeh/Better-Carriage-Destinations/blob/136dc7b3ad9754877c485fd5cea29550af108888/src/plugin.cpp#L35-L82)
- [`OpenTheMap` menu transition](https://github.com/shazdeh/Better-Carriage-Destinations/blob/136dc7b3ad9754877c485fd5cea29550af108888/src/plugin.cpp#L201-L212)
- [`BCD_SetDestination` selection event](https://github.com/shazdeh/Better-Carriage-Destinations/blob/136dc7b3ad9754877c485fd5cea29550af108888/Fla/BetterCarriageDestinations.as#L69-L75)

The installed BCD dialogue fragment calls its quest's `OpenMap` directly. Its
CFTO ferry patch chooses a driver-faction-specific whitelist before doing the
same. Consequently, BCD's CFTO dialogue entry opens the map before the player
reaches CFTO's normal destination topics. Diegetic Travel currently overrides
those topics to publish and enforce road availability, graph-derived fare, and
quoted hours. With the BCD CFTO patch enabled, that work is bypassed.

For alpha testing:

- Keep the base BCD mod and its CFTO patch disabled unless separately verifying
  conflicts.
- Load `DiegeticTravel.esp` after `CFTO.esp`.

A proper integration should reuse BCD only as the selection surface:

1. Diegetic Travel evaluates routes for the current driver and builds a marker
   whitelist from reachable destinations.
2. BCD opens the map with that whitelist.
3. The selected marker is translated back to a Diegetic Travel destination ID.
4. Diegetic Travel re-evaluates the route, uses its graph fare and hours rather
   than BCD's straight-line price, then performs the existing CFTO handoff.

That design preserves BCD's polished map UI without surrendering the road and
hazard model. It requires a deliberate compatibility patch or a small BCD API
extension; merely changing load order is not sufficient.
