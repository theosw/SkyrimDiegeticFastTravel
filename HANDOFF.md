# Diegetic Travel handoff

Updated: 2026-07-30

## Safety and environment

- Treat the released LoreRim list as the clean baseline. Do not disable, reorder,
  replace, or edit mods in its stack to manufacture a "clean" test.
- The development mod is installed at
  `D:\Lorerim\mods\DiegeticTravel`.
- The user also enabled the appropriate 32:9 AIO for the test display; preserve
  that profile choice.
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

This fix has not yet been regenerated, deployed, or tested in game.

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
- The exact xEdit 4.1.5f source checkout is under ignored `.tools/`.
- The distributable source patch is
  `tools/xedit/patches/xedit-4.1.5f-script-autoload-autoexit.patch`.
- The patch makes `-autoload` and `-autoexit` available in Script mode. Stock
  xEdit parses those switches only in Edit mode even though Script mode has the
  corresponding load/shutdown paths.
- Delphi was installed during this session, but the patched xEdit executable
  has not yet been compiled or tested. xEdit 4.1.5f targets Delphi 11; current
  development source targets Delphi 12.

## houseCARL

houseCARL looks highly relevant because it provides headless Mutagen-backed MO2
record inspection, plugin authoring, Papyrus compilation, and dialogue/VMAD
validation. It may eventually replace the xEdit generator while leaving xEdit
as an independent verifier.

Both required runtimes are installed and verified:

- `Microsoft.NETCore.App 9.0.18`
- `Microsoft.AspNetCore.App 9.0.18`

houseCARL itself has not been installed yet. Its setup should be run while Codex
is fully closed, followed by reopening Codex. Begin with read-only inspection of
the LoreRim load order, then write only to a disposable new DNT probe mod. Do not
use its in-place editing lane against LoreRim's existing stack.

Suggested first audit:

1. Inspect the effective CFTO/DNT root INFO, destination INFOs, VMAD fragments,
   quest `Text Display Globals`, and conflict winners.
2. Validate the generated dialogue graph and `<Global=...>` bindings.
3. Create a disposable `houseCARL - DNT Probe` output and compare its records
   with the xEdit-generated plugin.
4. Decide whether the quote refresh belongs in an INFO fragment or a persistent
   menu-open listener.

## Verification at checkpoint

`$env:PYTHONPATH='src'; python -m unittest discover -s tests -v`

passes all 10 tests. No Skyrim launch was performed while creating this
checkpoint.
