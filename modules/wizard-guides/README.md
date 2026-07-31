# Wizard Guides — Phase 1

This module is the first vertical slice of the wizard-guide travel pillar. It is
separate from the carriage prototype and has no CFTO or Better Carriage
Destinations dependency.

## Network

- The College of Winterhold is the permanent hub.
- Farengar Secret-Fire offers a direct trip to the College.
- Wylandriah offers a direct trip to the College.
- Sybille Stentor offers a direct trip to the College.
- Permanent College faculty offer Whiterun, Riften, or Solitude from the
  College.
- Every hop costs 250 gold.
- Travel is an immediate teleport. It does not advance time, count as rest, or
  restore health, magicka, or stamina.
- There are no faction, relationship, quest, or trust gates in Phase 1.

The proven three-node star established the route pattern used by the proven
four-node extension:
each court wizard reaches only the College, while any permanent College faculty
member can provide the same outward destination menu.

## Runtime boundary

`DNT_WizardTravelService` owns the destination registry, fare check, payment,
and teleport. Dialogue calls it by stable destination ID. A future map adapter
can call the same `GetFare`, `CanTravel`, and `RequestTravel` functions without
duplicating travel behavior.

Phase 1 deliberately uses new quest, branch, topic, and INFO records. It does
not override vanilla or LoreRim dialogue topics. Farengar and Wylandriah have
direct top-level transactions to the College. One owned root response, gated
to College faction rank 3 or higher, links to the Whiterun and Riften topics.
The explicit exclusions are Arniel's summoned shade and the dead Alftand
expedition NPC Endrast. The eligible permanent roster in Skyrim.esm is:

- Sergius Turrianus, Mirabelle Ervine, Savos Aren, and Tolfdir;
- Arniel Gane, Enthir, Nirya, Colette Marence, and Phinis Gestor;
- Drevis Neloren, Faralda, and Urag gro-Shub.

Every terminal travel INFO deliberately shares response data from a short
vanilla INFO whose FUZ/LIP exists for the speaker's exact voice type:

- Farengar: `Yes.`
- Wylandriah: `Of course.`
- Sybille Stentor: `Of course.`
- College faculty destination confirmation: `Of course.`

The branching faculty hub owns the unvoiced forced-subtitle response
`Where do you need to go?`. Every terminal donor is now a genuine SharedInfo
with an EditorID. Skyrim ships its `Of course.` FUZ/LIP for ten of the eleven
faculty voice types. Mirabelle's unique voice is the exception, so her two
terminal INFOs own subtitle-only `Of course.` responses. Earlier failed builds
pointed `DNAM` at ordinary Hello/Favor INFOs; xEdit accepted those records, but
Skyrim did not consider the resulting Phinis choices valid.

Travel INFOs have `Goodbye` and an `OnBegin` fragment that enters the central
service, waits one second for dialogue to close, charges the fare, and moves
the player. Travel traces include the initiating speaker reference so expanded
roster tests can identify the actual guide. The hub INFO has no travel fragment
and only opens the destination choices. Insufficient gold produces an explicit
message box and no charge.

## Arrival markers

The module reuses persistent markers already present in Skyrim and moved by the
installed JK interior overhauls where necessary:

- College: `MGPhinisSleepMarker` (`036A67:Skyrim.esm`)
- Whiterun: `FarengarLabMARKER` (`0B7AA5:Skyrim.esm`)
- Riften: `RiftenKeepWizardLabMarker` (`044A4A:Skyrim.esm`)
- Solitude: `BluePalaceAudienceMarker` (`02C194:Skyrim.esm`), whose installed
  winner is `JK's Blue Palace.esp`

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

The expanded faculty access passed a monitored gameplay regression on
2026-07-31. J'zargo did not receive the service option, while all eligible
faculty encountered by the player did. Phinis retained both choices, and
Mirabelle's subtitle-only fallback displayed and completed travel. Nine trips
produced nine matching start/completion pairs with no wizard-script warning.

The Solitude spoke is generated, byte-idempotent, compiled without warnings,
and passes the independent dialogue/service and voice-asset audits. Its
monitored 2026-07-31 gameplay pass verified Mirabelle's subtitle-only journey
to Solitude, safe arrival on the remodeled Blue Palace court floor, Sybille's
audible lip-synced `Of course.` and return to the College, plus a Riften and
Wylandriah regression. Four starts produced four matching completions.

Do not launch Skyrim as part of the build. Run the gameplay pass only after
explicit approval.
