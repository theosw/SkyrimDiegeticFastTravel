# Dependency lock

`dependencies.lock.json` is the machine-readable source of truth for the
current LoreRim development target. `tools/Audit-NativeDependencies.ps1`
verifies it without launching Skyrim.

## Runtime target

- Skyrim `1.6.1170.0`
- SKSE `2.2.6`
- Address Library `11.0.0.0`, exact `versionlib-1-6-1170-0.bin`
- SKSE Menu Framework `3.9.0.0` (runtime interface reports `3.7`)
- Carriage and Ferry Travel Overhaul `2.0.0.0` (Nexus 8379)
- Carriage and Ferry Travel Overhaul - Fixes and Winterhold `3.0.0.0`
  (Nexus 40651), installed after the base mod; this supplies the pinned
  `CFTO.esp` master and record layout
- `DiegeticTravel.esp` as the consolidated ESL-flagged travel authority

The tested visual setup also includes two recommendations whose hashes remain
pinned when present, but whose absence no longer fails the dependency audit:

- RUSTIC MAPS `2.0.0.0`, which overrides the physical-map paths used by boat
  providers;
- Skyrim Paper Map by Caro Tuts for FWMF `1.72.0.0`, the preferred wizard and
  carriage chart at `textures/terrain/tamriel/skyrim.dds`.

Without either mod, the native picker reads Bethesda's physical maps through
Skyrim's archive-aware resource stream. Wizard and carriage requests switch to
a calibrated `battlemap01.dds` profile; boat requests retain their existing
coordinates because the loose replacer and archived original share a path.

The tested profile also includes Wait Carriage in Inns `1.3.0.0` (Nexus
83044). That integration is optional and uses soft plugin lookups, but its
local FormIDs are version-sensitive; other versions are not covered by the
current compatibility claim.

Wizarding Traversal Magic `1.43.0.0` (Nexus 124125) is also an optional,
soft-detected compatibility target. When present, Diegetic Travel recognizes
its active Apparition speed override and uses zero-time `MoveTo` travel. It is
not a plugin master, and its absence retains ordinary time-passing travel.

Every installed payload above is pinned by SHA-256. Optional integration and
artwork hashes are verified when those files are present; their absence does
not fail the dependency audit. The lock describes the isolated
`UltraDiegeticTravel` test profile, not the complete LoreRim modlist.

## Optional Baan Malur add-on target

The separately packaged `DiegeticTravelBoatBaanMalur.esp` requires:

- Journey to Baan Malur and Morrowind `i1.1.9b` (Nexus 114518);
- Solstheim and Baan Malur Paper Map for FWMF `1.0.0.0` (Nexus 137315).

Both installed inputs are pinned under `optionalAddonDependencies`. They are
deliberately outside `targetRuntime`: neither is required to build, install,
or run the main `DiegeticTravel.esp`. The add-on archive must not be installed
unless Journey to Baan Malur is present, and it references rather than bundles
the external map texture.

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

## Required verification

Run before every native candidate build:

```powershell
./tools/Audit-NativeDependencies.ps1
```

The audit fails on a runtime hash/version change or CommonLib commit drift.
Updating the lock requires a fresh research and live-compatibility pass. The
retired native voice experiment and its private `Script::CompileAndRun`
relocation are not part of the release runtime.

## Distribution boundary

Pinned runtime hashes describe separately installed requirements and tested
optional recommendations; they are not redistribution permission. The repository and release package contain no
RUSTIC MAPS texture, Caro Tuts map texture, Baan Malur map texture, Bethesda
FUZ/XWM, BCD asset, or Menu Framework binary. See `docs/ASSET_POLICY.md` for
the packaging rules and fallbacks.
