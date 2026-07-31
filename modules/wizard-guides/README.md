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
direct top-level transactions to the College. Phinis has one root response
linking to the Whiterun and Riften destination topics.

Every terminal travel INFO deliberately shares response data from a short
vanilla INFO whose FUZ/LIP exists for the speaker's exact voice type:

- Farengar: `Yes.`
- Wylandriah: `Of course.`
- Phinis destination confirmation: `Of course.`

Phinis's branching hub owns the unvoiced forced-subtitle response
`Where do you need to go?`. Every terminal donor is now a genuine SharedInfo
with an EditorID and a shipped FUZ for the speaker's exact voice type. Earlier
failed builds pointed `DNAM` at ordinary Hello/Favor INFOs; xEdit accepted
those records, but Skyrim did not consider the resulting Phinis choices valid.

Travel INFOs have `Goodbye` and an `OnBegin` fragment that enters the central
service, waits one second for dialogue to close, charges the fare, and moves
the player. The hub INFO has no travel fragment and only opens the destination
choices. Insufficient gold produces an explicit message box and no charge.

## Arrival markers

The module reuses persistent markers already present in Skyrim and moved by the
installed JK interior overhauls where necessary:

- College: `MGPhinisSleepMarker` (`036A67:Skyrim.esm`)
- Whiterun: `FarengarLabMARKER` (`0B7AA5:Skyrim.esm`)
- Riften: `RiftenKeepWizardLabMarker` (`044A4A:Skyrim.esm`)

Their spatial safety passed the controlled 2026-07-31 in-game regression.
Structural validation alone still cannot prove marker safety after future
load-order or interior changes.

## Test scope

The three-node route flow passed monitored transport and presentation
regressions on 2026-07-31. Together they verified:

1. Farengar audibly says `Yes.` with lip sync before reaching the College;
2. Phinis shows `Where do you need to go?` and opens exactly Whiterun and
   Riften;
3. Phinis audibly says `Of course.` before either destination trip;
4. Wylandriah audibly says `Of course.` before returning to the College;
5. the first Phinis line, `Where do you need to go?`, is visibly subtitled but
   silent by design and is distinct from the voiced confirmation;
6. no game time or recovery is added by the module.

Do not launch Skyrim as part of the build. Run the gameplay pass only after
explicit approval.
