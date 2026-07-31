# Wizard Guides — Phase 1

This module is the first vertical slice of the wizard-guide travel pillar. It is
separate from the carriage prototype and has no CFTO or Better Carriage
Destinations dependency.

## Network

- The College of Winterhold is the permanent hub.
- Farengar Secret-Fire offers a direct trip to the College.
- Phinis Gestor offers the return trip to Whiterun.
- Every hop costs 250 gold.
- Travel is an immediate teleport. It does not advance time, count as rest, or
  restore health, magicka, or stamina.
- There are no faction, relationship, quest, or trust gates in Phase 1.

This two-node slice proves a complete spoke-to-hub-to-spoke journey before more
court wizards are exposed. The existing Riften/Wylandriah records remain
scaffolding only and are not part of the supported gameplay checkpoint.

## Runtime boundary

`DNT_WizardTravelService` owns the destination registry, fare check, payment,
and teleport. Dialogue calls it by stable destination ID. A future map adapter
can call the same `GetFare`, `CanTravel`, and `RequestTravel` functions without
duplicating travel behavior.

Phase 1 deliberately uses new quest, branch, topic, and INFO records. It does
not override vanilla or LoreRim dialogue topics. Farengar and Phinis each have
a direct top-level transaction with an explicit destination and fare.

Both INFOs own their response text instead of inheriting a vanilla Shared Info.
They use `Goodbye`, `Force Subtitle`, and `No LIP File`; the current prototype
therefore shows a short unvoiced subtitle. Its `OnBegin` fragment enters the
central service, waits one second for dialogue to close, charges the fare, and
moves the player. Insufficient gold is rejected by the service with no charge.

## Arrival markers

The module reuses persistent markers already present in Skyrim and moved by the
installed JK interior overhauls where necessary:

- College: `MGPhinisSleepMarker` (`036A67:Skyrim.esm`)
- Whiterun: `FarengarLabMARKER` (`0B7AA5:Skyrim.esm`)

Their spatial safety still requires the controlled in-game test. Structural
validation cannot prove that a marker is unobstructed in the rendered cell.

## Test scope

The next gameplay pass should verify:

1. Farengar shows the direct College option with its 250-gold fare;
2. selecting it shows `Very well. The College, then.` and emits a
   `WIZARD_TRAVEL_START` trace;
3. successful travel charges exactly 250 gold and arrives unobstructed near the
   College service area;
4. Phinis shows the direct Whiterun option and returns the player to
   `FarengarLabMARKER`, charging one additional hop;
5. insufficient gold shows a notification and charges nothing;
6. no game time or recovery is added by the module.

Do not launch Skyrim as part of the build. Run the gameplay pass only after
explicit approval.
