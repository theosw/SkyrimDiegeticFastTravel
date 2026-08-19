# LoreRim BCD coexistence patch

This isolated optional ESL keeps LoreRim's Better Carriage Destinations stack
loaded while returning carriage and ferry dialogue authority to Diegetic Fast
Travel. It does not remove BCD, change BCD's MCM, alter its DLL, or modify the
LoreRim profile.

`DiegeticTravelLoreRimBcdCompat.esp` overrides exactly three installed dialogue
INFO records: BCD's generic carriage entry, its CFTO ferry entry, and its Wait
Carriage in Inns entry. Each retains the original fragment and conditions, then
adds a default-off `DNT_ShowBcdTravelDialogue` global condition. Setting that
global to `1` is a diagnostic escape hatch that restores the BCD entries.

The patch is intentionally separate from the main release. The main
`DiegeticTravel.esp` remains one ESL-flagged plugin with its fixed six-master
contract. Build and audit this archive only after generating the current main
release candidate:

```powershell
.\tools\Build-BcdLoreRimCompat.ps1 -LoreRimRoot "D:\Lorerim"
```

The main build supplies the shared version/UTC timestamp in
`build\release-identity.json`. This builder carries that exact identity into
the compatibility ZIP filename and its adjacent MO2 `.zip.meta` sidecar.

Load the compatibility ESL after BCD's CFTO/WCI adapters and after
`DiegeticTravel.esp`. Never disable and re-enable the BCD mods merely to test
Diegetic Fast Travel; doing so changes LoreRim's plugin enumeration and can
append dependent patches to the end of the profile.
