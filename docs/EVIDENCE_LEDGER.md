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

The latest fully proven faculty-access wizard star is the six-node College,
Whiterun, Riften, Solitude, Windhelm, and Markarth network. Its ESP is SHA-256
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`.
The preceding Solitude checkpoint is commit `ae1dc5c`, whose ESP is SHA-256
`3F5C3BEBCBBD26DC70517A7943CF36E918942C57240736A3BFD3731EAB2D9550`.
Commit `4dfb646`, whose ESP is SHA-256
`4EEAED7C6556ADC159A128C9D95FB66124C3C90FC3FB9200D4CF7CC797567E89`, is the
earlier Whiterun/Riften faculty-access checkpoint.
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
The exact tested Solitude payload was historically packaged without
recompilation at
`dist\DiegeticTravelWizardGuides-phase1.zip`, SHA-256
`9D8004F580DB5FBE15DDA5F83FC594D6250C1DF56F06DAE175C41D3E0566A8A2`.

The proven Windhelm/Markarth extension adds Wuunferth and Calcelmo as inbound
guides and expands the faculty hub from three to five destinations. Both
Papyrus scripts compile with zero errors and warnings; the exact-record,
service-marker, and voice-asset audits pass. A corrected monitored gameplay
pass promoted DLG-010, RUN-005, and RUN-006 to Proven. The complete module is
deployed under `UltraDiegeticTravel`; all seven installed payload hashes match
the workspace, and the non-launching profile preflight passes. The exact
live-tested payload was packaged without recompilation at
`dist\DiegeticTravelWizardGuides-phase1.zip`, SHA-256
`55301E384F844661C0F5CE884115F54AD66E5039C965D5A99E3B95FF86086C7E`.

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

### DLG-010 — Windhelm and Markarth court-wizard spokes

**Status:** Proven

**Claim:** Wuunferth and Calcelmo can each expose the direct College route,
while the faculty hub can reliably expose five linked destination topics.

**Evidence:** The focused Skyrim/LoreRim inventory resolves Wuunferth as
`MaleOldGrumpy` NPC `00014146`, reference `0001B132`, and Calcelmo as
`MaleOldKindly` NPC `0001338E`, reference `00019908`. Vanilla ships the proven
`000DBA22` `Of course.` FUZ/LIP for both voice types. The generated plugin adds
exact-Wuunferth INFO `000816`, exact-Calcelmo INFO `00081A`, Windhelm DIAL/INFOs
`000813`/`000814`/`000815`, and Markarth DIAL/INFOs
`000817`/`000818`/`000819`. The independent audit verifies all speakers,
responses, five hub links, topic membership, OnBegin fragments, destination
IDs, and Mirabelle subtitle fallbacks. A second generator pass is byte-identical.

The first live build (`9B4545B8...`) completed Mirabelle-to-Windhelm,
Wuunferth-to-College, faculty-to-Markarth, and Calcelmo-to-College travel, but
also allowed Ancano reference `0001E7D8` to invoke `destination=college`.
Calcelmo and Ancano played another root's voice. This disproved `ANAM` as a
standalone eligibility gate. The corrected build adds an explicit subject
`GetIsID == 1` condition to every exact-speaker INFO, and the strengthened audit
requires exactly that one condition in addition to the expected `ANAM`.

The corrected monitored pass recorded five starts and five matching
completions: faculty `0001C1A1` to Markarth, Calcelmo `00019908` to the College,
Mirabelle `0001C1B9` to Windhelm, Wuunferth `0001B132` to the College, and
faculty `0001C1A8` to Whiterun. Ancano had no travel option and produced no
wizard-travel trace. The user confirmed that the tested voices matched their
speakers. Returning through Calcelmo and Wuunferth also demonstrated that both
arrival points left their wizard immediately accessible. Wuunferth's line was
slightly clipped before travel; timing polish is deferred while the final line
selection remains unsettled.

### DLG-011 — `ANAM` as a standalone speaker gate

**Status:** Rejected

**Claim:** Setting an INFO's `ANAM` speaker and removing its conditions limits
that top-level dialogue response to the named actor.

**Evidence:** In the monitored `9B4545B8...` pass, Ancano displayed the shared
court-wizard prompt and Papyrus recorded a complete College trip from his
reference `0001E7D8`. Ancano and Calcelmo also received the wrong donor voice,
showing that Skyrim could choose another eligible root INFO with the identical
prompt. The static audit had incorrectly passed because it checked `ANAM` but
not runtime eligibility conditions.

**Decision:** Every exact-speaker INFO must carry both the expected `ANAM` and
one subject `GetIsID == 1` condition. The generator and audit now enforce this
for all direct court-wizard roots and Mirabelle fallbacks.

### DLG-012 — Top-level branches expose their Starting Topic

**Status:** Supported

**Claim:** A new initial-menu prompt must be the `SNAM` Starting Topic of its
own top-level `DLBR`; merely assigning another topic to an existing top-level
branch does not add another initial-menu option.

**Evidence:** The first monitored map-adapter pass loaded the adapter at runtime:
`sqv DNT_WizardMapPickerQuest` showed running quest `AE000801`, the bound
`DNT_WizardMapPicker` script, the five exact world-map markers, the whitelist,
and the live core service property. Eligible faculty still displayed only the
proven list prompt, and Papyrus contained no `WIZARD_MAP_*` trace or adapter
binding error. The rejected build had linked `DNT_WG_OpenMap` to the core
faculty branch without making it that branch's Starting Topic. The Creation Kit
documentation states that a top-level branch contributes its Starting Topic to
the initial topic list.

**Decision:** The map adapter owns a separate non-blocking, non-exclusive
top-level branch whose Starting Topic is `DNT_WG_OpenMap`. The topic and branch
are both owned by the running adapter quest. The independent audit must reject
reuse of the core branch and require the two-way branch/topic links.

### DLG-013 — Insufficient-funds dialogue responses

**Status:** Proven architecture; remaining direct voice spot-checks pending

**Claim:** Mutually exclusive player-gold conditions can prevent an affirmative
terminal response from playing before the service denies a fare, while genuine
vanilla SharedInfos provide correct voiced refusals for most direct court
wizards.

**Evidence:** A read-only headless-xEdit scan of Skyrim and all three official
DLCs found genuine fare-refusal SharedInfos and separately rejected 170
ordinary dialogue matches. Skyrim `000C6E2D` says `I'm sorry, but you don't seem
to have enough gold to pay for that.` and has exact FUZ files for 5/13 target
voice types. HearthFires `0000B0B2` says `I'm sorry, but you can't afford that
right now.` and covers four types. Their union covers eight distinct types,
including Farengar, Wylandriah, Sybille, Calcelmo, and seven of twelve permanent
faculty. No semantically suitable genuine SharedInfo covers `MaleOldGrumpy`,
`MaleSlyCynical`, `FemaleElfHaughty`, `FemaleShrill`, or Mirabelle's unique
voice. The existing carriage generator already authors inverse player
`GetItemCount Gold001` conditions with a server-side payment recheck.

The generated candidate now implements all ten denial INFOs. A second generator
pass was byte-identical at ESP SHA-256
`3D469B2441FFEBCC0AF57D4F77ADB3FE49B940C56707C0B027133EE6799A2CA5`.
The exact-record xEdit audit passes against both the workspace and deployed
LoreRim copies, including the inverse gold ranges, PlayerRef execution, genuine
SharedInfo topic membership, three-INFO destination topics, terminal fragments,
and unchanged service bindings. The vanilla archive audit passes every used
affirmative and denial FUZ, and the independent map-adapter audit still passes.
The separately named candidate package is
`dist\DiegeticTravelWizardGuides-fare-denials-candidate.zip`, SHA-256
`45219F0C475EF0EAE020F6BE332F761E44E3376BC0E332F6A5B017D55EBFB793`.
The monitored 2026-07-31 candidate pass then proved the implemented split in
gameplay. Farengar denied College travel at 22 gold with the intended voiced
Skyrim refusal; the user described the line as great. Sybille denied at zero
gold with the intended voiced HearthFires refusal and the user confirmed it
worked. Each denial emitted one `WIZARD_TRAVEL_DENIED` and no start/completion;
after funding, both speakers produced a normal 250-gold start/completion pair.

College text-submenu denials from Mirabelle and multiple faculty emitted direct
denial traces with no preceding map trace and no later start/completion. Tolfdir,
Nirya, and Sergius were silent as designed because the current College branch
uses one destination-level forced-subtitle fallback. Map selections at 22 and
zero gold were likewise silent/notification-only and denied cleanly. Funded map
trips to Whiterun and Solitude completed normally. The listener observed four
successful trips and no wizard-script warning. Wylandriah and Calcelmo retain
statically verified exact FUZ coverage but were not voice-checked in this pass;
Wuunferth remains intentionally subtitle-only.

**Implemented candidate decision:** Gold-condition only terminal INFOs, not the
College hub.
Keep funded affirmative INFOs at `>= 250`; add denial INFOs at `< 250` that call
the same service. Voice Farengar, Wylandriah, Sybille, and Calcelmo through the
verified donors; use an owned forced-subtitle denial for Wuunferth and one
subtitle denial per College destination. Keep the map path notification-only.
See `docs\WIZARD_FARE_DENIAL_VOICES.md` for the full matrix and rejected lines.

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

### RUN-005 — Wuunferth lab marker arrival

**Status:** Proven

**Claim:** Persistent reference `000A3F1C:Skyrim.esm`
(`WindhelmWuunferthLabMarker`) is a safe arrival point in the installed Palace
of the Kings Upstairs interior.

**Evidence:** A focused xEdit inventory identifies the reference as a
purpose-named persistent `XMarker` beside Wuunferth's lab. Its winner among the
loaded Skyrim, USSEP, JK, and Snazzy interior records is USSEP. The independent
plugin audit verifies that `WindhelmMarker` resolves to this exact reference.

**Gameplay evidence:** The corrected monitored pass completed Mirabelle to
Windhelm and then Wuunferth back to the College. The successful immediate
return conversation demonstrates a usable arrival with convenient access to
Wuunferth.

### RUN-006 — Calcelmo vendor marker arrival

**Status:** Proven

**Claim:** Persistent reference `0003692A:Skyrim.esm`
(`MarkarthCastleWizardVendorMarkerREF`) is a safe arrival point beside Calcelmo
in the installed Understone Keep interior.

**Evidence:** A focused xEdit inventory identifies the reference as a
purpose-named persistent `XMarker` adjacent to Calcelmo's persistent actor
reference. Its winner among the loaded Skyrim, USSEP, JK, and Snazzy interior
records is Skyrim.esm. The independent plugin audit verifies that
`MarkarthMarker` resolves to this exact reference.

**Gameplay evidence:** The corrected monitored pass completed a faculty trip
to Markarth and then Calcelmo back to the College. The successful immediate
return conversation demonstrates a usable arrival with convenient access to
Calcelmo.

### RUN-007 — Exterior College hub marker

**Status:** Proven

**Claim:** Persistent reference `00046BDF:Skyrim.esm`
(`WinterholdCollegeMapMarkerRef`) is a better College hub arrival point than
Phinis's private-room sleep marker.

**Evidence:** A focused headless-xEdit inventory places the reference at
`116258.921875,111530.132812,-7719.998536`, beside the exterior College tour
and Mirabelle quest-marker cluster. It is a vanilla `MapMarker` reference with
no override among the loaded Skyrim, USSEP, and JK's College records. The
candidate core ESP binds its sole `CollegeMarker` property to this exact
reference, and the independent wizard-star audit passes. The ESP is
byte-idempotent at SHA-256
`AC92D9C14E7E9BFAB9DC09C28A4112014CF069C1536336B652C43EF698E54374`.
The exact candidate payload is
`dist\DiegeticTravelWizardGuides-exterior-college-candidate.zip`, SHA-256
`E958E0AD2B43F282A9C214FEFFBABA5097601F77566DAB5789DB92C0C6625F0B`.

Existing saves may retain the old quest-script property even after the ESP
binding changes. The candidate service therefore resolves
`00046BDF:Skyrim.esm` through `Game.GetFormFromFile` when the College marker is
first requested, replaces a stale property, and emits
`WIZARD_TRAVEL_MIGRATE`. New games still receive the audited VMAD binding.

**Gameplay evidence:** In the monitored 2026-07-31 pass, the existing save
emitted exactly one `WIZARD_TRAVEL_MIGRATE property=CollegeMarker` trace before
Wylandriah completed the first return to the exterior marker. A later Farengar
return completed without another migration. The user confirmed that the public
arrival location was usable, then completed College-to-Whiterun and
College-to-Riften map trips. Arrival preserves the player's pre-teleport facing
because the service does not force a rotation; this was acceptable in the live
test.

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

The map-adapter audit additionally requires a dedicated top-level branch, the
map prompt as that branch's Starting Topic, matching adapter-quest ownership,
and a topic backlink to the same branch. This closes the static hole exposed by
the first monitored map-adapter pass.

### UI-001 — BCD as a wizard selection-only map adapter

**Status:** Proven

**Claim:** A separate adapter can call BCD's native filtered MapMenu, translate
one of five selected world-map marker references to the wizard service's stable
destination ID, and leave fare and movement under the proven core service.

**Evidence:** BCD repository HEAD on 2026-07-31 is commit
`136dc7b3ad9754877c485fd5cea29550af108888`, matching the source already cited
in the compatibility notes. The installed BCD 1.0.10 Papyrus source confirms
that its carriage quest registers for `BCD_SetDestination` only inside its own
`OpenMap`; the adapter instead calls the lower-level native
`BCD_Utils.OpenTheMap`. A headless xEdit inventory resolved the exact Whiterun,
Riften, Solitude, Windhelm, and Markarth map-marker references. Both adapter
scripts compile with zero errors and warnings.

The first monitored build, ESP SHA-256
`85AE4DEF45B94894D92499654499347CD0C0B380A8969B14113F40CFC324A9EA`, is rejected
for reusing the core top-level branch without becoming its Starting Topic. The
adapter quest loaded at runtime but no map prompt appeared and no map trace ran.
The corrected candidate owns a dedicated top-level branch and is byte-idempotent
at ESP SHA-256
`74D1EF6F6268BFAF5CCC12FA3D6CF4B074790ECC655A233E0AA4481132A08FE4`. Its first
successful live pass used core ESP
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`; the
independent adapter audit also passes against the exterior-College candidate
core `AC92D9C1...E54374`. The audit checks both integration masters, the
five-entry whitelist, seven quest properties, faculty eligibility, dedicated
branch ownership and Starting Topic, and the OnBegin picker fragment. The
corrected candidate package is `dist\DiegeticTravelWizardMapAdapter-alpha.zip`, SHA-256
`F55A9B42C6DF05F90A612DEC25168D43CC748C5CD36B3E1F80920B84E6BA3D95`.

**Gameplay evidence:** With the corrected adapter unchanged, the prompt became
visible after the game saved once with the adapter installed and then reloaded
that save. At 32:9, Mirabelle opened the map and selection of Solitude emitted
`WIZARD_MAP_OPEN`, `WIZARD_MAP_SELECT destination=Solitude`, and exactly one
matching `WIZARD_TRAVEL_START` / `WIZARD_TRAVEL_COMPLETE` pair at fare 250.
Sybille then completed the College return. Phinis repeated the map flow to
Riften, followed by a successful Wylandriah-to-College return. No
`WIZARD_MAP_REJECT`, `WIZARD_MAP_DENIED`, or DNT travel failure appeared. A
preceding run with the same adapter installed completed the retained dialogue
list from Faralda to Windhelm and Wuunferth back to the College.

The same monitored session then proved cancellation and filtering. Closing the
map without a selection emitted `WIZARD_MAP_CANCEL`, removed no gold, and left
the player in place. Attempting a non-whitelisted marker produced another clean
open/cancel pair with no select or travel trace. The user confirmed that only
the five intended markers were selectable and that Ancano had no map prompt;
Ancano correctly produced no DNT trace because dialogue eligibility rejected
him before the picker script ran.

The final monitored pass proved both fare-feedback paths. A funded faculty map
trip selected Whiterun and emitted one start/completion pair. A direct Farengar
request with 22 gold emitted
`WIZARD_TRAVEL_DENIED reason=gold required=250 available=22`; after funding,
the same route emitted one start/completion pair. Mirabelle then opened the
map, selected Windhelm, and emitted `WIZARD_MAP_SELECT` followed by
`WIZARD_TRAVEL_DENIED reason=gold required=250 available=22`, with no later
start or completion. The user confirmed that denials displayed the top-left
notification, removed no gold, played no payment cue, and caused no movement;
successful payment played vanilla `ITMGoldDown` and travel completed.

**Candidate under test:** Dialogue terminal INFOs now use mutually exclusive
player-gold conditions, with genuine voiced refusal SharedInfos where exact FUZ
coverage exists and forced-subtitle fallbacks elsewhere. The service remains the
authority and the map path remains notification-only because selection occurs
after dialogue closes. Do not call the semantic mismatch fixed until the new
candidate passes the monitored denial and funded-regression checks.

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
- Per-voice College fare denials beyond the current destination-level subtitle
  fallback, if the added record complexity proves worthwhile.
- More College spokes beyond Whiterun, Riften, Solitude, Windhelm, and Markarth.
- Travel-time passage, rest/recovery behavior, and intervention/recall magic.

These remain design goals, not implementation assumptions.
