# Wizard Guides — Phase 1

This module is the first vertical slice of the wizard-guide travel pillar. It is
separate from the carriage prototype and has no CFTO or Better Carriage
Destinations dependency.

## Network

- The College of Winterhold is the permanent hub.
- Farengar Secret-Fire offers a direct trip to the College.
- Wylandriah offers a direct trip to the College.
- Sybille Stentor offers a direct trip to the College.
- Wuunferth the Unliving offers a direct trip to the College.
- Calcelmo offers a direct trip to the College.
- Madena offers a direct trip to the College.
- Falion offers a direct trip to the College.
- Permanent College faculty offer Whiterun, Riften, Solitude, Windhelm,
  Markarth, Dawnstar, or Morthal from the College.
- Every hop costs 250 gold.
- Travel is an immediate teleport. It does not advance time, count as rest, or
  restore health, magicka, or stamina.
- There are no faction, relationship, quest, or trust gates in Phase 1.

The proven three-node star established the route pattern used by the
eight-node candidate:
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
- Wuunferth the Unliving: `Of course.`
- Calcelmo: `Of course.`
- Madena: `Of course.`
- Falion: `Of course.`
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

- College: `WinterholdCollegeMapMarkerRef` (`046BDF:Skyrim.esm`)
- Whiterun: `FarengarLabMARKER` (`0B7AA5:Skyrim.esm`)
- Riften: `RiftenKeepWizardLabMarker` (`044A4A:Skyrim.esm`)
- Solitude: `BluePalaceAudienceMarker` (`02C194:Skyrim.esm`), whose installed
  winner is `JK's Blue Palace.esp`
- Windhelm: `WindhelmWuunferthLabMarker` (`0A3F1C:Skyrim.esm`), whose focused
  inventory winner is USSEP
- Markarth: `MarkarthCastleWizardVendorMarkerREF` (`03692A:Skyrim.esm`), whose
  focused inventory winner is Skyrim.esm
- Dawnstar: `MadenaServiceMarkerREF` (`0877B4:Skyrim.esm`)
- Morthal: `MorthalCarriageEastDestinationMarker` (`0EB7CC:Skyrim.esm`), a
  purpose-built ground-level arrival reference outside the rebuilt town

The first six nodes' spatial safety passed the controlled 2026-07-31 in-game
regression. Dawnstar passed its focused 2026-08-01 arrival test. The original
Morthal map-marker candidate landed on COTN roof geometry and is rejected; the
carriage-destination replacement is structurally verified but still needs a
focused gameplay arrival check.
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

The proven Windhelm/Markarth build adds exact-speaker direct routes for Wuunferth
and Calcelmo, extends the faculty hub to five choices, and adds voiced plus
Mirabelle-subtitle INFOs for both destinations. The generator is
byte-idempotent at ESP SHA-256
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`.
Both scripts compile with zero errors and warnings, and the exact-record and
voice-asset audits pass. The monitored 2026-07-31 retest confirmed Ancano had no
option, both new round trips completed with matching voices, both arrival
markers were usable, and the Whiterun regression completed. Papyrus recorded
five starts and five completions. Wuunferth's line was slightly cut off by the
former one-second travel delay. The later sequential 1.5-second dialogue and
`PlayAndWait` payment contract described below resolved that timing class and
is live-proven.

An initial `9B4545B8...` gameplay pass proved all five requested teleports but
also allowed Ancano to select an identical court-wizard root and produced wrong
voices for Ancano and Calcelmo. `ANAM` is therefore not accepted as an
eligibility gate. The corrected build requires an explicit subject
`GetIsID == 1` condition on every exact-speaker INFO, and the structural audit
enforces that contract.

The live-proven fare-feedback build replaces the normal insufficient-funds
modal with `Debug.Notification`, keeping the denial visible in the top-left without
interrupting play. Successful payment plays Skyrim's vanilla `ITMGoldDown`
sound (`000334AB:Skyrim.esm`) after the confirmation response. The
sound is an audited `FarePaymentSound` quest-script property rather than a
runtime EditorID lookup. The ESP is byte-idempotent at SHA-256
`2DF34217F6576D3FCFE720E1E101690216E6D94157C26A9D79544A1E7BA83C21`;
both Papyrus scripts compile with zero errors and warnings, and the independent
wizard-star and map-adapter audits pass. The monitored pass proved the
notification and absence of payment/movement on both direct-dialogue and map
denials at 22 gold, plus the payment sound and normal completion on funded
trips. The exact promoted package is
`dist\DiegeticTravelWizardGuides-phase1.zip`, SHA-256
`0029CC61CE6A9D94A900033BA1BACB341F9756F2E8F611F57F534DC4F3DDE759`.

The live-proven phase-1 checkpoint had one semantic rough edge: its terminal
INFO could play an affirmative vanilla response before the authoritative
service rejected the fare. The service-side check remains mandatory.

The previous fare-denial candidate addressed that rough edge with mutually
exclusive terminal INFOs: funded responses require at least 250 gold and denial
responses require less than 250 gold, while both still call the authoritative
service fragment. Farengar, Wylandriah, Sybille, and Calcelmo use verified
vanilla SharedInfo refusals; Wuunferth and the five College destinations use
forced-subtitle fallbacks. The generator is byte-idempotent at ESP SHA-256
`3D469B2441FFEBCC0AF57D4F77ADB3FE49B940C56707C0B027133EE6799A2CA5`.
Workspace and deployed exact-record audits, the affirmative/denial FUZ audit,
and the independent map-adapter audit pass. The candidate package is
`dist\DiegeticTravelWizardGuides-fare-denials-candidate.zip`, SHA-256
`45219F0C475EF0EAE020F6BE332F761E44E3376BC0E332F6A5B017D55EBFB793`.
The monitored 2026-07-31 pass proved Farengar's Skyrim refusal and Sybille's
HearthFires refusal, direct denials with no movement, funded direct regressions,
College destination-level subtitle denials, silent map denials, and funded map
travel. The listener observed four successful trips and no wizard-script
warning. Wylandriah and Calcelmo still need focused live voice spot-checks;
Wuunferth is intentionally subtitle-only.

The current seven-spoke expansion adds exact-speaker routes for Madena and
Falion plus Dawnstar and Morthal faculty destinations. The independent xEdit
audit verifies seven exact direct routes, seven hub links, two new three-INFO
destination topics, inverse fare conditions, fragment destinations, and the
two new service-marker bindings. Both Papyrus scripts compile with zero errors
and warnings. Vanilla voice-archive inspection proves genuine `Of course.`
FUZ/LIP for `FemaleCondescending` and `MaleSlyCynical`, and proves Madena's
funds refusal. A deeper archive/xEdit pass found Falion's genuine generic
`CantBeHelped` SharedInfo (`000DBA24`, "It can't be helped.") and matching
`MaleSlyCynical` FUZ/LIP, replacing the earlier subtitle-only fallback.
`DawnstarMarker` and `MorthalMarker` also resolve their Skyrim FormIDs at
runtime so an upgraded save cannot retain serialized `None` or stale marker
properties. A monitored 2026-08-01 pass proved Madena, Dawnstar, Falion's fare
branches, and four clean trip completions. It rejected the Morthal map marker
after a roof landing; the audited carriage-destination replacement still needs
a focused arrival retest. A later pass proved the replacement Morthal arrival;
Falion's funded line initially played only "course" while the payment cue began
at the same instant. The sequential service now reserves 1.5 seconds for the
dialogue and finishes the payment cue before moving the player. A focused
monitored retest proved Falion's full lip-synced `It can't be helped.` denial,
full `Of course.` confirmation, payment sound, and completed travel.
The generator is byte-idempotent at ESP SHA-256
`174CD2B86AC08693C4B708CDB1141190B5093F2BC6C594BCBE03916840D47B56`.

Do not launch Skyrim as part of the build. Run the gameplay pass only after
explicit approval.
