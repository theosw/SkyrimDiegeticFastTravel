# Wizard Guides — Phase 1

This module is the first vertical slice of the wizard-guide travel pillar. It is
separate from the carriage prototype and has no CFTO or Better Carriage
Destinations dependency.

## Network

- The College of Winterhold is the permanent hub.
- Farengar Secret-Fire offers a direct trip to the College.
- Wylandriah offers a direct trip to the College.
- Phinis Gestor offers Whiterun or Riften from the College.
- Every hop costs 250 gold.
- Travel is an immediate teleport. It does not advance time, count as rest, or
  restore health, magicka, or stamina.
- There are no faction, relationship, quest, or trust gates in Phase 1.

This three-node star proves the route pattern intended for every later court:
each court wizard reaches only the College, while the College guide provides
the outward destination menu.

## Runtime boundary

`DNT_WizardTravelService` owns the destination registry, fare check, payment,
and teleport. Dialogue calls it by stable destination ID. A future map adapter
can call the same `GetFare`, `CanTravel`, and `RequestTravel` functions without
duplicating travel behavior.

Phase 1 deliberately uses new quest, branch, topic, and INFO records. It does
not override vanilla or LoreRim dialogue topics. Farengar and Wylandriah have
direct top-level transactions to the College. Phinis has one owned root
response linking to the Whiterun and Riften destination topics.

Every visible INFO owns its response text instead of inheriting a vanilla
Shared Info. The current prototype uses short unvoiced, forced subtitles.
Travel INFOs have `Goodbye` and an `OnBegin` fragment that enters the central
service, waits one second for dialogue to close, charges the fare, and moves the
player. The hub INFO has no travel fragment and only opens the destination
choices. Insufficient gold produces an explicit message box and no charge.

## Arrival markers

The module reuses persistent markers already present in Skyrim and moved by the
installed JK interior overhauls where necessary:

- College: `MGPhinisSleepMarker` (`036A67:Skyrim.esm`)
- Whiterun: `FarengarLabMARKER` (`0B7AA5:Skyrim.esm`)
- Riften: `RiftenKeepWizardLabMarker` (`044A4A:Skyrim.esm`)

Their spatial safety still requires the controlled in-game test. Structural
validation cannot prove that a marker is unobstructed in the rendered cell.

## Test scope

The next gameplay pass should verify:

1. Farengar reaches the College for 250 gold;
2. Phinis's root response opens exactly two choices: Whiterun and Riften;
3. the Riften choice charges 250 gold and arrives unobstructed near Wylandriah;
4. Wylandriah offers a direct 250-gold return to the College;
5. Phinis can then return the player to Whiterun;
6. selecting a route with insufficient gold shows the exact required and
   available amounts, charges nothing, and does not move the player;
7. no game time or recovery is added by the module.

Do not launch Skyrim as part of the build. Run the gameplay pass only after
explicit approval.
