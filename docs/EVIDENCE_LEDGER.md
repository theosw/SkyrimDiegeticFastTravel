# Diegetic Travel evidence ledger

Updated: 2026-08-21

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

## 2026-08-21: Hearthfire private-carriage parity

**Supported:** read-only inspection of LoreRim's installed `CFTO.esp` proves
that Gunjar (`0x0CB329`), Engar (`0x0CB32A`), and Markus (`0x0CB32B`) are the
distinct Lakeview, Windstad, and Heljarchen carriage-driver bases and that all
three belong to `KmodCarriageFreeFaction` (`0x0DA68B`). CFTO's free dialogue
root supplies the same shared voiced request used by DNT. The rejected behavior
was downstream origin resolution: DNT played that response and then denied the
speaker because it knew only public physical drivers and WCI actors.

**Candidate:** the coordinator now requires the existing free-faction check
and maps those exact three bases to their existing quest-locked catalogue
origins. The picker checks this private path before WCI and passes a free-ride
quote through the unchanged purchase/travel service. No new forms, quests,
properties, dialogue, voice assets, or Papyrus scripts are introduced. Native
tests cover the three source IDs, quest-locked classification, and zero-fare
quotes; source/package audits cover the lookup order; and xEdit independently
proves the installed driver records and faction. The full offline release suite
passes with the same `0xAA5` next-object boundary.

The exact unproven candidate is `0.1.0-beta-20260821T170220Z`: main SHA-256
`B7BAA7AF9078977CB7139AB86B584591786F1B2AD2FD636F8C8926DA1EEED22E`,
Baan Malur add-on
`DEA28808CE671CE81CFFFF098ADB73D2A611EABFBAF148DD5DF7B7A8B1777094`, and
LoreRim BCD coexistence
`F677C11810206AF9B230FCDEAFC664CAABEFF00CA843F8FA4385010AF764CFDC`.
Promotion requires monitored map opens from all three personal drivers, correct
source/free labels, one completed trip without a gold deduction, and clean
acceptance/purchase/completion logs. Until then, the earlier `233726Z` release
remains the fully proven baseline.

The complete `170220Z` set is now active in `UltraDiegeticTravel`. Installed
inventories compare exactly to the audited package roots at 74/74, 9/9, and
2/2 files. The previous set remains installed but disabled, the BCD/WCI/CFTO
chain remains enabled, the functional plugin list retains SHA-256
`61F6EFEF2BA7893A577B83432340658C63D19EA47199F94B95E71E9E811F750E`, and the
non-launching consolidated-profile preflight passes.

## 2026-08-21: archived artwork fallback and preference proof

**Proven:** candidate `0.1.0-beta-20260820T233726Z` loaded
`PreferFormalMapArtwork=false` and successfully exercised the native archive
bridge in the monitored `UltraDiegeticTravel` profile. With the preferred loose
artwork hidden, the native runtime materialized Bethesda's archived
`battlemap01.dds` for Whiterun's carriage sheet, the Dawnstar north-coast ferry
sheet, and the College sheet, plus archived `dlc2mapsolstheim02.dds` for the
Raven Rock Solstheim sheet. The transformed College and carriage layouts, ferry
layout, selection, cancellation, payment, and travel paths all behaved as
designed. The College-to-Markarth trip charged 250 gold and completed; the
Dawnstar-to-Windhelm ferry trip charged 50 gold and completed. Whiterun and
Solstheim cancellation via Escape restored the HUD cleanly.

First-frame times were 133.954 ms for the first Whiterun archive/cache open,
41.222 ms for the north-coast ferry, 24.115 ms for Solstheim, and 25.533 ms for
the College. Baan Malur remained isolated from the fallback system: its sheet
used its external FWMF `solstheim.dds`, opened in 56.560 ms, and cancelled
cleanly. The native log contained no warning, error, missing, or rejection
entry during the matrix.

The exact main archive is SHA-256
`06A139A65372AE801D9945DB9CD73923BF13A1F0380FE7EFFD961C0165EC68A9`;
the Baan Malur add-on is
`39B495E017569D0D56494C8A6AC7BC26ED281B94DE68892439C504C81BE88675`;
and LoreRim BCD coexistence is
`3846D799164344B3707C7464CADF82F7BEDD4ACF8E1043DBCE771C7F075FA71F`.
Package/install comparison passed 74/74 main files, 9/9 add-on files, and 2/2
compatibility files. The `233726Z` set remains active, while the test override
and older candidate are disabled. RUSTIC's DDS files and
`PreferFormalMapArtwork=true` have been restored. The functional plugin list
and order are unchanged after MO2 normalized its generated header and line
endings.

**Proven:** the final restored-preference smoke loaded
`PreferFormalMapArtwork=true`, opened the north-coast ferry sheet from the
preferred `battlemap01.dds`, and completed Dawnstar-to-Winterhold for 50 gold.
It then opened the College sheet from the preferred `skyrim.dds` and completed
College-to-Morthal for 250 gold. First-frame times were 71.380 and 193.473 ms;
both requests restored all 12 HUD layers. The native picker log contains 107
info entries and zero warnings, errors, or critical entries. Papyrus records
both travel completions; errors adjacent to the travel events identify
unrelated LoreRim throwing-knife, Falmer-tracking, predator, critter, and
ice-wraith scripts rather than DNT. The exact candidate has now passed both
artwork preferences and is approved for the timestamped annotated tag
`v0.1.0-beta-20260820T233726Z`. Preserve the earlier `v0.1.0-beta` tag as
immutable history.

## Current decision

The latest fully proven faculty-access wizard star is the six-node College,
Whiterun, Riften, Solitude, Windhelm, and Markarth network. Its ESP is SHA-256
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`.
The current eight-node wizard extension adds Madena/Dawnstar and Falion/Morthal
without changing the College-centred topology. Offline evidence proves seven
exact-speaker direct routes, seven hub links, every funded/denial condition
pair, service fragments, runtime marker migration, both new success voice
assets, both direct-wizard refusal assets, and the seven-destination parchment
contract.
Both wizard Papyrus scripts and all three parchment scripts compile with zero
errors and warnings; the native test, independent xEdit audits, and zero-
bundled-asset audit pass. A monitored 2026-08-01 run recorded four clean trips:
Madena and Dawnstar passed, Falion's denial/funded travel branches executed, and
the Morthal parchment selection handed off correctly. The original Morthal map
marker is Rejected because it landed on COTN roof geometry. A full-profile VFS
xEdit audit identified unoverridden ground-level
`MorthalCarriageEastDestinationMarker` (`0EB7CC`) as the replacement, and the
next monitored pass proved its ground-level arrival. Falion's funded travel
completed again but its confirmation remained silent. Direct BSA extraction
proves that the selected FUZ is valid, distinct, non-silent audio lasting 0.93
seconds. A 1.75-second follow-up produced only "course," disproving end cutoff;
the payment sound began at the exact response start and is the stronger masking
candidate. All thirteen success clips are at most 1.11 seconds. The rebuilt
service waits 1.5 seconds, plays the payment sound with `PlayAndWait`, then
moves the player. xEdit and BSA inspection also found genuine SharedInfo
`CantBeHelped` (`000DBA24`) with a distinct 1.35-second `MaleSlyCynical` FUZ for
Falion's denial. A focused monitored live check proved the full lip-synced
denial, the full funded confirmation, payment cue, and completed travel. The
voice/payment sequencing is Proven. The two new crest alignments still need
confirmation.
Its wizard ESP is SHA-256
`174CD2B86AC08693C4B708CDB1141190B5093F2BC6C594BCBE03916840D47B56`;
the separately named package is
`dist\DiegeticTravelWizardGuides-seven-spoke-candidate.zip`, SHA-256
`29844E10D041790F0898B564B939DC562AFE1001EED008E6F9053F970E233F86`.
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

### PARCH-001 — Provider-neutral parchment destination picker

**Status:** Proven (core interaction, original five-route layout, visibility,
and startup/cursor polish); Candidate (Dawnstar/Morthal extension)

**Claim:** A blocking SKSE Menu Framework window can present provider-supplied
map artwork and normalized destination markers, return only a selection index,
and leave wizard fare/payment/movement exclusively in the proven core service.

**Offline evidence:** The AE DLL builds cleanly; the three Papyrus scripts
compile with zero errors and warnings; C++ tests preserve provider art aspect
and centered safe-canvas layout at 16:9, 21:9, and 32:9; all 26 dynamically
resolved functions exist in LoreRim's installed SKSE Menu Framework 3.9 DLL;
and Champollion readback verifies the embedded artwork configuration and
capitalized labels. The separate generated ESP passes an independent
headless-xEdit audit, masters the wizard core but not BCD, and regenerates
byte-identically at SHA-256
`90DB9BF3FFE1823D0403D4739BF694B8FACC89E498276C66363C5E3C4D760E0B`.
The current candidate archive is
`dist\DiegeticTravelParchmentPicker-offline-candidate.zip`, SHA-256
`CA785A6BDE17AC9F0A11D262920A731439FCCD9B9EE33201B1537F7EDDD059EC`,
and contains zero artwork/audio assets. Its forced-subtitle native DLL is
SHA-256
`1F0E2C1DB15896614582618CC63BDBB8169D76E99B9DC4FE80A42F3FCB800043`.

**Gameplay evidence:** After the known custom-dialogue compatibility save and
reload, a monitored 32:9 pass opened the RUSTIC parchment four times with the
configured `(0,0)-(1,0.75)` crop. The original rectangular selection layer was
usable; a later visible-ring pass showed that its approximate centers did not
precisely surround several printed crests. Native logs recorded button
cancellation, a funded Whiterun selection and result-event handoff, plus
underfunded Whiterun and Solitude selections.
The service charged/moved nothing for both denials and completed the funded
route. Papyrus recorded two completed trips; neither log contained native or
script errors/warnings. The runtime dynamic API identified itself as version
3.7 even though the installed framework file is labelled 3.9.0.

A later monitored pass displayed `Whiterun - 250 gold` correctly and completed
a funded Solitude selection. Native and Papyrus logs agreed on destination,
fare, and successful completion. This promotes the ASCII footer and a funded
non-default destination to Proven.

**Rejected HUD attempt:** The same pass logged the single vanilla `HUD Menu`
movie being hidden and restored, but the screenshot retained LoreRim's
bottom-left TrueHUD/STB interface. A vanilla-only visibility toggle is therefore
rejected for this profile.

**Proven HUD replacement:** Local source/config inspection shows Norden
enables TrueHUD's player widget and LoreRim's Ultimate Immersion Toggle controls
`HUD Menu`, `TrueHUD`, `lvlWidget`, `goldWidget`, STB, and related movie roots
through `_root._alpha`. The deployed replacement saves visibility and numeric
root alpha independently for each present optional movie, then restores those
exact values. It changes no installed-mod configuration. In the monitored pass,
the user confirmed no HUD remained over the parchment; native logs recorded 12
present layers hidden from visibility/alpha 100 and restored exactly. Markarth
selection and travel then completed with no native or Papyrus errors.

**Presentation evidence and candidate:** Rectangular destination buttons are
replaced by large invisible hitboxes over the baked city crests. The first
small-ring positions visibly missed several baked crests and are rejected.
Texture inspection also found that the 0.75 crop included approximately 56
rows of opaque backing below the useful parchment edge. A later gameplay pass
proved crop max `0.736328`, aspect `1.358090`, all five corrected crest centers,
the Winterhold route origin, five spokes, and route selection at 32:9; the user
confirmed that everything was in the right spot. That pass rejected the quiet
idle styling as too hard to see and the yellow pointer as unlike LoreRim's
other screens.

The live-tested revision uses visible rings at 46% of the hitbox, strong gold for all
idle rings/routes, and red for only the hovered or controller-focused route
and ring. Inspection of the active `Norden UI 16x9` `cursormenu.swf` established
the target arrow silhouette and monochrome palette. Because Menu Framework's
ImGui layer renders after Skyrim Scaleform and cannot place the exact SWF
cursor above the parchment, the candidate redraws that appearance with
polyline and concave-fill primitives. It copies and ships no cursor asset.
LoreRim's exact installed DLL exports every required function. The monitored
pass visually approved the gold/red presentation and confirmed that the new
monochrome cursor appeared. Native logs recorded one clean cancel and then a
Markarth selection; Papyrus recorded the matching 250-gold start/completion.
All 12 HUD layers restored exactly, Skyrim exited normally, and no DNT
error/warning appeared.

The apparent initial Whiterun highlight was an explicit first-item navigation
focus, not a selected destination. The polish candidate removes that default,
shows retained focus only after keyboard/gamepad input, and lowers the dark
cursor-center alpha from 245 to 150. Native build, Papyrus, xEdit, static asset
audit, and offline tests pass. All six deployed runtime payloads match the
workspace, and its non-launching `UltraDiegeticTravel` preflight passes after
switching back from the parallel profile.

The monitored polish pass visually approved both requested changes: no route
was active at startup and the translucent cursor center looked good. The run
completed a parchment trip to Markarth and Calcelmo's direct return to the
College. Two subsequent parchment opens proved Escape cancellation and the
close button respectively. Every selection/cancel restored all 12 HUD layers
to visibility/alpha 100, Skyrim exited normally, and no DNT error/warning
appeared. This promotes the startup gate, cursor alpha, and Escape path to
Proven.

**Formal wizard-map result:** The first Caro/FWMF pass exposed a stale saved
quest auto-property: the new crop and hold icons loaded, but native logging
showed the old `battlemap01.dds` path at `PARCHMENT_OPEN`. The provider now
passes the formal texture path through the same local effective profile as its
crop and aspect. The follow-up 32:9 pass visually approved the formal Caro map,
all eight opaque vanilla hold icons, exact College/capital alignment, and
destination-preserving hover state. Native logging confirmed
`Data/textures/terrain/tamriel/skyrim.dds`, all seven destination textures, and
12 HUD layers hidden/restored. Papyrus recorded a 250-gold Whiterun start and
completion. No DNT warning/error appeared. This promotes the formal wizard-map
profile and mouse-selected funded journey to Proven.

**Mirabelle presentation voice result:** Mirabelle's unique voice type has
no matching generic SharedInfo asset, while the exact desired INFO belongs to
`MG01`, a quest that stops after First Lessons. The first direct-FUZ experiment
used ConsoleUtil selection followed immediately by `ExecuteCommand`; source
inspection shows the selection is queued through Skyrim's UI message queue but
the command reads the current selected reference synchronously. Two live
attempts logged the Papyrus request but produced no Mirabelle audio, so this
selection-based architecture is Rejected. The replacement native `PlayVoice`
call resolved the actor on the game thread and invoked CommonLibSSE-NG
`Script::CompileAndRun`. The live test then crashed at 01:58:36 before map
`Show`; CrashLogger's probable stack names `DNTParchmentPicker.dll`,
`Script::CompileAndRun`, Papyrus.cpp line 132, Mirabelle `0001C1B9`, and the
exact `SpeakSound` path. No `PARCHMENT_VOICE_DISPATCH` was logged. Source
comparison explains the failure: this CommonLib build maps AE to relocation ID
`21890`, whereas OStim NG uses ID `441582` on runtime patches 1.6.1130 and
newer. The actor-targeted stock-CommonLib path is therefore Rejected on
LoreRim's 1.6.1170 runtime. A subtitle-only fallback with no runtime voice
command was rebuilt, audited, deployed byte-for-byte, and profile-preflighted.

**Isolated corrected-relocation candidate:** The configured CommonLib checkout
is official upstream commit `b93280e832f263dbef44e44cbe2936622a02f91a`;
the problem is its still-stale convenience-method relocation, not an accidental
fork or dependency downgrade. Direct decoding of LoreRim's exact Address
Library 11.0.0 database proves ID `21890` is absent, the next ID `21891`
resolves to the rejected crash address `0x33D880`, and modern ID `441582`
resolves to `0x33D6A0`. `dependencies.lock.json` pins the Skyrim, SKSE,
Address Library, Menu Framework, RUSTIC MAPS, wizard-core, CommonLib, and vcpkg
inputs by version/commit and hash; the read-only dependency audit passes.

The new Candidate bypasses only CommonLib's stock `Script::CompileAndRun`
method. It refuses any runtime other than 1.6.1170, refuses any resolved offset
other than `0x33D6A0`, and whitelists only Mirabelle reference `0001C1B9` plus
the exact installed MG01 FUZ path. Its first test branch returns before request
creation and map `Show`, so a Mirabelle prompt can test voice dispatch without
involving Menu Framework. Other faculty retain the proven map path. Native
build/tests, three zero-warning Papyrus compiles, source/package constraints,
and the independent xEdit adapter audit pass. This is not gameplay-proven.
The archive SHA-256 is
`0543BCB990EED393BDBF16AF4EBD6D5F72BDEEB5F685CAFF17EBA58C1B7AE21C`.
All six deployed runtime files match the workspace byte-for-byte, and the
non-launching `UltraDiegeticTravel` preflight passes. No game was launched.

**Focused gameplay result:** The 2026-08-02 monitored pass dispatched the
corrected relocation four times at ID `441582` / offset `0x33D6A0`. The player
heard the matching Mirabelle line with proper lip sync, Skyrim exited normally,
no new crash report was created, and neither native nor DNT Papyrus logging
reported an error. This promotes the relocation, actor targeting, FUZ path,
audio, and lip sync to Proven. The pass also exposed a sequencing defect: the
subtitle-only INFO completed a silent subtitle/lip-sync presentation before
`OpenMap`'s dialogue-close wait queued the proven voice. The follow-up Candidate
moves only the Mirabelle probe ahead of that wait, directly into the INFO
OnBegin path; it remains map-suppressed and requires focused timing verification.

The focused timing pass then fired two clean probes. The player confirmed that
the voice now starts at the intended moment and lip sync remains correct;
Skyrim exited normally, no new crash report appeared, and DNT logs were clean.
This promotes the OnBegin timing to Proven. Pausing the Fuz Ro D-oh-generated
silent response also removes its subtitle, and `SpeakSound` does not create a
replacement, so the audible line had no subtitle. The next Candidate inserts
the exact matching text into Skyrim's normal `SubtitleManager` immediately
after proven playback begins. It uses the manager's own spin lock, Mirabelle's
speaker handle, squared distance zero, and forced-display flag; it does not
draw custom HUD text. LoreRim's active Fuz Ro D-oh and Lingering Subtitles Fix
remain untouched.

The focused subtitle pass then produced two clean Mirabelle probes. Both native
dispatches resolved relocation ID `441582` to `0x33D6A0` and logged
`subtitleAdded=true`; the player confirmed that subtitle, voice, and lip sync
worked together. Skyrim exited normally, no new crash report was created, and
no native or DNT Papyrus warning/error was recorded. This promotes normal
subtitle-manager insertion and visible display to Proven. Subtitle
lifetime/cleanup was not separately reported and remains a minor regression
check.

**End-to-end Mirabelle handoff Candidate:** Direct extraction from the locked
vanilla voice BSA measures the exact MG01 XWM payload at 2.147846 seconds. The
provider now reserves a 2.35-second presentation window after the proven
OnBegin voice/subtitle dispatch, then enters the existing dialogue-close and
parchment `Show` path. It marks the request as opening before waiting to prevent
re-entry. If native voice dispatch is rejected, travel remains available via a
map fallback. Native tests, three zero-warning Papyrus compiles, the independent
xEdit audit, dependency audit, and zero-bundled-asset audit pass. The complete
voice -> subtitle -> map -> travel sequence needs one focused gameplay test.

**Compatibility evidence:** The new dialogue branch initially remained absent
until the user saved and reloaded once with the adapter installed. Quest
stop/start did not resolve that live session. The Creation Kit Wiki discussion
documents the same custom-dialogue save/load workaround:
https://ck.uesp.net/wiki/Talk%3ABethesda_Tutorial_Dialogue

**Remaining boundary:** Keyboard/controller destination activation,
controller-B cancellation, missing-art fallback, and the old dialogue fallback
remain unproven for this adapter. Controller work is deliberately deferred
while both controller mods are disabled; test only with the intended
`No Delete Controller` compatibility stack enabled.

**Use:** The provider-neutral picker is valid for continued wizard-guide
development. Keep the BCD adapter and seven-choice dialogue path as regression
fallbacks until the remaining input and fallback cases are exercised.

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

**Claim:** A terminal INFO fragment running on `OnBegin` can charge immediately,
reserve 1.5 seconds for dialogue, play the payment cue with `PlayAndWait`, and
then move the player without overlapping either audio source.

**Evidence:** Farengar, Wylandriah, Whiterun, and Riften routes have completed
with paired `WIZARD_TRAVEL_START` and `WIZARD_TRAVEL_COMPLETE` traces. The
sequential audio revision is statically supported and awaiting its focused live
gate.

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

**Status:** Archived after proof

The experiment proved that a separate adapter could use BCD as a filtered
selection surface while leaving fare and movement under the wizard service.
The physical parchment picker superseded it. Its source, binaries, and
dedicated pipeline remain recoverable from Git history before repository
cleanup; they are no longer part of the maintained architecture.

## 2026-08-02 offline provider and authoring checkpoint

**Claim:** The gameplay-proven Mirabelle playback/subtitle mechanism can be
expressed as a provider-neutral presentation contract without weakening its
runtime guard or coupling it to selection/payment/movement.

**Offline evidence:** `PlayPresentation` now validates actor, installed
`Voice/*.fuz` path, subtitle, and finite measured duration; holds an
`ObjectRefHandle` through the queued task; and returns duration plus a
0.20-second margin. Pure tests accept Mirabelle's measured contract and reject
command delimiters, traversal, wrong roots, subtitle controls, and invalid
durations. The native build, three Papyrus compiles, dependency lock, exact
Address Library relocation check, independent parchment xEdit audit, BCD
adapter audit, and zero-bundled-art/audio audit all pass. This revision was not
deployed while a separate Skyrim test was active and is not gameplay-proven.

**Claim:** The patched xEdit CLI can build the carriage alpha without Module
Selection or UI automation once the generator itself uses supported record
operations.

**Offline evidence:** The prior failure was reproduced at the generator's
attempt to rewrite `ALFR` after copying a complete Specific Reference quest
alias union. xEdit 4.1.5f rejects editing that union container. The assignment
was redundant because `ElementAssign` had already copied the player alias; its
removal allows the script to complete headlessly. The launcher now defaults to
the patched executable, uses a hidden window, records compact failure detail,
and stops only its own process if a failed script leaves a hidden dialog. The
full carriage build produced 29 stops, 812 ordered routes, 11 SEQ quest IDs,
six warning-free Papyrus compiles, and no lingering xEdit process.

Final workspace packages:

- carriage alpha: `9D729A230725A984AEB510180C472EF6EDCDEAF5FF26FAB4238D2E4D7A5B979A`;
- parchment offline candidate: `CC90A93C56A65AC3601126EFCD97E09BD4BDA547889B6FEBEAE294024A4B7671`;
- wizard guides: `0F5BF619466BF2A8E72345CBB9C9DFC43D8E561E95F768674CA3E72165E83C55`;
- optional BCD wizard adapter: `CDFF6A1F4297B77073B50526FFED4A2B71B8AE6781E973EBCBBB6CCC99A41994`.

## 2026-08-02 Lake Honrich live vertical-slice checkpoint

**Claim:** The provider-neutral parchment contract can drive CFTO's public
Lake Honrich lane without replacing its ferrymen, live local fare, arrival
markers, or time-passing travel execution.

**Gameplay evidence:** The monitored pass resolved Thalldar at Heartwood Mill,
Haennr at Ivarstead, and Heirmir at Riften. Each provider displayed exactly the
other two lane stops. The player completed Heartwood -> Ivarstead, Ivarstead ->
Riften, and Riften -> Heartwood; each emitted one matching
`BOAT_TRAVEL_START` / `BOAT_TRAVEL_COMPLETE` pair at CFTO's current 30-gold
fare. A Heartwood cancellation was inert. Requests with 0 and 10 gold emitted
`BOAT_TRAVEL_DENIED reason=gold required=30` with no start or movement. The
native picker restored all twelve hidden HUD layers after selection/cancel,
and neither DNT nor CrashLogger recorded a failure. PickUpAsJunk RC1 remained
loaded and recorded successful world/container junk actions in the same run.

**Rejected handoff:** The first deployed picker waited for `Dialogue Menu` to
close but could not request closure. Heartwood and Ivarstead therefore required
manual Escape before the parchment appeared; Riften dismissed dialogue
normally. Once unblocked, native `PARCHMENT_BEGIN` and `PARCHMENT_OPEN` were
separated by only tens of milliseconds, which rules out the renderer as the
source of the delay.

**Proven handoff:** `RequestDialogueClose` now queues Skyrim's normal
`UI_MESSAGE_TYPE::kHide` message only for `Dialogue Menu`. The boat OnEnd
provider requests that transition, polls for confirmed closure, and logs the
requested/already-closed/completed/timeout path plus wait ticks before opening
the parchment. It does not synthesize Escape input. The locked CommonLib build,
native unit test, six affected zero-warning Papyrus compiles, source audit,
independent boat xEdit/SEQ audit, exact ferryman/FUZ audit, and zero-asset
package boundary pass.

**Follow-up gameplay evidence:** Riften, Ivarstead, and Heartwood each emitted
`BOAT_DIALOGUE_HANDOFF_CLOSE_REQUEST`, native
`PARCHMENT_DIALOGUE_CLOSE_REQUESTED`, and
`BOAT_DIALOGUE_HANDOFF_COMPLETE ... closeRequested=TRUE waitTicks=0`. The
picker then opened about 0.2-0.3 seconds later without manual Escape. The player
completed Riften -> Ivarstead, Ivarstead -> Heartwood, and Heartwood -> Riften;
all three trips charged the live 30-gold fare and emitted matching start/
complete pairs. There was no DNT failure, timeout, rejection, or crash. Together
with the first pass, all six directed trips among the three public stops are
gameplay-proven. Heartwood follower/horse placement remains unverified.

Candidate packages:

- parchment runtime: `31BC0AD4A7C84E43D4E11BF0A7A30F5B0794C23C358F0991AB12A8D62EC085E4`;
- Lake Honrich boat: `2929CEA27215DA5483299DB73DDC694143F442573CA8F8068CAE2A499BE3006B`.

## 2026-08-02 Lake Ilinalta offline candidate

**Claim:** CFTO Route 3 contains a symmetric public triangle that can reuse the
gameplay-proven Lake Honrich picker/service contract without treating its
private and destination-only extensions as peers.

**Inventory evidence:** Headless xEdit resolves Rinlen/Brittleshin Pass
(`0502E1E6`), Hisygg/Half-Moon Mill (`050332ED`), and Bryst/Guardian Stones
(`050332F5`) to `KmodFerryRoute3Faction` (`0502E1DF`). All three use
`MaleEvenToned`, all three public destinations use `KmodFerryCostLocal` at 30
gold, and the exact Dawnguard `DialogueFerryWhereDoYouWantToGo` FUZ exists.
CFTO's fragments bind arrival markers `05014C8F`, `05014C95`, and `050332F7`;
Brittleshin additionally binds horse marker `05195C32`, while Guardian Stones
binds follower/horse markers `05195C33`/`05195C34`.

Lakeview Manor is ownership/jetty/ferryman-gated. Ilinata's Deep has no Route 3
provider and uses the 50-gold regional fare; it is now represented as an
explicit destination-only stop rather than a public peer.

**Build evidence:** All three Papyrus scripts compile. The independent xEdit
audit passes the exact Route 3 faction conditions, shared voice, OnEnd
fragment, quest/service binding, official+CFTO master set, and start-game SEQ.
Regenerating the ESP is byte-identical at SHA-256
`2FCD2A526E53E962EFD3520A635D210CBC4F496C6D23A24282AF709E342BA14C`.
The package contains zero artwork/audio assets:

- `DiegeticTravelBoatIlinalta-offline-candidate.zip`:
  `E62E385D8FDA7649467F4DF86534EED256B18A6A85EDA609542707CCD72C52FE`.

The map positions are derived from the three gameplay-proven Honrich
world-to-parchment anchors and remain a live visual check. The candidate has
not been deployed or gameplay-tested.

## 2026-08-03 Solstheim public-ferry functional pass

**Claim:** The public CFTO Route 4 triangle can use the same automatic dialogue
handoff, parchment selection, live fare, and travel-service contract as the
mainland boat slices.

**Live evidence:** A monitored LoreRim pass opened the Solstheim picker five
times. Raven Rock -> Skaal Village and Skaal Village -> Tel Mithryn both emitted
matching `BOAT_TRAVEL_START`/`BOAT_TRAVEL_COMPLETE` pairs at the live 50-gold
fare. Two picker cancellations completed cleanly. A Skaal Village -> Tel
Mithryn attempt with 22 gold emitted the expected denial with `required=50`
and did not travel. Dialogue handoff closed automatically at zero wait ticks;
the native picker hid and restored all twelve observed HUD layers. No relevant
Papyrus/native error, warning, rejection, timeout, or crash was present.

**Visual finding:** The clean Dragonborn/RUSTIC physical map occupies the right
half of a square DDS and therefore has an inherent 1:2 portrait ratio. The
renderer displayed it without accidental distortion, but both geography and
folds look horizontally compressed. A follow-up deployment attempted an FWMF
chart, but the existing save retained the old texture path/UVs from the quest
script's auto properties while accepting newly compiled marker literals. The
native log proves the mixed state: old `uv=(0.500,0.000)-(1.000,1.000)` and old
physical-map path with the new route-origin point. The candidate therefore
returned to the stable physical-map path, restored its original three marker
coordinates, and moved all static visual settings into function-local
executable code so existing saves receive future visual revisions. A live
1.5:1 pass then proved too wide. The subsequent square 1:1 presentation was
visually approved in game; its Raven Rock hit target also completed a funded
trip to Skaal Village. Raven Rock's overlay point is now staged slightly west
and south, from `(0.329, 0.645)` to `(0.300, 0.665)`, for one focused visual
recheck.

Current no-asset package:

- `DiegeticTravelBoatSolstheim-offline-candidate.zip`:
  `6812DD4A6A28F9674566BD79DFB75597FAE7D7AA521D14FA43D3B7B68C3F6959`.

## 2026-08-03 northern-coast public-ferry offline candidate

**Claim:** CFTO's seven ordinary public Route 1 ferrymen can share one
provider-neutral parchment and travel service without exposing the same option
on the quest-special Enthralled Ferryman.

**Inventory evidence:** Headless xEdit resolves Harlaug/Dawnstar, Jolf/Solitude,
Gort/Windhelm, Radding/Morthal, Perius/Solitude Lighthouse,
Jollsen/Winterhold, and Rolf/Dragon Bridge to `KmodFerryRoute1Faction`. All
seven use `MaleEvenToned`, the live `KmodFerryCost` is 50 gold, and the exact
Dawnguard `DialogueFerryWhereDoYouWantToGo` FUZ exists. The same inventory
proves that the Enthralled Ferryman also belongs to Route 1, so faction-only
dialogue gating would be too broad.

**Scope evidence:** The generated INFO requires CFTO's travel-dialogue faction,
Route 1 faction, and an output FLST containing exactly the seven ordinary
providers. Frostflow Lighthouse is destination-only; Icewater Jetty and
the Enthralled Ferryman retain their distinct Castle Volkihar flow and extra
fare; Windstad Manor retains its ownership/construction gate. Frostflow is now
present only as a marker-backed target; the other special/private routes remain
absent from the picker and service.

**Build evidence:** All three Papyrus scripts compile with zero errors and
warnings. The independent xEdit audit passes six masters in order, the exact
seven-entry whitelist, start-game-enabled priority-60 quest, one Goodbye/OnEnd
shared-voice dialogue response, service/picker wiring, and matching four-byte
SEQ. Every source exposes the other six public ports. The package references
the installed Skyrim battle map and contains zero artwork/audio assets.

**Remaining boundary:** The five capital positions reuse visually proven
parchment anchors. Solitude Lighthouse and Dragon Bridge were projected from
those anchors and still require one in-game alignment pass. No north-coast
trip is gameplay-proven yet.

Candidate package:

- `DiegeticTravelBoatNorthCoast-offline-candidate.zip`:
  `3D5B10EB7F1C8CC14E303D304C5A1208A18CED454C0C4B991322AAF488D24938`.

## 2026-08-03 provider-defined physical route graphs

**Claim:** The provider-neutral parchment picker can render shared physical
water/road networks while preserving the proven wizard-spoke behavior for
providers that do not opt in.

**Implementation evidence:** The native request contract now accepts up to 192
normalized undirected segments. It rejects out-of-range, duplicate, and
zero-length edges. Ready validation requires every offered destination to be
connected to the source. The renderer draws the graph once in the existing
gold/ink treatment and uses a weighted shortest-path search to redraw only the
hovered or focused journey in red. The existing straight-spoke branch remains
the fallback when no explicit graph is supplied.

**Provider evidence:** Lake Honrich supplies a ten-segment lake ring connecting
Riften, Heartwood Mill, and Ivarstead. The northern coast supplies a 23-segment
coastal graph with a Sea of Ghosts trunk plus the Karth, Morthal, Dawnstar, and
White River approaches. All endpoints include the exact source/destination
anchors, so every request passes native connectivity validation.

**Build evidence:** Offline core and full CommonLib builds pass. The new graph
tests prove bent-path resolution, reversed-duplicate rejection, zero-length
rejection, and disconnected-destination rejection. All three picker scripts,
all three Lake Honrich scripts, and all three northern-coast scripts compile
with zero errors and warnings. Both boat xEdit and voice-asset audits pass.
The verified artifacts were deployed only to their three isolated test mods;
MO2 profile files were not changed.

**Remaining boundary:** Route placement, gold idle visibility, red hover-path
choice, selection, and cancellation require a live visual pass. No claim is
yet made that every bend perfectly follows the artwork's shoreline.

Candidate hashes:

- parchment picker: `A454A384E121E6936997BE192ACB1849CAE937BC9761747AE67EF03AB11176E9`;
- Lake Honrich: `D42E3583FDA70901093B1A2A344DAA62F086C4360D085BB35E21E6B699C20C20`;
- northern coast: `41738B6276DABAD6C03C22C506B827D42D572BF1F8A8670986230ED9076A4202`.

## 2026-08-03 user-authored boat route overlay candidate

**Claim boundary:** This is an offline-proven, deployed test candidate; its
appearance is not yet gameplay-proven.

**Implementation evidence:** Requests can optionally set one full-canvas
transparent overlay texture. The renderer composites it after the dependency
map and before interactive markers. For overlay-backed requests, inactive
native route segments are suppressed and only the shortest active path is
drawn in red. Requests without an overlay retain the existing gold-idle/red-
active presentation. North-coast and Lake Honrich opt in; wizard, carriage,
Ilinalta, and Solstheim providers do not.

**Asset evidence:** The user-authored 4096x3016 RGBA PNG was hash-copied into
`assets/route-overlays` and encoded as one-mip `BC7_UNORM` DDS with alpha. The
shared package contains exactly that one owned DDS and no RUSTIC MAPS texture,
audio, or other artwork. DDS SHA-256:
`E0CDF0D9E4B9BE8E36E6BD51D40EF74065B3905197304CF7E83DE8294A00C37E`.

**Verification evidence:** Native C++ and all affected Papyrus scripts compile
with zero errors/warnings. Core route tests, the shared picker audit, and both
isolated boat xEdit/SEQ audits pass. Package and deployed DLL, PEX, and DDS
hashes match. The `UltraDiegeticTravel` North-coast no-launch preflight passes.

Candidate hashes:

- parchment picker: `9FE9276A4569B3CB438DDFFF591F36F2EF6B265545982D4C8BD8B2E5C8D7DACD`;
- Lake Honrich: `A10D3786F8A6E9DBA9AA9813ECC4FD73FF5369F30AC7A2E7CF038C0C322A71C6`;
- northern coast: `88A7EBA3C7216D29CC806E2FFEDE923BA6397CB59F96C55590D91E0EB582FA36`.

**Live test gate:** Confirm the charcoal overlay loads once, its registration
matches the parchment crop, no idle native network is visible, hover/focus
draws exactly one red shortest path, selection still travels, Escape cancels,
and no `PARCHMENT_OVERLAY_MISSING` or DNT error appears.

## 2026-08-05 direct carriage selection and Norden map symbols

**Rejected runtime path:** LoreRim's winning carriage overrides expose the
vanilla `LinkCarriageSeat` association but not CFTO's expected custom seat link.
The attempted safe repair was rejected by the runtime reference and logged
`CARRIAGE_LINK_BLOCKED ... reason=repair_failed`; no purchase committed and no
gold was removed. Boarding execution is therefore removed from the beta.

**Candidate architecture:** Clicking a parchment marker now revalidates the
quote, resolves one of CFTO's 27 ground-level arrival `XMarkerHeading`
references, verifies funds, charges atomically, and immediately invokes the
same fade/encumbrance/`Game.FastTravel` pattern already proven by the boat
providers. A missing marker or insufficient funds returns before payment.
`KmodCarriageDestination` is cleared so no stale CFTO boarding state remains.

**Marker evidence:** The installed Norden UI 1.2.5 16:9 and 21:9
`mapmarkerart.swf` files are byte-identical with SHA-256
`AF39A7C181E8BF6187E389CC6D5F333780F11057C562673BC40A78490998B1AA`.
Fourteen exact discovered-state symbols were exported and hash-pinned: nine
hold capitals plus Town, Settlement, Farm, Wood Mill, and Mine. The project
owner reports direct use/redistribution permission from the Norden UI author.

**Offline evidence:** Six core and two carriage Papyrus scripts compile with
zero errors/warnings. The strict parchment asset audit, isolated xEdit/SEQ
audit, native core CTest, and all ten Python unit tests pass. The no-launch MO2
preflight confirms the `UltraDiegeticTravel` profile, adapter winner, deployed
scripts, and all fourteen marker DDS files. Gameplay remains unproven until a
marker is clicked in a live run.

Candidate hashes:

- core package: `E1061AADF47ECFEE38AFAA49413AAB6FB70CE7E6D8EF6DE432A9408C61CD6F77`;
- carriage adapter: `0606159F79EEFDF6A6376493CB11B99CEAA01338AF71CD2DB238659561976EF1`;
- parchment picker: `FD582118A5FDB4285F1EE37431AB13C880B8322F11FF75D7D2FB301B275DAECB`;
- origin-service PEX: `6D7432F5B1E2FF378269007A36598D000510514544E56BC5A059903FE8665CE8`;
- carriage-picker PEX: `B56548C8FB9AD3E38E1E2D1431D1420E6CCD634CC3D352AE457497A87B1E3C49`.

**Focused live gate:** Select one capital and one minor stop, confirm payment
occurs once, travel begins without boarding, arrival is on the ground at the
expected CFTO stop, elapsed game time advances, and the log contains paired
`PURCHASE_COMMITTED ... execution=direct` and `CARRIAGE_TRAVEL_COMPLETE` lines.
Also verify the nine capital symbols and at least one mill/farm/mine marker
match the regular Norden world-map family.

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
# 2026-08-05: full CFTO carriage beta sheet, without route geometry

- The installed CFTO plugin exposes 27 destinations with a verified native
  carriage handoff: nine hold capitals, fifteen minor Skyrim stops, and three
  HearthFires homesteads. Helgen and Granite Hill are deferred because the
  installed plugin does not provide the same executable handoff for them.
- The discovery-time xEdit inventory recorded authoritative world coordinates
  from each destination's Skyrim/HearthFires map marker. Those results are
  retained in `modules/carriage-parchment/config/network.json`; the obsolete
  inventory script remains recoverable from Git history. Its calibrated
  capital residual is RMSE `(0.004614, 0.010628)` in parchment UV space.
- The beta intentionally omits `SetRouteOrigin` and `AddRouteSegment`. It shows
  selectable destinations without straight spokes or invented road geometry.
- `DNT_RouteService` batches hazard-phase and war-multiplier reads;
  `DNT_TravelCoordinator` coalesces duplicate preparation requests; the picker
  consumes published quotes and `Purchase` still revalidates the chosen route.
- The shared native request bound increased from 24 to 32. A regression test
  accepts all 32 bounded entries and rejects entry 33. Both AE and pure-core
  CTest presets pass, both Papyrus compilation sets pass with zero warnings,
  and the isolated xEdit audit reports `cached 27-stop CFTO sheet, no synthetic
  routes, revalidated purchase`.
- Candidate package SHA-256 values after the change:
  parchment picker `04202F448CE501CC00F9DC0C048E9F5441E4C9123B7ED6B7C4004022DDEA1238`;
  carriage adapter `CDD941011FEFABE445662122875B86B8C9E1F9149EF62D3F2361D4D5C343298C`.

# 2026-08-05: aspect-correct Norden symbols and reciprocal mainland docks

- **Failure cause:** `Build-NordenCarriageMarkers.ps1` passed both
  `--export-width=512` and `--export-height=512` to Inkscape. That reshaped each
  non-square Norden SVG page before the normalizer ever saw it. The Menu
  Framework renderer does draw textures in a square visual rectangle, but its
  invisible destination hitbox is independently computed; the click circle did
  not cause the distortion.
- **Repair:** render each SVG with width constrained only, alpha-crop the
  result, proportionally fit within 416 by 416, and center it on a transparent
  512-square canvas. Spot inspection of Whiterun, Town, and Settlement outputs
  shows intact aspect and no edge clipping.
- **Ilinalta recalibration:** CFTO's audited arrival-marker coordinates were
  projected with the carriage parchment model's nine-point affine coefficients.
  This yields Brittleshin `(0.454414, 0.665229)`, Half-Moon Mill
  `(0.399755, 0.670970)`, and Guardian Stones `(0.501218, 0.685304)`. The old
  `(0.394,0.667)`, `(0.315,0.675)`, and `(0.444,0.688)` estimates are retired.
- **Network presentation:** each mainland provider now adds all docks from the
  other two mainland networks through `AddRouteLandmark`; these markers are
  non-interactive and use the existing grey inactive-anchor rendering.
- **Offline evidence:** nine Papyrus scripts compile at zero errors/warnings;
  shared parchment audit passes with fourteen Norden markers; native parchment
  CTest passes 1/1; Ilinalta, Honrich, and North-coast isolated xEdit/SEQ audits
  pass; carriage and North-coast MO2 validation-only preflights pass.
- **Deployment:** only the four owned test mods were updated. No LoreRim
  baseline mod or MO2 profile file was modified. Live visual approval remains
  required before promoting the marker aspect and dock placement claims.

# 2026-08-05: mainland ferry route artwork deferred for beta

- **Decision:** the Lake Honrich and North-coast providers no longer call the
  optional overlay or authored-segment APIs. All mainland ferry maps now use
  the Lake Ilinalta-style beta presentation: destination anchors, current and
  hovered boats, a direct selection line, and grey landmarks for inactive
  waterways.
- **Asset boundary:** `boat-route-chalk-overlay.dds` is not built, packaged, or
  deployed. Its user-authored PNG, conversion script, and the dormant provider
  geometry remain reproducible post-release sources rather than runtime data.
- **Regression guard:** provider audits fail if `SetOverlayTexture` or either
  route-network activation call returns. The native API and unit coverage stay
  intact for later artwork work.
- **Offline evidence:** both changed provider script sets compile with zero
  errors/warnings; the shared parchment audit reports only two user-authored
  marker assets; native CTest passes 1/1; and both isolated xEdit/SEQ audits
  pass.
- **Candidate hashes:** parchment picker
  `792EBED6A5FB9A0A7080336836B727AD46F68030E362942994888A5CCAF0BCB9`;
  Honrich `5819E92CA88BB7944133EA0D5F5B1B706A0AB09B3A7713C2C744AFB866A27087`;
  North coast `830432532BE67A3BBE167D4A4A42ED4DCAD45E68DBF284959CEB1F2662C877E3`.
- **Live gate:** open one provider on each changed network, verify no chalk or
  authored water path appears, and confirm hover, cancel, and travel still work.

# 2026-08-05: icon-only provider maps and beta endpoint preservation

- **Observed failure:** Winterhold supplied 16 carriage destinations and
  Falkreath 14 even though the native picker supports 32 and the adapter
  defines all 27 CFTO stops. `CARRIAGE_PARCHMENT_ROUTE_SKIPPED` correlated the
  omitted stops with route-service `unavailable` results. Papyrus also reported
  `Cannot cast from None to String[]/Int[]` in `EndQuoteBatch`.
- **Root cause:** the deferred trust/hazard design still treated active
  refuse-tier chokepoints as hard candidate blockers, sometimes eliminating
  every candidate before the adapter built its sheet. Batch cleanup assigned
  `None` to typed arrays.
- **Repair:** active/unknown hazards now surcharge rather than block in both the
  Papyrus runtime and Python reference evaluator. Marker/endpoint availability
  remains the sole map-visibility gate. Batch arrays remain allocated and are
  logically reset. Regression audits reject the old blocker and typed-array
  assignments.
- **Presentation:** provider IDs `boat` and `college` bypass dynamic route
  rendering. College uses an 18% focused-icon scale and no red halo. Boat origin,
  destination, and grey landmark icons remain. Brittleshin is moved north from
  historical `(0.454414,0.665229)` to `(0.454414,0.632000)` so the anchor tip
  lands on the calibrated location.
- **Offline evidence:** native build and asset audit pass; native CTest 1/1;
  Python tests 10/10; carriage plus all three affected mainland boat xEdit/SEQ
  audits pass; carriage and North-coast MO2 validation-only preflights pass.
  Source/deployed DLL and four changed PEX files have identical SHA-256 hashes.
- **Live gate:** verify no path strokes on a boat map or College map, focused
  College icons grow without changing artwork, the Brittleshin anchor placement
  is acceptable, and carriage menus expose every currently executable stop.

# 2026-08-05: live provider-case diagnosis and icon hierarchy candidate

- **Observed evidence:** the Ilinalta runtime logged provider `Boat`,
  `routeSegments=0`, and `overlay=<none>` while a yellow direct line was still
  visible. This disproves both stale segment data and save-state persistence as
  causes.
- **Root cause:** presentation suppression compared provider IDs to lowercase
  string literals. The runtime boundary preserved a capitalized provider ID,
  so the request fell through to the legacy direct-line renderer.
- **Repair:** provider policy is now ASCII case-insensitive. Boat and College
  line suppression and College/carriage special presentation consequently do
  not depend on Papyrus string casing. Regression audits reject direct
  case-sensitive provider comparisons.
- **Visual candidate:** carriage capital icons render at `1.25x`, other stops
  at `0.84x`, with hitboxes unchanged. Dawnstar is moved to
  `(0.570000,0.160000)` to cover the baked crest. Brittleshin is moved to
  `(0.454414,0.632000)` to align the anchor tip with the calibrated point.
- **Live gate:** confirm no Ilinalta line, verify capital/minor hierarchy,
  Dawnstar crest coverage, and Brittleshin anchor placement.
- **Offline evidence:** shared source/asset audit; native build and CTest 1/1;
  all affected Papyrus compiles with zero errors/warnings; Python tests 10/10;
  carriage and all three mainland boat xEdit/SEQ audits; carriage and
  North-coast combined-profile preflights. Deployed DLL and affected picker
  PEX files match their workspace artifacts byte-for-byte.
- **Candidate packages:** parchment
  `24C072A4631C78A86CABD80F4879B4AE4A5EB6131F2CBA4B4AD18A34478CB6DB`;
  carriage `D5C53F8CE9A455C9E9E2DD851BA382F71AFFC3FA51F8FF9FCE09197F2697454F`;
  Ilinalta `A8775C8CB32016EBA17538175D5D35EFEE1695A69AE37E95AAFEDE5C0AD1F5E8`;
  Honrich `1D9508E977D59EB831293405306769D7F4D8A02DE4C239FEB49253761C630999`;
  North coast `686F066DA1379338358AA43CB46ED124F42B94D57233F154F86CFD90C51A2E01`.

# 2026-08-06: live provider-case proof and second marker calibration

- **Proven:** an Ilinalta request arrived as provider `Boat` with zero route
  segments and no overlay, and the map displayed no yellow route line. The
  case-insensitive native presentation policy is therefore live-proven.
- **Rejected:** Brittleshin `(0.454414,0.632000)` placed the anchor too far
  north. The next candidate restores the affine-projected southern shoreline
  point `(0.454414,0.665229)`.
- **Accepted:** the carriage capital/minor size hierarchy. Falkreath, Riften,
  and Windhelm are still slightly up/left of the baked crests; their next
  positions are `(0.443000,0.792000)`, `(0.936000,0.828000)`, and
  `(0.823000,0.382000)`.
- **Travel evidence:** `CARRIAGE_TRAVEL_COMPLETE` recorded Dawnstar to Morthal
  for 200 gold and Morthal to Winterhold for 1250 gold.
- **Live gate:** visually accept the restored Ilinalta coordinate and the
  three down/right capital corrections.
- **Offline evidence:** all four affected Papyrus targets compile with zero
  errors/warnings; all four xEdit/SEQ audits and both combined-profile
  preflights pass. Deployed picker PEX files match their workspace builds
  byte-for-byte.
- **Coordinate-pass packages:** carriage
  `4894CBB7E97E719F7F1F87F009869DF2BD9316BA8EE068620D1039F2A1C3D914`;
  Ilinalta `08DBC4FA0CFCD829328DCA5DC23DAFE13715A103633DB990FA6CFCF057CA5735`;
  Honrich `F0FA68EBF9DD228B5814CAA4EFE14537BFA258D1F1E8344C2894722287E7FC72`;
  North coast `1CE578E02A7D1363BCEDBCB5DEA7700B854FF3263D6B6463BA267151A3597FED`.

# 2026-08-07: destination-only ferry contract

- **Source proof:** isolated CFTO inventory resolves Frostflow Lighthouse
  (`05038411`), Ilinata's Deep (`0503840E`), Northshore Landing (`0503840C`),
  and Bujold's Retreat (`0503840D`) as executable arrival references. Their
  original INFO records add only the normal gold condition; the one-way
  restriction comes from their Route 1, Route 3, or Route 4 topic membership.
- **Topology proof:** none of the four destinations has a service actor. The
  runtime therefore records each under `destination_only_stops` with an exact
  `available_from` provider list, no `service_npc`, and `provider_enabled=false`.
  Source resolution remains exactly seven north-coast, three Ilinalta, and
  three Solstheim actors.
- **Fare/companion proof:** Frostflow, Northshore, and Bujold use regional
  `KmodFerryCost` (`0500AA12`). Ilinata also uses that 50-gold regional fare
  instead of Route 3's 30-gold local fare and retains follower/horse markers
  `05195C43` and `05195C35`.
- **Offline evidence:** all nine affected Papyrus targets compile with zero
  errors/warnings. The three isolated xEdit/SEQ audits pass exact provider
  counts, marker IDs, fares, map coordinates, and the absence of return-source
  contracts.
- **Live gate:** complete one trip to each destination, verify exact payment
  and arrival placement, and confirm no parchment travel prompt appears at the
  destination.
