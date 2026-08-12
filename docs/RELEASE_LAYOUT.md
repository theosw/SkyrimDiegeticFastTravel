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

The Baan Malur experiment and Better Carriage Destinations wizard-map adapter
remain development-only.

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

The build creates `dist\DiegeticTravel-beta.zip`. Packaging rejects any legacy
module plugin/SEQ, test harness, PDB, or unexpected executable. It then runs
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
