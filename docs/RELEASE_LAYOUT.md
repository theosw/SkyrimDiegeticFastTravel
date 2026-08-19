# Consolidated release layout

Development remains split into isolated modules so each travel provider can be
generated, audited, and tested independently. Distribution is deliberately
different: users receive one `DiegeticTravel.esp` and one matching SEQ file.

## Included in the consolidated ESP-FE

- core travel/quote services
- College wizard-guide star
- wizard parchment dialogue adapter
- carriage parchment dialogue adapter
- Lake Honrich ferries
- Lake Ilinalta ferries
- north-coast ferries
- Solstheim ferries

The Better Carriage Destinations wizard-map adapter remains archived. Baan
Malur support is maintained as a separate optional ESP-FE and is never merged
into this consolidated plugin.

## Optional Baan Malur add-on

`DiegeticTravel-BaanMalur-Addon-<version>-<UTC timestamp>.zip` contains
`DiegeticTravelBoatBaanMalur.esp`, one SEQ, and three Papyrus script pairs. It
requires the main Diegetic Fast Travel runtime, Journey to Baan Malur and
Morrowind, and Solstheim and Baan Malur Paper Map for FWMF.

The add-on exposes the Raven Rock / Baan Malur / Cormaris public triangle and
the verified stage-5 one-way trip to Sunmul from all three public captains. Its ESP-FE alone has
`Journey to Baan Malur.esp` as a master. The main `DiegeticTravel.esp` audit
continues to require exactly its six existing masters, so users without Baan
Malur install only the main archive and retain every other travel service.

For the three supported captains, the add-on replaces Journey's parallel
native destination prompt by default. A static provider list keeps the prompt
intact for every other Journey captain, and the diagnostic global
`DNT_ShowBaanMalurNativeDialogue` can restore it. The add-on build proves both
that condition topology and Journey's shared `Where are you headed?` FUZ.

## Optional LoreRim BCD coexistence patch

`DiegeticTravel-LoreRim-BCD-Compat-<version>-<UTC timestamp>.zip` contains one ESL-flagged
`DiegeticTravelLoreRimBcdCompat.esp` plus its README. It requires the main
release and LoreRim's enabled Better Carriage Destinations base, CFTO adapter,
and Wait Carriage in Inns adapter. It gates exactly three competing BCD
dialogue INFOs while retaining their original fragments and conditions.

The compatibility patch is generated and audited independently. It never adds
a BCD master to the main `DiegeticTravel.esp`, so the main archive continues to
contain exactly one plugin with six masters.

## Fixed local FormID blocks

| Block | Owner |
|---|---|
| `0x800` | wizard-guide seed |
| `0x900` | core travel records |
| `0xA00` | wizard parchment |
| `0xA20` | carriage parchment |
| `0xA40` | Lake Honrich |
| `0xA60` | Lake Ilinalta |
| `0xA80` | north coast |
| `0xAA0` | Solstheim |

The finalizer refuses a next-object ID above `0x1000`, a non-ESL-capable
plugin, an unexpected master, or a combined SEQ other than the expected 17
start-game quests.

## Build and audit

```powershell
.\tools\Build-Release.ps1 -LoreRimRoot "D:\Lorerim"
```

The build creates a candidate such as
`dist\DiegeticTravel-0.1.0-beta-20260819T193802Z.zip`. The archive also contains
the restart-time `SKSE\Plugins\DiegeticTravel.ini` pricing configuration.
Packaging rejects any legacy module plugin/SEQ, test harness, PDB, or
unexpected executable. It then runs
xEdit Check for Errors against an isolated copy of the release plugin and its
six masters. Before packaging—even with `-PackageOnly`—the release builder also
audits the exact vanilla and CFTO voice assets borrowed by wizard and ferry
presentation records.

The modular plugins are never copied into the release archive. A topology
change from the modular development build requires a new/disposable save for
gameplay verification.

`config\release.json` owns the semantic version. The main builder adds a fresh
compact UTC timestamp and, after a successful package, writes the shared
identity to `build\release-identity.json`. Every ZIP has an adjacent
`<archive>.zip.meta` sidecar containing the same identity in MO2's `modName`
and `version` fields. Keep that sidecar beside the ZIP when opening the archive
in MO2; it is what makes Quick Install suggest the complete timestamped name
instead of MO2's shortened filename guess.

When Skyrim and MO2 are both closed, the recoverable deployment command is:

```powershell
.\tools\Deploy-Release.ps1 -LoreRimRoot "D:\Lorerim"
```

It backs up the previous `mods\DiegeticTravel` directory under `build`, replaces
only that exact directory, and verifies the one-plugin/one-SEQ topology. It does
not edit any MO2 profile. Disable the separate wizard-guide, parchment,
carriage, boat, Baan Malur, and state-gate development mods manually before the
fresh-save release test.

After building the main candidate, build and audit the optional add-on with:

```powershell
.\tools\Build-BoatBaanMalur.ps1 -LoreRimRoot "D:\Lorerim"
```

This reuses the main candidate's identity and produces
`dist\DiegeticTravel-BaanMalur-Addon-<version>-<UTC timestamp>.zip`. It rejects
bundled DLLs, map textures, audio, or any file outside the one-plugin/one-SEQ/
three-script-pair inventory.

After the main release exists, build the LoreRim coexistence patch with:

```powershell
.\tools\Build-BcdLoreRimCompat.ps1 -LoreRimRoot "D:\Lorerim"
```

This reuses the main candidate's identity and produces
`dist\DiegeticTravel-LoreRim-BCD-Compat-<version>-<UTC timestamp>.zip`. It
rejects any package contents other than its ESL and README.
