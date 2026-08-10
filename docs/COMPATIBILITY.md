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
reaches CFTO's normal destination topics. Diegetic Travel currently owns a
separate parchment handoff with flat destination gates and CFTO-tier fares.
With the BCD CFTO patch enabled, that handoff is bypassed.

For alpha testing:

- Keep the base BCD mod and its CFTO patch disabled unless separately verifying
  conflicts.
- Load `DiegeticTravel.esp` after `CFTO.esp`.

A proper integration should reuse BCD only as the selection surface:

1. Diegetic Travel builds a marker whitelist from the current driver's flat
   destination set and live gates.
2. BCD opens the map with that whitelist.
3. The selected marker is translated back to a Diegetic Travel destination ID.
4. Diegetic Travel revalidates availability, uses CFTO's current fare tier,
   then performs its normal direct travel handoff.

That design preserves BCD's polished map UI without duplicating service logic.
It requires a deliberate compatibility patch or a small BCD API
extension; merely changing load order is not sufficient.

### Wizard-guide adapter

The optional `DiegeticTravelWizardMap.esp` implements that selection-only
boundary for the wizard network without changing BCD itself. It calls the
native `BCD_Utils.OpenTheMap` function with a five-city whitelist, receives the
selected marker through `BCD_SetDestination`, translates it to a stable wizard
destination ID, and delegates fare and movement to `DNT_WizardTravelService`.

The adapter deliberately remains a separate plugin with hard masters on BCD
and `DiegeticTravelWizardGuides.esp`. The core wizard plugin and its dialogue
list therefore remain usable when the adapter is removed. The adapter has now
passed its monitored 32:9 checks: map open/cancel, core fare denial, funded
travel, and the dialogue-list fallback. The parchment picker is the preferred
in-world surface; BCD remains a proven optional adapter and comparison point.

## Wizarding Traversal: Apparition Travel

`WizardingTraversal.esl` is an optional, soft-detected compatibility target.
When its Apparition holder effect (local FormID `000808`) is active—or its own
`fFastTravelSpeedMult=100000` override is present—Diegetic Travel completes
direct carriage, wizard, and ferry trips with `MoveTo` instead of
`Game.FastTravel`. The normal provider fare, state
validation, fade, arrival marker, and companion handoff still apply, but no
travel time passes.

This deliberately does not mutate Wizarding Traversal's game setting. The
original plugin is not a master and is not required: compatibility is soft
detected, and an absent holder/override falls through to normal time-passing
fast travel. The Baan Malur adapter remains
an exception because it delegates movement to that source mod's quest stages.
