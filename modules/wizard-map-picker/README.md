# Wizard map-picker adapter

This optional module connects Better Carriage Destinations (BCD) to the proven
College-centered wizard travel service. It does not replace or modify
`DiegeticTravelWizardGuides.esp`.

## Boundary

- BCD owns the MapMenu injection, marker dimming, click handling, and
  `BCD_SetDestination` event.
- `DNT_WizardMapPicker` owns the whitelist, selected-marker translation,
  cancellation, and concurrency guard.
- `DNT_WizardTravelService` remains the only fare and movement authority.
- The existing five-choice dialogue submenu remains available as a fallback.

The adapter deliberately calls `BCD_Utils.OpenTheMap` directly rather than
`BCD_Script.OpenMap`. That avoids BCD's carriage/ferry pricing, response scene,
and travel implementation.

## Marker contract

| Destination ID | World-map marker | Core arrival marker |
| --- | --- | --- |
| `whiterun` | `000162CE` `WhiterunMapMarkerREF` | `000B7AA5` |
| `riften` | `0001C390` `RiftenMapMarkerREF` | `00044A4A` |
| `solitude` | `0004D0F4` `SolitudeMapmarkerRef` | `0002C194` |
| `windhelm` | `00038436` `WindhelmMapMarkerRef` | `000A3F1C` |
| `markarth` | `0001C38A` `MarkarthMapMarkerREF` | `0003692A` |

The world-map references exist only for selection. They are never passed to
the core service as arrival targets.

## Current status

Candidate. Papyrus compiles with zero errors and warnings, the generator is
byte-idempotent, and the independent xEdit audit verifies the BCD/core masters,
five-entry whitelist, exact marker properties, faculty conditions, dialogue
branch, quest ownership, and fragment binding. Gameplay proof is still needed.
