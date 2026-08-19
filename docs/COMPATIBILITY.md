# Compatibility

## Legacy request dialogue

The consolidated release keeps CFTO's original carriage/ferry request INFOs
and the old College destination-list hub as overrides rather than deleting
them. Each is conditioned on `DNT_ShowLegacyTravelDialogue == 1`; the global
defaults to `0`, leaving one parchment-map prompt per provider. Court-wizard
spokes back to the College are not gated because they remain part of the
shipped star topology.

For conflict diagnosis or compatibility-patch development, the original
requests can be restored for the current game with:

```text
set DNT_ShowLegacyTravelDialogue to 1
```

This switch changes only dialogue visibility. It does not change fares,
destination gates, map contents, or the travel implementation.

## Journey to Baan Malur merchant ferries

The optional Baan Malur add-on owns the dialogue boundary for Captain Remyris
and the public Baan Malur and Cormaris captains. Its provider form list hides
Journey's parallel `I would like to hire your ship.` prompt for exactly those
three speakers by default. Journey's native prompt remains available for every
other Journey captain, including ports the parchment add-on has not curated.

For conflict diagnosis, restore the native prompt on the three supported
providers with:

```text
set DNT_ShowBaanMalurNativeDialogue to 1
```

Set it back to `0` for normal release behavior. The switch changes only
dialogue visibility; Journey still owns fares, quest stages, arrival handoffs,
and all native service outside the supported provider list. The gate is made
of record conditions and has no Papyrus runtime cost.

## Wait Carriage in Inns

Wait Carriage in Inns support is part of the consolidated runtime and requires
no compatibility ESP. WCI continues to own its innkeeper request, chair
sequence, temporary driver, and location-change cleanup. Diegetic Travel
recognizes WCI's four driver bases, resolves the player's exact inn Location,
and opens the normal carriage parchment path at Riverwood, Old Hroldan,
Rorikstead, Dragon Bridge, Nightgate Inn, Kynesgrove, and Ivarstead.

The native request builder resolves the source label from the same travel
catalogue used for destinations and quotes. This keeps all nine city origins
and all seven inn origins on one validated path. Selection, fare, hours,
availability, Apparition handling, payment, and travel therefore behave like
ordinary Diegetic Travel carriage service.

WCI's own destination prompt remains available as its independent fallback.
Only one Diegetic Travel route-map prompt should be present. The retired
`DiegeticTravelWciInnCarriages.esp` must not be installed because it adds a
second, redundant route-map dialogue entry.

## Better Carriage Destinations

Better Carriage Destinations (BCD) remains a possible future map-based front
end, but its CFTO and WCI patches compete with the physical parchment handoff.

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
separate parchment handoff with flat destination gates and configurable
distance-based carriage fares.
With the BCD CFTO patch enabled, that handoff is bypassed.

LoreRim testing must keep its curated BCD chain loaded. Do not disable and
re-enable the BCD base, CFTO adapter, or WCI adapter merely to expose Diegetic
Travel: MO2 can append the restored plugins and dependent patches to the end of
the profile, changing the controlled load order.

The separately packaged `DiegeticTravelLoreRimBcdCompat.esp` provides the
physical-parchment coexistence path. It loads after `DiegeticTravel.esp` and
adds a default-off condition to exactly three BCD dialogue INFOs: generic
carriage, CFTO ferry, and WCI carriage. The original BCD fragments and
conditions remain intact, and the diagnostic global
`DNT_ShowBcdTravelDialogue` can restore them by being set to `1`. BCD's DLL,
MCM, scripts, and plugin order are otherwise untouched.

This compatibility ESL suppresses competing selectors; it does not reproduce
BCD's broad eligible-map-marker feature set and is not a claim of BCD parity.

A proper integration should reuse BCD only as the selection surface:

1. Diegetic Travel builds a marker whitelist from the current driver's flat
   destination set and live gates.
2. BCD opens the map with that whitelist.
3. The selected marker is translated back to a Diegetic Travel destination ID.
4. Diegetic Travel revalidates availability, uses its immutable configured
   carriage quote, then performs its normal direct travel handoff.

That future design would preserve BCD's polished map UI without duplicating
service logic. It requires a BCD API extension or a different deliberate
compatibility adapter; merely changing load order is not sufficient.

### Archived wizard-guide experiment

An earlier optional plugin proved that BCD could act as a selection-only map
front end while the wizard service retained fare and travel authority. The
physical parchment picker superseded that experiment. Its source and dedicated
build/test pipeline were removed from the maintained tree during repository
cleanup and remain recoverable from Git history.

## Wizarding Traversal: Apparition Travel

`WizardingTraversal.esl` is an optional, soft-detected compatibility target.
When its own `fFastTravelSpeedMult=100000` override is present, Diegetic Travel completes
direct carriage, wizard, and ferry trips with `MoveTo` instead of
`Game.FastTravel`. The normal provider fare, state
validation, fade, arrival marker, and companion handoff still apply, but no
travel time passes.

This deliberately does not mutate Wizarding Traversal's game setting. The
original plugin is not a master and is not required: compatibility is soft
detected, and an absent override falls through to normal time-passing fast
travel. The holder effect is logged for diagnostics but is not authoritative,
because Wizarding Traversal can leave it present after Apparition is toggled
off.

The release test must verify both toggle directions. The speed override should
be `100000` while Apparition is enabled and return to its ordinary value after
the second cast; travel follows that live value on every trip.
