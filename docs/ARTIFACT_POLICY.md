# Generated artifact policy

The repository tracks reviewed source, authored/authorized visual assets, and
the one binary seed required by the consolidated xEdit workflow. Reproducible
compiler and intermediate-plugin output is ignored.

## Tracked binary seed

- `modules/wizard-guides/mod/DiegeticTravelWizardGuides.esp`
- `modules/wizard-guides/mod/SEQ/DiegeticTravelWizardGuides.seq`

The consolidated generator copies the wizard-guide ESP into ignored staging,
then appends the remaining release records and finalizes the result as
`build/release/DiegeticTravel.esp`. The SEQ file records the reviewed seed's
start-game quest and remains paired with it for isolated inspection.

## Reproducible, untracked outputs

- every module `Scripts/*.pex` file;
- `DNTParchmentPicker.dll`;
- the former wizard-parchment, carriage-parchment, and boat module ESP/SEQ
  intermediates;
- everything under `build/` and `dist/`.

`tools/Build-Release.ps1` recompiles Papyrus and native code, generates the
consolidated ESP-FE/SEQ in `build/release`, audits the package boundary, and
writes the ZIP under `dist`. `-PackageOnly` is therefore valid only after a
successful full build has populated the ignored artifacts in the current
workspace.

Generated DDS files remain tracked for now because they are release artwork
inputs and the consolidated builder does not yet regenerate the complete set.
