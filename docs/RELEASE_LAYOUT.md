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

`DiegeticTravel-BaanMalur-Addon.zip` contains
`DiegeticTravelBoatBaanMalur.esp`, one SEQ, and three Papyrus script pairs. It
requires the main Diegetic Fast Travel runtime, Journey to Baan Malur and
Morrowind, and Solstheim and Baan Malur Paper Map for FWMF.

The add-on exposes the Raven Rock / Baan Malur / Cormaris public triangle and
the verified stage-5 one-way trip to Sunmul from all three public captains. Its ESP-FE alone has
`Journey to Baan Malur.esp` as a master. The main `DiegeticTravel.esp` audit
continues to require exactly its six existing masters, so users without Baan
Malur install only the main archive and retain every other travel service.

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

The build creates `dist\DiegeticTravel-beta.zip`. The archive also contains
the restart-time `SKSE\Plugins\DiegeticTravel.ini` pricing configuration.
Packaging rejects any legacy module plugin/SEQ, test harness, PDB, or
unexpected executable. It then runs
xEdit Check for Errors against an isolated copy of the release plugin and its
six masters.

The modular plugins are never copied into the release archive. A topology
change from the modular development build requires a new/disposable save for
gameplay verification.

When Skyrim and MO2 are both closed, the recoverable deployment command is:

```powershell
.\tools\Deploy-Release.ps1 -LoreRimRoot "D:\Lorerim"
```

It backs up the previous `mods\DiegeticTravel` directory under `build`, replaces
only that exact directory, and verifies the one-plugin/one-SEQ topology. It does
not edit any MO2 profile. Disable the separate wizard-guide, parchment,
carriage, boat, Baan Malur, and state-gate development mods manually before the
fresh-save release test.

Build and audit the optional add-on independently with:

```powershell
.\tools\Build-BoatBaanMalur.ps1 -LoreRimRoot "D:\Lorerim"
```

This produces `dist\DiegeticTravel-BaanMalur-Addon.zip` and rejects bundled
DLLs, map textures, audio, or any file outside the one-plugin/one-SEQ/three-
script-pair inventory.
