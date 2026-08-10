# Destination-only ferry gameplay pass

This is the promotion gate for the four original CFTO one-way destinations.
Run it in one Skyrim session after the three owned ferry test mods and the
shared parchment picker have been deployed and enabled. The ordinary LoreRim
stack remains the baseline.

## Map visibility

Open the parchment map at each public provider and confirm the one-way marker
is present without changing the provider's normal source identity:

- North coast: all seven Route 1 providers show Frostflow Lighthouse. Each map
  has seven selectable destinations: the other six public docks plus Frostflow.
- Lake Ilinalta: Rinlen, Hisygg, and Bryst each show Ilinata's Deep in addition
  to the other two public docks.
- Solstheim: Maslyn, Bildul, and Gauldis each show Northshore Landing and
  Bujold's Retreat in addition to the other two public docks.

Cancel one map. Gold and position must remain unchanged.

## Fare and travel

1. From any north-coast provider, travel to Frostflow Lighthouse. Confirm a
   50-gold charge, fade, arrival at CFTO marker `05038411`, and no parchment
   travel prompt at the destination.
2. At any Lake Ilinalta provider, carry 49 gold and select Ilinata's Deep.
   Confirm denial, no charge, and no movement. Fund exactly 50 gold and repeat;
   confirm arrival at `0503840E`. If practical, bring a follower and horse and
   confirm CFTO markers `05195C43` and `05195C35` are used. There must be no
   parchment travel prompt at the destination.
3. From any public Solstheim provider, travel to Northshore Landing for 50 gold
   and confirm arrival at `0503840C` with no return provider.
4. Return to any public Solstheim provider by console or another established
   travel system, then travel to Bujold's Retreat for 50 gold. Confirm arrival
   at `0503840D` with no return provider.

The ordinary Lake Ilinalta destinations must still quote 30 gold; only
Ilinata's Deep uses the regional 50-gold fare.

## Log acceptance

For each completed trip, Papyrus should contain matching entries in order:

```text
BOAT_PARCHMENT_SELECT ... destination=<destination id>
BOAT_TRAVEL_START ... destination=<destination id> fare=<expected fare>
BOAT_TRAVEL_COMPLETE ... destination=<destination id> fare=<expected fare>
```

The four IDs are `frostflow_lighthouse`, `ilinatas_deep`,
`northshore_landing`, and `bujolds_retreat`. Reject the candidate if any trip
logs `invalid_provider`, `unknown_destination`, `service_unavailable`, or an
unexpected second charge.
