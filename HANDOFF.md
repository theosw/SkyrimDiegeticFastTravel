# Diegetic Travel handoff

Updated: 2026-07-31

## Evidence ledger

Use `docs\EVIDENCE_LEDGER.md` as the source of truth for working assumptions,
rejected approaches, live-proven behavior, and the next candidate test. In
particular, do not treat xEdit accepting a dialogue field as runtime proof.
Commit `ae1dc5c`, whose ESP is SHA-256
`3F5C3BEBCBBD26DC70517A7943CF36E918942C57240736A3BFD3731EAB2D9550`, is the
previous live-proven Solitude checkpoint. The corrected Windhelm/Markarth build
is now the latest live-proven gameplay checkpoint; its ESP is SHA-256
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`.

## Wizard-guide Phase 1

Phase 1 of the separate wizard-guide pillar is implemented under
`modules\wizard-guides`. It does not modify the carriage checkpoint or depend
on CFTO/Better Carriage Destinations.

Network:

- The College of Winterhold is the permanent hub.
- Farengar Secret-Fire (`013BBB:Skyrim.esm`) offers the College.
- Wylandriah (`019DEF:Skyrim.esm`) offers the College.
- Sybille Stentor (`0132AA:Skyrim.esm`) offers the College.
- Wuunferth the Unliving (`014146:Skyrim.esm`) offers the College.
- Calcelmo (`01338E:Skyrim.esm`) offers the College.
- Permanent College faculty at faction rank 3 or higher offer Whiterun,
  Riften, Solitude, Windhelm, or Markarth; students remain ineligible.
- All services are immediately available; faction, relationship, quest, and
  trust gates are deliberately deferred.
- Every hop costs 250 gold.
- Travel waits one second for dialogue to close and then calls `MoveTo`: no
  elapsed game time, rest, or recovery.

The UI-independent `DNT_WizardTravelService` exposes stable destination IDs plus
`GetFare`, `CanTravel`, and `RequestTravel`. New dialogue records call that
service through `DNT_WizardTravelFragment`; the optional BCD/Shazdeh adapter now
calls the same service without duplicating travel logic.

The generated plugin is `DiegeticTravelWizardGuides.esp`. It defines one
start-game-enabled quest, one top-level player branch, five custom topics, and
twelve INFOs. It overrides no existing records. Its SEQ and two compiled PEX
files live beside it in the module.

The three-node star passed its monitored gameplay test. INFO `000806` presents
`Can you teleport me to the College of Winterhold? (250 gold)` to Farengar and
binds `DestinationId=college`; INFO `000807` provides the corresponding
Wylandriah-to-College route. INFO `000808` is the College hub:
`Can you teleport me somewhere? (250 gold per trip)`. It carries no travel
fragment and links to exactly two destination topics:

- `000803` / INFO `00080B`: Whiterun (`DestinationId=whiterun`)
- `000804` / INFO `00080C`: Riften (`DestinationId=riften`)

The currently deployed voiced build gives each terminal travel INFO an
explicit, genuine vanilla Shared Response Data donor:

- Farengar (`MaleEvenTonedAccented`): `Yes.` from `000730FA:Skyrim.esm`
- Wylandriah (`FemaleEvenToned`): `Of course.` from `000DBA22:Skyrim.esm`
- Sybille (`FemaleSultry`): `Of course.` from `000DBA22:Skyrim.esm`
- all three general faculty destinations: `Of course.` from
  `000DBA22:Skyrim.esm`
- Mirabelle's three exact-speaker fallbacks: owned subtitle-only `Of course.`

Voiced travel INFOs retain only the vanilla `Goodbye` response flag, have no
`LinkTo`, and run `DNT_WizardTravelFragment` on `OnBegin`. Mirabelle's terminal
INFOs additionally force subtitles and have no LIP file. The branching hub
owns the unvoiced response `Where do you need to go?`, has
`Force Subtitle + No LIP File`, no VMAD, and exactly three `LinkTo` entries.
This experiment exposed a semantic hole in the original audit. `000730FA` and
`000DBA22` are genuine SharedInfo records, but `00079AD7` is ordinary dialogue
from `Favor258Reject` in the Thane of Falkreath quest. xEdit permits that INFO
reference in `DNAM`, but Skyrim does not consider the two Phinis destination
INFOs valid choices: the owned hub says `Where do you need to go?` and the
dialogue closes with no travel trace. An earlier hub experiment similarly used
ordinary generic Hello INFO `00087940`; it spoke `Yes?` and failed to expose
the links. These tests reject arbitrary INFO donors, not SharedInfo on linked
topics generally. A vanilla-data scan found 1,037 linked-topic INFOs using
genuine Shared Response Data.

The proven baseline uses an owned Phinis hub and genuine SharedInfo `000DBA22`
(`OfCourse`) on both child INFOs. The generator and independent audit require a
non-empty donor EditorID, Misc/SharedInfo topic identity, and actual
parent-child membership. That baseline passed its monitored gameplay
regressions on 2026-07-31: the submenu, all four directed routes, fare denial,
and audible lip-synced replies for Farengar, Phinis, and Wylandriah all worked.
The live-proven faculty-access expansion generalizes those same records as
described below.

Arrival markers reuse stable Skyrim references whose effective positions
already reflect the installed JK interiors:

- College: `036A67:Skyrim.esm` (`MGPhinisSleepMarker`), winner
  `JK's College of Winterhold.esp`
- Whiterun: `0B7AA5:Skyrim.esm` (`FarengarLabMARKER`), vanilla winner
- Riften: `044A4A:Skyrim.esm` (`RiftenKeepWizardLabMarker`), winner
  `JK's Mistveil Keep.esp`
- Solitude: `02C194:Skyrim.esm` (`BluePalaceAudienceMarker`), winner
  `JK's Blue Palace.esp`
- Windhelm: `0A3F1C:Skyrim.esm` (`WindhelmWuunferthLabMarker`), focused
  inventory winner `Unofficial Skyrim Special Edition Patch.esp`
- Markarth: `03692A:Skyrim.esm`
  (`MarkarthCastleWizardVendorMarkerREF`), focused inventory winner Skyrim.esm

Both scripts compile with 0 errors and 0 warnings. The workspace plugin parses
successfully off-order and has zero dangling references or missing masters.
The compact headless-xEdit audit confirms exact speakers, response donors,
flags, hub links, fragment timing, bound service, and destination IDs. A
separate BSA filename-table audit confirms all three selected vanilla FUZ files
exist. Arrival-marker geometry and audio playback remain gameplay-only checks.

An earlier live pass proved that Farengar's top-level option appeared, but
the borrowed response played and no `WIZARD_TRAVEL_*` trace was emitted. The
fragment never entered the service. The new build removes both suspect layers:
there is no Shared Info inheritance, and the fragment runs on `OnBegin` rather
than `OnEnd`. `DNT_WizardTravelService` then waits one second before charging
and moving the player.

The replacement build passed its live two-way test on 2026-07-31. With only
72 gold, Farengar's route emitted `WIZARD_TRAVEL_DENIED` and did not move the
player. After adding test funds, Farengar completed the College trip:

- `WIZARD_TRAVEL_START destination=college fare=250`
- `WIZARD_TRAVEL_COMPLETE destination=college fare=250`

Phinis then completed the return trip:

- `WIZARD_TRAVEL_START destination=Whiterun fare=250`
- `WIZARD_TRAVEL_COMPLETE destination=Whiterun fare=250`

The player confirmed arrival at the College and then back in Whiterun. This
proves the full dialogue -> fragment -> fare -> delayed `MoveTo` path in both
directions and establishes the College-centred star's first working spoke.

The expanded star then completed three monitored trips:

- Farengar -> College
- Phinis -> Riften
- Wylandriah -> College

Every trip emitted one `WIZARD_TRAVEL_START` and one
`WIZARD_TRAVEL_COMPLETE`, and Skyrim exited normally. The simultaneous
`IsPoison()` errors belong to LoreRim's
`Nox_WAR_ThrowingKnife_PoisonApply.OnItemRemoved`; its listener reacts to the
gold removal but does not interrupt travel.

Rollback commit `a03262d` checkpoints the proven two-way build. Commit
`9aa25ef` checkpoints the live-proven three-node star before voice changes, and
commit `ed004f2` checkpoints the fully proven voiced Phase 1 build.
Commit `4dfb646` checkpoints the live-proven permanent-faculty expansion.
`tools/Audit-WizardGuideStar.ps1` checks the seven visible INFOs, while
`tools/Audit-WizardVoiceAssets.ps1` checks the exact FUZ paths. The voice
patcher produces byte-identical output on a second run. Both the generator and
the independent audit now prove that every donor belongs to a special
Misc/SharedInfo topic and has an EditorID; the separate archive audit proves
the expected speaker-specific FUZ paths. See `docs\EVIDENCE_LEDGER.md` for the
promoted live evidence and the gate future dialogue changes must pass.

`tools/Patch-WizardGuideDialogue.ps1` now defaults to the patched headless
xEdit at `build/xedit-patched/SSEEdit64.exe`, patches the workspace copy only,
and deploys to LoreRim only when passed `-Deploy`; deployment is refused while
`SkyrimSE` is running. `-Deploy` copies the complete owned module payload so
the ESP, SEQ, and newly compiled PEX files stay in sync. The latest fully proven
ESP is SHA-256
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`.
The exact live-tested payload was packaged with `-PackageOnly` as
`dist\DiegeticTravelWizardGuides-phase1.zip`, SHA-256
`55301E384F844661C0F5CE884115F54AD66E5039C965D5A99E3B95FF86086C7E`.
A normal package build recompiles the PEX files and changes their binary hashes;
use `-PackageOnly` when checkpointing already-tested artifacts, or require a
new live pass after recompilation.

### BCD wizard map-adapter candidate

The optional adapter lives under `modules\wizard-map-picker` and is deployed as
additional files inside the existing owned
`houseCARL - DiegeticTravelWizardGuides` mod directory. It does not modify the
live-proven core ESP. `DiegeticTravelWizardMap.esp` hard-masters the core wizard
plugin and Better Carriage Destinations, adds a second faculty dialogue option,
and opens BCD with a whitelist containing exactly these world-map markers:

- Whiterun `000162CE`
- Riften `0001C390`
- Solitude `0004D0F4`
- Windhelm `00038436`
- Markarth `0001C38A`

`DNT_WizardMapPicker` receives `BCD_SetDestination`, resolves the selected
marker while MapMenu is open, translates it to the existing lowercase stable
destination ID, closes the map, and calls
`DNT_WizardTravelService.RequestTravel`. It never calls BCD's pricing, scene,
or travel functions. Cancelling does not invoke the core service, and the old
five-choice dialogue submenu remains available.

Research is pinned to current BCD HEAD
`136dc7b3ad9754877c485fd5cea29550af108888`; LoreRim has BCD 1.0.10 enabled in
`UltraDiegeticTravel`. Both adapter scripts compile with 0 errors and 0
warnings. Generation is byte-idempotent, and the independent audit passes both
integration masters, the whitelist, seven quest properties, faculty conditions, branch,
quest ownership, and OnBegin fragment. The adapter ESP is SHA-256
`85AE4DEF45B94894D92499654499347CD0C0B380A8969B14113F40CFC324A9EA`; the core
ESP remains
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`.

The candidate package is
`dist\DiegeticTravelWizardMapAdapter-alpha.zip`, SHA-256
`22E60A42E9CB0432EF2936848BF21A94C019A958D223816DC9EAB6D7D971D5C5`. All seven
deployed adapter files hash-match the workspace. The profile currently has BCD
and the core plugin enabled, but `DiegeticTravelWizardMap.esp` has not yet been
added to `plugins.txt`; enable it in MO2 before testing. Do not promote the
adapter until the monitored matrix in `docs\WIZARD_MAP_ADAPTER.md` passes.

### Faculty access

The current workspace and deployment broaden the College hub from exact
speaker Phinis to members of `CollegeofWinterholdFaction` at rank 3 or higher.
This selects twelve permanent faculty: Sergius, Mirabelle, Savos, Tolfdir,
Arniel, Enthir, Nirya, Colette, Phinis, Drevis, Faralda, and Urag. The condition
explicitly excludes Arniel's summoned shade and the dead Alftand NPC Endrast;
rank-0 students and Nelacar remain ineligible.

The generic `Of course.` SharedInfo has shipped audio for ten of the eleven
faculty voice types. Mirabelle's unique voice lacks it, so each destination
topic has a second exact-Mirabelle, subtitle-only INFO. The two inbound court
wizard routes are unchanged. The candidate is byte-idempotent at ESP SHA-256
`4EEAED7C6556ADC159A128C9D95FB66124C3C90FC3FB9200D4CF7CC797567E89`.
Both the workspace and deployed copy pass the strengthened seven-record xEdit
audit, and the archive audit passes all ten voiced faculty types. The focused
gameplay matrix passed on 2026-07-31: J'zargo had no option, every encountered
eligible faculty member had the hub and both choices, and Mirabelle's owned
subtitle-only confirmation completed travel as designed.
The fragment now passes `akSpeakerRef` into the service, and every denial,
start, and completion trace includes `source=<actor reference>` so the monitor
can distinguish faculty members that share the same destination INFO.

### Solitude-spoke proof

The proven build adds Sybille Stentor as the Solitude court wizard and a
third outward faculty choice, preserving the College hub topology. Sybille's
direct route uses the same genuine `Of course.` SharedInfo proven for
`FemaleSultry`; the BSA audit confirms her exact FUZ/LIP. General faculty use
the existing voiced response and Mirabelle receives a third owned
subtitle-only fallback.

The service binds `SolitudeMarker` to persistent Skyrim reference `0002C194`,
`BluePalaceAudienceMarker`. A focused xEdit inventory loaded JK's Blue Palace
and confirmed that it wins this reference and moves it to the remodeled court
floor. The generator adds DIAL `00080F`, child INFOs `000810` and `000811`, and
Sybille root INFO `000812`; it is byte-idempotent at ESP SHA-256
`3F5C3BEBCBBD26DC70517A7943CF36E918942C57240736A3BFD3731EAB2D9550`.
The independent audit verifies the three-link hub, all new speaker/response
conditions and fragments, and the service marker property. The monitored
2026-07-31 pass verified the three-choice menu, Mirabelle-to-Solitude travel,
safe Blue Palace arrival, Sybille's audible lip-synced response and return to
the College, and a Riften/Wylandriah regression.

### Windhelm/Markarth proof

The proven build extends the same College-centred star with Wuunferth the
Unliving and Calcelmo. A repeatable headless-xEdit inventory loads USSEP, JK's
Palace of the Kings, JK's Understone Keep, and the installed Snazzy interior
plugins. It resolves Wuunferth as `MaleOldGrumpy` NPC `00014146` with persistent
reference `0001B132`, and Calcelmo as `MaleOldKindly` NPC `0001338E` with
persistent reference `00019908`. The existing `000DBA22` `Of course.` FUZ/LIP
exists for both voice types.

The service binds `WindhelmMarker` to persistent reference `000A3F1C`,
`WindhelmWuunferthLabMarker`, and `MarkarthMarker` to persistent reference
`0003692A`, `MarkarthCastleWizardVendorMarkerREF`. Both are purpose-named
markers beside the relevant wizard. The focused winners are USSEP and
Skyrim.esm respectively; live arrival geometry is still required.

The generator adds Windhelm DIAL `000813`, voiced INFO `000814`, Mirabelle INFO
`000815`, and Wuunferth root INFO `000816`; Markarth uses DIAL `000817`, voiced
INFO `000818`, Mirabelle INFO `000819`, and Calcelmo root INFO `00081A`. The
faculty hub now links to exactly five destination topics. Both Papyrus scripts
compile with zero errors and warnings, all exact-record and voice-asset audits
pass, and a second generation is byte-identical at ESP SHA-256
`F81562179374815AEF3D57015BC0EBC7AD40B7235A730CB727E7994F7EF68B4F`.
The initial live build `9B4545B8...` completed five trips, including both new
round trips, but exposed a semantic audit hole: INFO `ANAM` did not gate the
top-level response. Ancano reference `0001E7D8` received a court-wizard route,
and both he and Calcelmo could select another identical root INFO and therefore
play the wrong donor voice. The corrected generator adds one subject
`GetIsID == 1` condition to every exact-speaker INFO, including Mirabelle's
fallbacks. The strengthened audit now requires both `ANAM` and that condition.
The monitored corrected-build pass confirmed Ancano no longer had the option;
faculty-to-Markarth, Calcelmo-to-College, Mirabelle-to-Windhelm,
Wuunferth-to-College, and a faculty-to-Whiterun regression all completed. The
user confirmed the tested voices matched their speakers and both arrivals were
usable. Wuunferth's line ended slightly early because travel begins after one
second; timing polish is deferred while the final voice set remains unsettled.
The complete module is deployed to the owned LoreRim mod under
`UltraDiegeticTravel`; all seven ESP/README/SEQ/PEX/PSC payload hashes match the
workspace, and the non-launching profile preflight passes.

At this checkpoint MO2's active profile is `UltraDiegeticTravel`. The complete
workspace payload has been deployed to
`D:\Lorerim\mods\houseCARL - DiegeticTravelWizardGuides`, and the installed
ESP, README, SEQ, PEX, and PSC files hash-match the workspace copies. Direct
reads of the MO2 profile files confirm the mod is enabled in the left pane and
`DiegeticTravelWizardGuides.esp` is checked in the right pane. The installed
build passes the strengthened structural audit and the monitored faculty and
five-city gameplay regressions. Do not launch Skyrim without coordinating with
the user; a parallel PickUpAsJunk task may also use MO2.

## Wizard-guide live tests

### Windhelm/Markarth exact-speaker regression

The monitored corrected-build pass recorded five trips and five matching
completions: faculty `0001C1A1` -> Markarth, Calcelmo `00019908` -> College,
Mirabelle `0001C1B9` -> Windhelm, Wuunferth `0001B132` -> College, and faculty
`0001C1A8` -> Whiterun. Ancano had no option and produced no travel trace. The
tested voices matched their actors; Wuunferth's line was only slightly clipped
by the one-second travel delay. Skyrim exited normally.

### Solitude-spoke regression

The monitored 2026-07-31 Solitude pass recorded four trips and four matching
completions. Mirabelle (`0001C1B9`) reached Solitude using her intentional
subtitle-only fallback; the player reported a safe Blue Palace arrival.
Sybille (`000198C5`) audibly delivered the lip-synced `Of course.` and returned
the player to the College. A faculty member (`0001C1A8`) then reached Riften,
and Wylandriah (`00019DF0`) returned the player to the College. Skyrim exited
normally with no wizard-travel denial or unpaired start.

### Faculty-access regression

The monitored 2026-07-31 faculty pass confirmed the rank-gated service in the
`UltraDiegeticTravel` profile. J'zargo, a rank-0 student, did not receive the
travel option. Every eligible faculty member encountered by the player did,
while Phinis retained both destinations. Mirabelle displayed her owned
subtitle-only `Of course.` fallback and completed the selected trip.

Papyrus recorded nine trips and nine matching completions, with no wizard
script warning. The run exercised faculty travel to both Whiterun and Riften
and returns through both Farengar and Wylandriah. Source references were
present on every trace, including the Phinis (`0001C1A7`), Farengar
(`0001A67E`), and Wylandriah (`00019DF0`) regressions. Skyrim exited normally.

### Presentation regression

The monitored 2026-07-31 presentation pass completed this sequence:

- Phinis -> Whiterun at 12:17:14;
- Farengar -> College at 12:17:46;
- Phinis -> Riften at 12:18:01;
- Wylandriah -> College at 12:18:31.

Each trip emitted exactly one start and one completion one second apart. The
player confirmed that Farengar's `Yes.` and Phinis's and Wylandriah's
`Of course.` were audible, lip-synced, and finished as expected. Phinis's
preceding custom `Where do you need to go?` remained silent and subtitled as
designed. Skyrim exited after four completed trips.

### Transport and fare regression

The monitored 2026-07-31 run covered all four directed edges and the failure
branch. Skyrim logged five successful trips, each with exactly one start and
one completion:

- College at 11:51:50, then Whiterun at 11:52:11;
- College at 11:52:27, then Riften at 11:52:39;
- College again at 11:53:12 after adding funds.

At 11:52:59, a College trip with only 72 gold logged exactly one denial
(`required=250 available=72`) and no start or completion. The player confirmed
that the route dialogue and Phinis submenu worked. That earlier run did not
check audio or lip sync. In particular, the owned hub response
`Where do you need to go?` is intentionally subtitle-only; the subsequent
destination response `Of course.` was verified in the later presentation pass.
No DNT errors were present in Papyrus, and Skyrim was no longer running when
the logs were collected.

## Safety and environment

- Treat the released LoreRim list as the clean baseline. Do not disable, reorder,
  replace, or edit mods in its stack to manufacture a "clean" test.
- The development mod is installed at
  `D:\Lorerim\mods\DiegeticTravel`.
- The user's current `[No Delete] 32x9 AIO` is enabled in
  `UltraDiegeticTravel`. The older
  `32x9 USERS ENABLE THIS - Misc AIO Patch for LoreRim` is intentionally
  disabled and must remain disabled; it is obsolete and has a broken BTPS icon.
- Do not launch Skyrim without the user's explicit approval.
- Do not edit `C:\Users\Theo\Documents\PickUpAsJunk`; another Codex task may be
  using it.

## Last carriage live test

- The fixed root fragment fired and matched the Whiterun driver.
- The destination menu showed only its first generated entry, Darkwater
  Crossing, because INFO OnBegin refreshed globals too late for the menu's
  choice snapshot.
- Darkwater Crossing displayed 800 gold / 5.60 hours.
- The purchase trace committed exactly 800 gold with CFTO destination code 11,
  and the player arrived at Darkwater Crossing. The stale-price/payment defect
  is fixed; menu population timing remains the target.

## Root cause and current source fix

Inspection found that generated root INFO `CFTO.esp:09D8C7` in
`DiegeticTravel.esp` had no VMAD subrecord. Consequently,
`DNT_PrepareOrigin.Fragment_0` never ran, while the destination purchase
fragments did run.

`tools/xedit/DNT_GeneratePlugin.pas` now makes INFO VMAD creation explicit:

- create the destination VMAD container;
- copy the template VMAD into it;
- set the fragment to `DNT_PrepareOrigin.Fragment_0`;
- explicitly set the INFO fragment timing flag to OnBegin;
- fail generation if the expected VMAD/script/fragment structure is absent.

The fix was regenerated and deployed on 2026-07-30. The active
`UltraDiegeticTravel` load-order winner now carries:

- `DNT_PrepareOrigin.Fragment_0` as the root INFO's OnBegin fragment;
- a bound `DNT_PrepareOrigin` script attachment;
- a non-null `Coordinator` property pointing at
  `000853:DiegeticTravel.esp`.

The deployed ESP SHA-256 is
`ED86F4205C6DE6B3391A5878B63A6001C414B7006D8883C2256AAE2E268205F1`.
The pre-deployment mod folder is backed up at
`build\backups\DiegeticTravel-20260730-184454`.

This deployed build was tested successfully for payment and CFTO handoff, but
confirmed the INFO OnBegin timing defect described above.

The workspace source now implements the timing fix:

- `DNT_DialogueMenuListener` is a player `ReferenceAlias` script;
- it registers for `Dialogue Menu` on initialization and after every save load;
- menu open resolves `Game.GetCurrentCrosshairRef()` and preloads every quote
  for the matched origin;
- `DNT_PrepareOrigin` reuses the completed cache instead of clearing it;
- `DNT_OriginService.RefreshQuotes` returns the available-route count, logged as
  `MENU_QUOTES_READY origin=<origin> available=<count>`;
- the generator adds the player alias/VMAD listener binding and emits the
  eligible start-game quest FormIDs; the PowerShell launcher serializes them
  into `Seq\DiegeticTravel.seq`;
- the origin services no longer all refresh the shared globals during startup.

The six Papyrus scripts compile cleanly, all ten Python tests pass, and the
generated ESP completed both off-order and active-load structural readback. The
coordinator quest has a forced player alias (ID 0), the alias VMAD points back
to that quest and alias ID, and `DNT_DialogueMenuListener.Coordinator` points at
the coordinator quest.

The first Pascal binary SEQ writer was rejected during validation:
JvInterpreter wrote twelve copies of `0x00000013` instead of raw FormIDs, and it
included an already-SGE CFTO quest override. The final build mirrors xEdit's
built-in eligibility rule, writes the fixed FormIDs to a text manifest, and lets
PowerShell serialize the four-byte little-endian entries with format,
uniqueness, and byte-count checks. The deployed 44-byte SEQ contains the 11
unique IDs `0x06000852` through `0x0600085C`.

The timing-fix package was deployed on 2026-07-30 after Skyrim closed. Only
`D:\Lorerim\mods\DiegeticTravel` was overlaid; no profile or other mod was
changed. The pre-deployment folder is backed up at
`build\backups\DiegeticTravel-20260730-201745`.

Deployed/package hashes:

- `DiegeticTravel.esp`:
  `63170DA469959069D8BD8841657AEEAD9E0D6522B7CB8EBBBA2FAD88F31B1E8C`
- `Seq\DiegeticTravel.seq`:
  `50BF3B406D9033462103C045C8727C29197C5747DC11504D4FC4E437ECA6ED4D`
- `dist\DiegeticTravel-alpha.zip`:
  `DA98AAF9FDE2FB9C4031EB477067C6132FA444E57F2B6D608B58003DAFFC1061`

No live Skyrim test of the menu-preload listener has been launched yet. Because
this update adds an alias to an already start-game-enabled quest, prefer the
gameplay harness's fresh test save/new-game path; an existing save may retain
the old running quest instance instead of reconstructing its new alias.

## xEdit work

- `tools/Generate-Plugin.ps1` uses managed Windows UI Automation only; the
  temporary dynamic C#/PInvoke implementation was removed after Defender
  flagged the Codex transcript containing it.
- The current xEdit executable still presents the Module Selection dialog.
  Managed UI Automation did not activate its OK button during the successful
  2026-07-30 build, so the user clicked OK once. The wrapper now treats the
  generator's terminal `success` status plus a clean xEdit exit as authoritative
  and does not falsely reject that completed run.
- The exact xEdit 4.1.5f source checkout is under ignored `.tools/`.
- The distributable source patch is
  `tools/xedit/patches/xedit-4.1.5f-script-autoload-autoexit.patch`.
- The patch makes `-autoload` and `-autoexit` available in Script mode. Stock
  xEdit parses those switches only in Edit mode even though Script mode has the
  corresponding load/shutdown paths.
- Delphi 12 Community is installed with its Win64 compiler files. The exact
  xEdit 4.1.5f source targets Delphi 11; all pinned source submodules (including
  nested JCL/JEDI) were initialized on 2026-07-30. MSBuild reaches `dcc64` but
  Community reports that the product does not support command-line compiling
  and produces no executable. Build the patched project through the RAD Studio
  IDE; the patched executable has not yet been produced or tested.

## houseCARL

houseCARL looks highly relevant because it provides headless Mutagen-backed MO2
record inspection, plugin authoring, Papyrus compilation, and dialogue/VMAD
validation. It may eventually replace the xEdit generator while leaving xEdit
as an independent verifier.

Both required runtimes are installed and verified:

- `Microsoft.NETCore.App 9.0.18`
- `Microsoft.AspNetCore.App 9.0.18`

houseCARL is installed and persistently configured to the MO2 instance at
`D:\Lorerim`. `UltraDiegeticTravel` had `DiegeticTravel` and
`DiegeticTravel.esp` active during the recorded validation; do not assume the
currently selected profile while the parallel gameplay test is running.

Post-deployment read-only validation of the timing-fix build on 2026-07-30
found:

- the root carriage topic winner is `DiegeticTravel.esp`;
- the root topic graph is OK and its one INFO has a bound, compiled result
  fragment;
- the Mixwater topic graph is OK and its purchase fragment is bound and
  compiled;
- the coordinator's forced player alias, alias VMAD quest/ID link, listener
  script, and `Coordinator` property all resolve to the generated coordinator
  quest;
- `DiegeticTravel.esp` has 0 dangling references, 0 missing masters, and
  0 unscannable records;
- 39 scripted records have 0 unbound properties, 0 bound-null properties, and
  0 unverifiable attachments.

`TasteOfDeath_Addon_Dialogue.esp` remains excluded from Mutagen inspection due
to an unrelated PKCU data-count mismatch. Every other plugin, including
DiegeticTravel, remains inspectable; do not alter that upstream mod as part of
this project.

## Verification at checkpoint

`$env:PYTHONPATH='src'; python -m unittest discover -s tests -v`

passes all 10 tests. The six current Papyrus scripts also compile with 0 errors
and 0 warnings.

`tools\Generate-Plugin.ps1 -LoreRimRoot D:\Lorerim` completed successfully.
The staged CFTO SHA-256 exactly matched the current `D:\Lorerim` source:
`17581B6A701A90F0F8DE71AB893B7D24F0BAA39E8B35B9522DF5FDC254B6710D`.
After the six-script compile and structural validation,
`tools\Build-Alpha.ps1 -PackageOnly` wrote
`dist\DiegeticTravel-alpha.zip` with SHA-256
`DA98AAF9FDE2FB9C4031EB477067C6132FA444E57F2B6D608B58003DAFFC1061`.
`Compress-Archive` includes fresh directory timestamps, so rebuilding the same
contents can change the ZIP hash; the ESP, SEQ, PEX, and runtime hashes are the
stable artifact checks.
