# Dependency lock

`dependencies.lock.json` is the machine-readable source of truth for the
current LoreRim development target. `tools/Audit-NativeDependencies.ps1`
verifies it without launching Skyrim.

## Runtime target

- Skyrim `1.6.1170.0`
- SKSE `2.2.6`
- Address Library `11.0.0.0`, exact `versionlib-1-6-1170-0.bin`
- SKSE Menu Framework `3.9.0.0` (runtime interface reports `3.7`)
- RUSTIC MAPS `2.0.0.0` for the boat/carriage `battlemap01.dds`
- Skyrim Paper Map by Caro Tuts for FWMF `1.72.0.0` for the wizard
  `textures/terrain/tamriel/skyrim.dds`
- `DiegeticTravel.esp` as the consolidated ESL-flagged travel authority

Every installed payload above is pinned by SHA-256. The lock describes the
isolated `UltraDiegeticTravel` test profile, not the complete LoreRim modlist.

## Build target

- CommonLibSSE-NG official commit
  `b93280e832f263dbef44e44cbe2936622a02f91a`
- vcpkg baseline `1dc5ee30eb1032221d29f281f4a94b73f06b4284`
- Visual Studio 2022, CMake 3.24+, and the `x64-windows-static-md` triplet
- LoreRim's installed Bethesda Papyrus compiler for PEX generation

The CommonLib checkout is outside this repository. CMake uses the
`DNT_COMMONLIBSSE_NG_DIR` cache variable, accepts the environment variable of
the same name as its initial value, and retains the existing local checkout as
a development-machine default. The pre-build audit verifies its repository URL
and commit, so a path that happens to contain a different checkout cannot pass.

## Retained credited learning source

- The wizard parchment marker derives from borokoshow's
  `KWD_DBWR_ApparitionTravel.svg` in Dragonborn Reskin - Wheeler `1.9.1`.
- The exact source SVG is pinned by SHA-256 in `dependencies.lock.json`.
- Its published permissions allow reuse and modification with credit, prohibit
  sale, and allow Donation Points. `THIRD_PARTY_NOTICES.txt` travels with the
  package.
- The current release does not contain the converted derivative; the source is
  retained for provenance and rollback research only.

## Runtime relocation override

CommonLibSSE-NG still maps `RE::Script::CompileAndRun` to AE Address Library ID
`21890`. That ID does not exist in LoreRim's 1.6.1170 database; its next entry,
ID `21891`, resolves to `SkyrimSE.exe+0x33D880`, the wrong function reached by
the rejected crash candidate.

For AE runtime patches 1.6.1130 and newer, the correct ID is `441582`. On the
locked 1.6.1170 database it resolves to `SkyrimSE.exe+0x33D6A0`. The native
voice probe must use a runtime-aware wrapper and must never call CommonLib's
stock `RE::Script::CompileAndRun` method.

## Required verification

Run before every native candidate build:

```powershell
./tools/Audit-NativeDependencies.ps1
```

The audit fails on a runtime hash/version change, CommonLib commit drift,
missing modern relocation, unexpected legacy relocation, or offset mismatch.
Updating the lock requires a fresh research and live-compatibility pass.

## Distribution boundary

Pinned runtime hashes describe separately installed requirements; they are not
redistribution permission. The repository and release package contain no
RUSTIC MAPS texture, Caro Tuts map texture, Bethesda FUZ/XWM, BCD asset, or
Menu Framework binary. See `docs/ASSET_POLICY.md` for the packaging rules and
fallbacks.
