# Diegetic Travel handoff

Updated: 2026-07-30

## Safety and environment

- Treat the released LoreRim list as the clean baseline. Do not disable, reorder,
  replace, or edit mods in its stack to manufacture a "clean" test.
- The development mod is installed at
  `D:\Lorerim\mods\DiegeticTravel`.
- The user enabled the appropriate 32:9 AIO during the earlier live test.
  houseCARL reported it disabled after the switch to `UltraDiegeticTravel`;
  verify that display-specific mod is enabled before the next visual test.
- Do not launch Skyrim without the user's explicit approval.
- Do not edit `C:\Users\Theo\Documents\PickUpAsJunk`; another Codex task may be
  using it.

## Last live test

- Carriage dialogue appeared and displayed generated fare/time labels.
- Selecting Mixwater Mill from Whiterun successfully charged the player and
  completed CFTO travel.
- The purchase log recorded a fare of 700, but the dialogue text showed a stale
  or otherwise incorrect gold amount.

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

This deployed build has not yet been tested in game.

There is a second timing risk: dialogue choices may be rendered before an INFO
OnBegin fragment can refresh globals used by sibling topic labels. houseCARL's
dialogue-authoring guidance recommends preparing those globals on
`RegisterForMenu("Dialogue Menu")`. If the regenerated VMAD still produces
stale labels, move quote preparation to that menu-open event instead of adding
more INFO-fragment timing assumptions.

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
- Delphi 12 was installed during this session, but the patched xEdit executable
  has not yet been compiled or tested. The exact xEdit 4.1.5f source targets
  Delphi 11 and its submodules/package dependencies are not initialized.

## houseCARL

houseCARL looks highly relevant because it provides headless Mutagen-backed MO2
record inspection, plugin authoring, Papyrus compilation, and dialogue/VMAD
validation. It may eventually replace the xEdit generator while leaving xEdit
as an independent verifier.

Both required runtimes are installed and verified:

- `Microsoft.NETCore.App 9.0.18`
- `Microsoft.AspNetCore.App 9.0.18`

houseCARL is installed and persistently configured to the MO2 instance at
`D:\Lorerim`. The active profile is `UltraDiegeticTravel`, the
`DiegeticTravel` mod is enabled, and `DiegeticTravel.esp` is active.

Post-deployment read-only validation on 2026-07-30 found:

- the root carriage topic winner is `DiegeticTravel.esp`;
- the root topic graph is OK and its one INFO has a bound, compiled result
  fragment;
- the Mixwater topic graph is OK and its purchase fragment is bound and
  compiled;
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

passes all 10 tests. No Skyrim launch was performed while creating this
checkpoint.

`tools\Build-Alpha.ps1 -LoreRimRoot D:\Lorerim` also completed successfully:
all five Papyrus scripts compiled with 0 errors and 0 warnings, and the alpha
package was written to `dist\DiegeticTravel-alpha.zip` with SHA-256
`C34F4D9B78D4EEE8B3F7209F2A17B62FC39BA9D79F35ADDB95E84151501F63DC`.
