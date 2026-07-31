# Diegetic Travel handoff

Updated: 2026-07-31

## Wizard-guide Phase 1

Phase 1 of the separate wizard-guide pillar is implemented under
`modules\wizard-guides`. It does not modify the carriage checkpoint or depend
on CFTO/Better Carriage Destinations.

Network:

- The College of Winterhold is the permanent hub.
- Farengar Secret-Fire (`013BBB:Skyrim.esm`) offers the College.
- Wylandriah (`019DEF:Skyrim.esm`) offers the College.
- Phinis Gestor (`01C199:Skyrim.esm`) offers Whiterun or Riften from the
  College.
- All services are immediately available; faction, relationship, quest, and
  trust gates are deliberately deferred.
- Every hop costs 250 gold.
- Travel waits one second for dialogue to close and then calls `MoveTo`: no
  elapsed game time, rest, or recovery.

The UI-independent `DNT_WizardTravelService` exposes stable destination IDs plus
`GetFare`, `CanTravel`, and `RequestTravel`. New dialogue records call that
service through `DNT_WizardTravelFragment`; a future BCD/Shazdeh adapter can
call the same service without duplicating travel logic.

The generated plugin is `DiegeticTravelWizardGuides.esp`. It defines one
start-game-enabled quest, one top-level player branch, four custom topics, and
seven speaker-gated INFOs. It overrides no existing records. Its SEQ and two
compiled PEX files live beside it in the module.

The first spoke was proven two-way. The next staged build expands it into a
three-node star. INFO `000806` presents
`Can you teleport me to the College of Winterhold? (250 gold)` to Farengar and
binds `DestinationId=college`; INFO `000807` now provides the corresponding
Wylandriah-to-College route. INFO `000808` is the College hub:
`Can you teleport me somewhere? (250 gold per trip)`. It owns the response
`Where do you need to go?`, carries no travel fragment, and links to exactly
two destination topics:

- `000803` / INFO `00080B`: Whiterun (`DestinationId=whiterun`)
- `000804` / INFO `00080C`: Riften (`DestinationId=riften`)

All five visible INFOs own a single response instead of using Shared Info.
Travel INFOs have `Goodbye + Force Subtitle + No LIP File`, no `LinkTo`, and
run `DNT_WizardTravelFragment` on `OnBegin`. The hub has
`Force Subtitle + No LIP File`, no VMAD, and exactly two `LinkTo` entries.
The owned responses are currently unvoiced prototype subtitles:

- `Very well. The College, then.`
- `The College? Very well.`
- `Where do you need to go?`
- `Very well. Whiterun, then.`
- `Very well. Riften, then.`

Arrival markers reuse stable Skyrim references whose effective positions
already reflect the installed JK interiors:

- College: `036A67:Skyrim.esm` (`MGPhinisSleepMarker`), winner
  `JK's College of Winterhold.esp`
- Whiterun: `0B7AA5:Skyrim.esm` (`FarengarLabMARKER`), vanilla winner
- Riften: `044A4A:Skyrim.esm` (`RiftenKeepWizardLabMarker`), winner
  `JK's Mistveil Keep.esp`

Both scripts compile with 0 errors and 0 warnings. The workspace plugin parses
successfully off-order and has zero dangling references or missing masters.
Raw binary reads confirm both root INFOs own one response, have no Shared Info
or `LinkTo`, carry the correct speaker condition and destination property, and
contain an `OnBegin` fragment. Arrival-marker geometry remains a gameplay-only
check.

The preceding live pass proved that Farengar's top-level option appears, but
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

Rollback commit `a03262d` checkpoints that proven two-way build. The subsequent
workspace build adds the Riften spoke and Phinis hub without changing record
count or masters. `tools/Audit-WizardGuideStar.ps1` is a read-only, compact
headless-xEdit audit that checks only the five visible INFOs: owned responses,
speakers, flags, exact hub links, fragment timing, bound service, and stable
destination IDs. It currently reports all six PASS lines. The patcher also
produces byte-identical output on a second run. This three-node build has not
yet had its gameplay pass.

`tools/Patch-WizardGuideDialogue.ps1` now defaults to the patched headless
xEdit at `build/xedit-patched/SSEEdit64.exe`, patches the workspace copy only,
and deploys to LoreRim only when passed `-Deploy`; deployment is refused while
`SkyrimSE` is running. `-Deploy` copies the complete owned module payload so
the ESP, SEQ, and newly compiled PEX files stay in sync. The generated ESP is
byte-idempotent at SHA-256
`4B63578E5AE7A501DCEA4CC4B696DF0B21F55E2BC3E354497FCD98CAFBABA130`.
The rebuilt Phase 1 ZIP SHA-256 is
`F12D768B3FF495B5F77AF136315854C0F85721E21A0461070866780F7E736F49`.

At this checkpoint MO2's active profile is `UltraDiegeticTravel`. The complete
workspace payload has been deployed to
`D:\Lorerim\mods\houseCARL - DiegeticTravelWizardGuides`, and the installed
ESP, SEQ, PEX, and PSC files hash-match the tested workspace copies. Direct
reads of the MO2 profile files confirm the mod is enabled in the left pane and
`DiegeticTravelWizardGuides.esp` is checked in the right pane. The installed
ESP itself passes the compact six-line star audit. The new Riften/submenu build
still requires its gameplay pass. Do not launch Skyrim without coordinating
with the user; a parallel PickUpAsJunk task may also use MO2.

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

## Last live test

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
