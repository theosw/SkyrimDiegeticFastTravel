# Diegetic Travel handoff

Updated: 2026-07-30

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
