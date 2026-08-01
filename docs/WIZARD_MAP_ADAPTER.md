# Wizard map-picker adapter research and design

Updated: 2026-07-31

## Decision

Use Better Carriage Destinations as a selection surface only. Keep its native
DLL and injected Scaleform movie unchanged, and put the integration in a
separate Papyrus/ESP adapter. Do not call BCD's `BCD_Script.OpenMap`, pricing,
response scenes, or travel functions.

This preserves the live-proven wizard service as the sole authority for stable
destination IDs, fare validation, payment, trace output, and arrival markers.
It also leaves the existing dialogue destination list available as a rollback
path.

## Upstream evidence

Research is pinned to BCD commit
`136dc7b3ad9754877c485fd5cea29550af108888`, which was still repository `HEAD`
on 2026-07-31. LoreRim has BCD `1.0.10` installed and enabled in the dedicated
`UltraDiegeticTravel` profile.

BCD's native `OpenTheMap(FormList, Bool)` closes the Dialogue Menu, stores one
global whitelist/blocklist, registers a MapMenu event sink, and opens the map.
Its injected ActionScript dims rejected markers and sends
`BCD_SetDestination` with the selected marker's runtime array index. The native
`GetMapMarkerByIndex` function translates that index back to the selected
reference while the MapMenu is open.

Relevant upstream source:

- [Native whitelist and map opening](https://github.com/shazdeh/Better-Carriage-Destinations/blob/136dc7b3ad9754877c485fd5cea29550af108888/src/plugin.cpp#L35-L82)
- [Native Papyrus functions](https://github.com/shazdeh/Better-Carriage-Destinations/blob/136dc7b3ad9754877c485fd5cea29550af108888/src/plugin.cpp#L201-L222)
- [Scaleform selection event](https://github.com/shazdeh/Better-Carriage-Destinations/blob/136dc7b3ad9754877c485fd5cea29550af108888/Fla/BetterCarriageDestinations.as#L69-L75)

The installed BCD quest registers for that event only inside its own `OpenMap`
function. The adapter calls the lower-level native `BCD_Utils.OpenTheMap`
instead, so BCD's carriage quest is not listening during a wizard selection.

## Adapter flow

1. An eligible College faculty member exposes a new terminal dialogue option.
2. `DNT_WizardMapFragment` passes the speaker reference to
   `DNT_WizardMapPicker.OpenMap`.
3. The picker registers for `BCD_SetDestination` and opens BCD with a whitelist
   of exactly five city world-map markers.
4. A valid click is resolved to its map-marker reference before the map closes.
5. The picker translates that exact reference to `whiterun`, `riften`,
   `solitude`, `windhelm`, or `markarth`.
6. The picker closes the map and calls the existing
   `DNT_WizardTravelService.RequestTravel(destinationId, speakerRef)`.
7. The core service revalidates, charges, logs, and moves the player to its
   existing interior arrival marker.

Cancellation closes the map without payment or travel. A per-quest active flag
prevents overlapping picker sessions. An unknown marker is rejected and leaves
the map open.

## Dialogue branch contract

The map prompt must be the Starting Topic of its own top-level dialogue branch.
Skyrim does not expose every topic assigned to a top-level branch; it exposes
that branch's designated Starting Topic. The first live adapter build reused the
core faculty branch, whose Starting Topic remained the proven destination-list
prompt. The adapter quest loaded and ran, but the map prompt never appeared and
no `WIZARD_MAP_*` trace was emitted.

The corrected adapter therefore owns a dedicated `DLBR` with only the
`Top-Level` flag, points its `SNAM` Starting Topic at `DNT_WG_OpenMap`, and owns
both records with the start-game-enabled `DNT_WizardMapPickerQuest`. The map
topic points back to that branch. The existing core branch is neither overridden
nor reused. A `DLVW` editor-layout record is not required by the live-proven core
runtime and is deliberately not added.

The independent xEdit audit rejects the adapter unless all of those links and
flags match and the map branch differs from the core faculty branch. This
contract follows the Creation Kit's documented
[Dialogue Branch behavior](https://skyrimck.uesp.net/wiki/Dialogue_Branch).

## Marker inventory

The headless xEdit inventory read BCD's installed `BCD_AutoUnlockMarkers` list
and resolved the five required selection markers:

- Whiterun: `000162CE` `WhiterunMapMarkerREF`
- Riften: `0001C390` `RiftenMapMarkerREF`
- Solitude: `0004D0F4` `SolitudeMapmarkerRef`
- Windhelm: `00038436` `WindhelmMapMarkerRef`
- Markarth: `0001C38A` `MarkarthMapMarkerREF`

These are distinct from the core service's interior arrival references.

## Live promotion gate

The corrected adapter is live-proven. Every behavior in the promotion matrix
has been confirmed:

- [x] Eligible College faculty expose the map prompt while the old list remains
  available.
- [x] Ancano and other ineligible actors do not show the map option.
- [x] The map opens correctly at 32:9.
- [x] Only the five whitelisted destination markers can be selected.
- [x] Cancelling produces `WIZARD_MAP_CANCEL`, removes no gold, and leaves the
  player in place.
- [x] Selecting a marker produces `WIZARD_MAP_SELECT` followed by one matching
  core `WIZARD_TRAVEL_START` / `WIZARD_TRAVEL_COMPLETE` pair.
- [x] Map-initiated fare denial still comes from the core service and does not
  move the player.
- [x] The original dialogue list completes a regression trip.

The first successful map session selected Solitude through Mirabelle and
Riften through Phinis; both completed with fare 250 and were followed by
successful city-wizard returns to the College. The corrected prompt first
became visible after saving once with the adapter installed and reloading that
save, so future clean-install tests should include an explicit save/reload
checkpoint.

The later exterior-College session confirmed Ancano exclusion, the five-marker
whitelist, and two cancellation paths. Both cancellations emitted
`WIZARD_MAP_CANCEL` with no select, travel, payment, or movement. The final
fare-feedback pass selected Windhelm through Mirabelle with 22 gold and
emitted `WIZARD_MAP_SELECT` followed by
`WIZARD_TRAVEL_DENIED reason=gold required=250 available=22`, with no
start/completion, payment, or movement. A funded trip in the same pass played
vanilla `ITMGoldDown` and completed normally.

Use the map-aware monitored harness for this matrix:

```powershell
.\tools\Run-WizardGuidesTest.ps1 -RequireMapAdapter
```

That mode requires the core ESP, adapter ESP, BCD ESP, adapter SEQ, and both
adapter PEX files before launch, then streams both `WIZARD_MAP_*` and
`WIZARD_TRAVEL_*` traces.
