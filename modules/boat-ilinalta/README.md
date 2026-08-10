# Lake Ilinalta boat vertical slice

This isolated candidate adapts the gameplay-proven parchment ferry contract to
CFTO's three public Lake Ilinalta ferrymen:

```text
Brittleshin Pass <-> Half-Moon Mill <-> Guardian Stones
```

Lakeview Manor is a private fourth provider. It is visible only while CFTO's
placed ferryman is enabled, preserving the Hearthfire ownership/jetty/service
state without cloning those prerequisite quests. Ilinata's Deep is available
from all four available ferrymen as a destination-only extension using CFTO's
50-gold regional fare. It has no provider and therefore never appears as a
return source.

## Contract

- CFTO remains authoritative for ferrymen, its live local fare, and arrival and
  companion markers.
- The service validates the live speaker and destination, charges once, then
  mirrors CFTO's fade, over-encumbrance allowance, and `Game.FastTravel` flow.
- Brittleshin also moves the player's horse to CFTO's dedicated marker.
- Guardian Stones also moves the active follower and horse to CFTO's dedicated
  markers. Half-Moon Mill uses normal fast-travel party behavior.
- Lakeview Manor uses CFTO's dedicated arrival, follower, and horse markers and
  the local 30-gold fare.
- Ilinata's Deep uses its own CFTO arrival, follower, and horse markers and the
  regional 50-gold fare rather than the lane's local 30-gold fare.
- The dialogue handoff uses the gameplay-proven native Dialogue Menu close and
  confirmation loop. It does not synthesize an Escape keypress.
- Cancel is inert and the original CFTO dialogue remains available.

The map coordinates use CFTO's exact shoreline arrival-marker world positions
projected through the nine-point carriage parchment calibration. A live test
rejected the attempted northward texture-tip correction; Brittleshin therefore
uses the original projected southern shoreline point. The original
three-Honrich-anchor estimates visibly placed Half-Moon Mill west of Lake
Ilinalta and are retired. The corrected positions remain a visual gameplay
check, not a claimed live result.

All three mainland waterway pickers exchange non-interactive landmarks. While
Lake Ilinalta is active, the North-coast and Lake Honrich docks remain visible
as grey anchors; while either of those networks is active, the three Lake
Ilinalta docks remain visible in the same inactive style.

No artwork or audio is shipped. The module relies on the existing parchment
runtime and external RUSTIC MAPS texture.

## Focused gameplay checklist

1. At Rinlen, Hisygg, and Bryst, confirm the parchment prompt appears, the
   spoken response/lip sync plays, and the map opens without pressing Escape.
2. Confirm each public map shows the other providers plus Ilinata's Deep. With
   Lakeview unlocked, confirm its provider and marker appear; without it, they
   must remain absent.
3. Cancel once; confirm no charge and no movement.
4. At 0 or 10 gold, choose a destination; confirm denial, no charge, and no
   movement. Then fund 30 gold and complete a three-stop cycle. Confirm
   Ilinata's Deep quotes and charges 50 gold.
5. With a horse, arrive at Brittleshin Pass. With a follower and horse, arrive
   at Guardian Stones. With a follower and horse, verify the dedicated Ilinata
   arrival handoff. Confirm no parchment provider exists at Ilinata's Deep.
