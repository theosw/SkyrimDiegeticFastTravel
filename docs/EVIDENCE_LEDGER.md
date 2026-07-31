# Diegetic Travel evidence ledger

Updated: 2026-07-31

This ledger separates ideas that look valid in tooling from behavior that has
actually been demonstrated in Skyrim. Update an entry whenever a test changes
its evidence. Do not describe a candidate as working until it passes a
monitored gameplay test on the `UltraDiegeticTravel` profile.

## Status vocabulary

- **Proven:** passed a monitored gameplay test in the intended LoreRim profile.
- **Supported:** backed by Creation Kit documentation, vanilla game data, or a
  working comparison mod, but not yet isolated in our live module.
- **Candidate:** plausible and ready to implement or test, with incomplete
  evidence.
- **Rejected:** contradicted by a live test or by the documented data contract.
- **Deferred:** intentionally outside the current phase.

## Current decision

The latest fully proven faculty-access wizard star includes the Solitude spoke;
its ESP is SHA-256
`3F5C3BEBCBBD26DC70517A7943CF36E918942C57240736A3BFD3731EAB2D9550`.
Commit `4dfb646`, whose ESP is SHA-256
`4EEAED7C6556ADC159A128C9D95FB66124C3C90FC3FB9200D4CF7CC797567E89`, is the
previous Whiterun/Riften faculty-access checkpoint.
The earlier `9aa25ef` checkpoint is the all-owned-response fallback. One failed
voice experiment pointed the Phinis destination `DNAM` fields at ordinary
`Favor258` dialogue rather than a real SharedInfo record.

The corrected build is now live-proven for menu flow, payment, travel, voice,
and lip sync. Phinis's hub remains owned and intentionally unvoiced, while both
destination responses use genuine SharedInfo
`000DBA22` (`OfCourse`, "Of course."). Skyrim ships the matching
`MaleCondescending` FUZ used by Phinis. The ESP is byte-idempotent at SHA-256
`9402ED91A1207A4BB94D0778FD359FD0B477DA24C745F42BD611CBBD3B6185B5` and
passes the strengthened audit. A monitored 2026-07-31 test exercised every
route, both Phinis choices, and fare denial. A second monitored pass confirmed
the expected audio and lip sync for Farengar, Phinis, and Wylandriah across
four completed trips.

The deployed faculty-access build generalizes the hub to permanent College
members at faction rank 3 or higher, with explicit shade/corpse exclusions and
subtitle-only Mirabelle fallbacks. Its ESP is byte-idempotent at SHA-256
`4EEAED7C6556ADC159A128C9D95FB66124C3C90FC3FB9200D4CF7CC797567E89`, and both
the workspace and deployed copies pass the strengthened structural and voice
asset audits. A monitored gameplay pass verified the new eligibility
conditions and promoted DLG-008 to Proven.

The proven Solitude extension adds Sybille as an inbound guide, Solitude as a
third faculty destination, and `BluePalaceAudienceMarker` as the arrival. Its
ESP is byte-idempotent at SHA-256
`3F5C3BEBCBBD26DC70517A7943CF36E918942C57240736A3BFD3731EAB2D9550` and passes
the independent structural/service and voice-asset audits. The monitored
2026-07-31 gameplay matrix in DLG-009 and RUN-004 passed in full.
The exact tested Solitude payload was packaged without recompilation at
`dist\DiegeticTravelWizardGuides-phase1.zip`, SHA-256
`9D8004F580DB5FBE15DDA5F83FC594D6250C1DF56F06DAE175C41D3E0566A8A2`.

## Dialogue and voice claims

### DLG-001 — Owned hub plus linked owned destination INFOs

**Status:** Proven

**Claim:** An owned, non-Goodbye hub response can expose two `Link To` topics
whose INFOs own their responses, close dialogue, and execute travel on begin.

**Evidence:** The `9aa25ef` build displayed both Phinis choices and completed
Phinis-to-Whiterun and Phinis-to-Riften travel in monitored gameplay. Court
Wizard Teleport Services uses the same owned-response structure for its hub and
linked destination INFOs.

**Use:** This is the rollback architecture for all branching wizard dialogue.

### DLG-002 — Arbitrary INFO records used as Shared Info donors

**Status:** Rejected

**Claim:** Any vanilla INFO with suitable text and voice assets can be written
to an INFO's `DNAM` field and reused as Shared Response Data.

**Evidence:** xEdit accepted the references and the structural audit passed,
but runtime tests failed twice. `00087940` from a generic Hello spoke "Yes?"
and then suppressed the Phinis submenu. `00079AD7` from `Favor258Reject`
caused the owned Phinis hub to finish with no valid destination choices and no
`WIZARD_TRAVEL_*` trace. Creation Kit documentation defines the field as a
selection of a SharedInfo ID, not an arbitrary INFO.

**Use:** The generator and audit must reject donors that are not members of a
special SharedInfo topic with an Editor ID.

### DLG-003 — Genuine SharedInfo on linked destination INFOs

**Status:** Supported

**Claim:** A destination INFO reached through `Link To` may reuse a genuine
SharedInfo response.

**Evidence:** A headless xEdit scan found 1,037 vanilla INFOs inside linked
topics that use `DNAM` Shared Response Data. Creation Kit documentation says a
choice list is built from linked topics containing valid INFOs. Vanilla game
data therefore disproves the broader theory that SharedInfo is incompatible
with linked child choices.

**Use:** Voiced child choices remain viable, provided the donor satisfies the
real SharedInfo and voice-type contracts.

### DLG-004 — `000DBA22` as a Phinis destination response

**Status:** Proven

**Claim:** Both Phinis destination INFOs can use `000DBA22:Skyrim.esm`
(`OfCourse`, "Of course.").

**Evidence:** `000DBA22` belongs to `DialogueGenericSharedInfo`, has an Editor
ID, and is therefore a genuine SharedInfo. The vanilla voice archive contains
`sound\voice\skyrim.esm\malecondescending\dialoguege_dialoguegeneric_000dba22_1.fuz`.
Vanilla uses genuine SharedInfos in linked topics extensively. The candidate
is generated, deployed with matching hashes, byte-idempotent, and passes the
independent strengthened xEdit audit. In the monitored 2026-07-31 test, the
owned hub displayed both destinations and the Whiterun and Riften choices each
produced one start/complete pair. A second monitored pass confirmed Phinis's
`Of course.` was audible, lip-synced, and completed cleanly before travel. The
preceding custom hub line `Where do you need to go?` remained subtitle-only as
designed.

### DLG-005 — `000730FA` for Farengar's direct response

**Status:** Proven

**Claim:** Farengar's standalone College INFO can use `000730FA:Skyrim.esm`
(`WISharedAgreeMysteriousMaleEvenToned`, "Yes.").

**Evidence:** The donor is in `WISharedInfosTopic`, the
`MaleEvenTonedAccented` FUZ exists, and the live voice build spoke the line and
completed Farengar-to-College travel.

**Use:** Keep this donor unless later compatibility testing finds a conflict.

### DLG-006 — `000DBA22` for Wylandriah's direct response

**Status:** Proven

**Claim:** Wylandriah's standalone College INFO can use the genuine
`OfCourse` SharedInfo.

**Evidence:** The donor contract and `FemaleEvenToned` FUZ are statically
verified. The monitored presentation regression confirmed that Wylandriah's
`Of course.` was audible and lip-synced, followed by a paired
Wylandriah-to-College start/complete trace.

### DLG-007 — Owned response without packaged audio

**Status:** Proven

**Claim:** `Force Subtitle + No LIP File` allows our owned dialogue responses
to function without custom voice assets.

**Evidence:** The entire `9aa25ef` three-node star passed live with owned
responses. This is the reliable fallback when no suitable genuine SharedInfo
exists.

### DLG-008 — Rank-gated College faculty hub

**Status:** Proven

**Claim:** One owned hub INFO conditioned on College faction rank 3 or higher
can make the outward Whiterun/Riften menu available through all permanent
College faculty without NPC overrides.

**Evidence:** A headless Skyrim.esm inventory found 19 explicit members of
`CollegeofWinterholdFaction`. Rank 0 contains students and former member
Nelacar. Rank 3+ contains twelve permanent faculty plus two non-dialogue edge
cases: Arniel's summoned shade and the dead Alftand expedition NPC Endrast.
The generated build explicitly excludes those two. Its voiced destination
INFO excludes Mirabelle because her unique voice lacks the chosen generic FUZ;
two exact-speaker Mirabelle INFOs provide owned subtitle-only fallbacks. The
strengthened xEdit audit verifies all conditions, exclusions, topic children,
responses, flags, and fragments. The BSA audit verifies `Of course.` for all
ten other faculty voice types. The compiled fragment passes its
speaker reference into the service, whose travel traces now include `source=`,
allowing the monitored result to identify which faculty actor initiated a trip.

**Gameplay evidence:** In the monitored 2026-07-31 faculty regression, J'zargo
did not receive the option, while all eligible faculty encountered by the
player did. Phinis retained the outward menu. Mirabelle displayed the expected
subtitle-only `Of course.` and completed travel. Papyrus recorded nine
`WIZARD_TRAVEL_START` / `WIZARD_TRAVEL_COMPLETE` pairs, covering both outward
destinations and both court-wizard returns, with a source actor on every trace
and no wizard-script warning.

### DLG-009 — Solitude court-wizard spoke

**Status:** Proven

**Claim:** Sybille Stentor can use a direct voiced College route, while the
existing faculty hub can expose Solitude as a third child topic without
regressing Whiterun or Riften.

**Evidence:** Skyrim.esm identifies Sybille as `FemaleSultry`; the selected
genuine `000DBA22` SharedInfo has the matching vanilla FUZ/LIP already audited
for Faralda. The generated plugin adds exact-Sybille INFO `000812`, Solitude
DIAL `00080F`, voiced faculty INFO `000810`, and Mirabelle subtitle fallback
`000811`. The independent xEdit audit verifies the exact speaker, response
contracts, three hub links, topic membership, OnBegin fragments, and
destination IDs. A second generator pass is byte-identical.

The monitored 2026-07-31 pass displayed the three-choice faculty menu and
completed Mirabelle-to-Solitude with her intentional subtitle-only response.
Sybille's `Of course.` was audible and lip-synced before the return to the
College. A subsequent faculty-to-Riften and Wylandriah-to-College pair proved
the earlier spokes still worked. Papyrus recorded four starts and four matching
completions, with source references on every trace.

## Runtime claims

### RUN-001 — Travel fragment timing

**Status:** Proven

**Claim:** A terminal INFO fragment running on `OnBegin`, followed by a
one-second service delay, reliably charges and moves the player after dialogue.

**Evidence:** Farengar, Wylandriah, Whiterun, and Riften routes have completed
with paired `WIZARD_TRAVEL_START` and `WIZARD_TRAVEL_COMPLETE` traces.

### RUN-002 — Fare denial

**Status:** Proven

**Claim:** A player below the 250-gold fare is denied without being moved.

**Evidence:** A live Farengar test with 72 gold emitted
`WIZARD_TRAVEL_DENIED` and left the player in place.

### RUN-003 — LoreRim `IsPoison()` warning

**Status:** Proven harmless to travel

**Claim:** The `Nox_WAR_ThrowingKnife_PoisonApply.OnItemRemoved` error observed
when fare gold is removed is unrelated to wizard travel completion.

**Evidence:** The warning appeared during successful trips and was followed by
`WIZARD_TRAVEL_COMPLETE`.

### RUN-004 — Blue Palace audience marker arrival

**Status:** Proven

**Claim:** Persistent reference `0002C194:Skyrim.esm`
(`BluePalaceAudienceMarker`) is a safe Solitude arrival point in the installed
Blue Palace interior.

**Evidence:** A focused xEdit inventory confirms the reference is persistent,
uses `XMarkerHeading`, and is won and repositioned by
`JK's Blue Palace.esp`. The service's `SolitudeMarker` property resolves to the
exact reference in the independent plugin audit.

The monitored 2026-07-31 pass moved the player from Mirabelle to this marker;
the player reported that the arrival looked correct before continuing to
Sybille and returning to the College.

## Workflow claims

### TOOL-001 — Patched headless xEdit

**Status:** Proven

**Claim:** `build\xedit-patched\SSEEdit64.exe` can autoload a staged data set,
run project scripts without Module Selection input, write reports or plugins,
and exit after the script finishes.

**Use:** Prefer it for repeatable generation and audits. A successful script
must still be followed by semantic checks; xEdit accepting a field is not
proof that Skyrim will consider the record valid.

### TOOL-002 — Strengthened static dialogue audit

**Status:** Supported

**Claim:** The audit can reject unsupported donor structures before gameplay.

**Evidence:** The old audit verified only that `DNAM` resolved to an INFO with
matching text and therefore approved `00079AD7`. The generator and independent
audit now require the donor to have an EditorID, be a child of its declared
topic, and require that topic to be Misc dialogue with subtype name
`SharedInfo`. The archive audit separately checks the target voice-type FUZ.

**Limit:** Static validation cannot prove runtime choice eligibility, audio
playback, lip movement, or fragment execution; those remain live gates.

## Promotion gate for future claims

Promote a dialogue candidate to **Proven** only after all applicable checks:

1. The generated ESP passes the compact xEdit structure audit.
2. Every Shared Response Data donor is a genuine SharedInfo, not merely an INFO
   reference that xEdit accepts.
3. The expected FUZ exists for the actual speaker voice type.
4. Workspace and deployed payload hashes match.
5. The dialogue option and any linked submenu appear in live gameplay.
6. The expected response plays and the intended fragment executes.
7. Papyrus records the expected denial or paired start/complete traces.
8. The result and exact build identity are recorded in this ledger.

## Deferred Phase 1 ideas

- Trust, faction, disposition, and quest-based service gates.
- Map-based destination selection and Better Carriage Destinations integration.
- More College spokes beyond Whiterun, Riften, and Solitude.
- Travel-time passage, rest/recovery behavior, and intervention/recall magic.

These remain design goals, not implementation assumptions.
