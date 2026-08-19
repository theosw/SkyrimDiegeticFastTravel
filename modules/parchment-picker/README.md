# Native parchment destination picker

`DNTParchmentPicker.dll` is the shared native UI and carriage-catalogue runtime
for Diegetic Travel. It presents a blocking Menu Framework window, owns input
and texture lifetime, and returns a stable selection result. It does not charge
the player, advance game time, or move actors.

## Release responsibilities

- `ParchmentCore` validates bounded requests, layout, hitboxes, marker optics,
  controller navigation, route origins, and inactive landmarks.
- `ParchmentMenu` owns one active menu session, texture caches, HUD suppression,
  mouse/controller input, rendering, and mod-event result delivery.
- `TravelCatalog` loads the flat carriage catalogue from
  `travel_catalog.tsv`.
- `PricingConfig` loads and validates user-tunable fares and estimate display
  settings from `SKSE/Plugins/DiegeticTravel.ini`, retaining per-field safe
  defaults when a value is missing or invalid.
- `TravelRuntime` resolves carriage origins, builds the native request, quotes
  fare/hours, exposes the immutable wizard/ferry pricing snapshot, maps the
  selected index back to a stable destination ID, and returns the resolved
  arrival `ObjectReference` from that same catalogue entry at purchase time.
- `Papyrus.cpp` exposes the provider-neutral native API plus single-call
  carriage and College request builders and quote bindings.

Papyrus provider scripts supply request metadata and perform Skyrim world
mutation after native selection: payment, time advancement, fade, and movement.
Carriage Papyrus contains no destination/FormID registry.

## Request contract

A provider may set:

- source label and footer position;
- map texture, crop, and aspect ratio;
- route-origin marker and inactive route landmarks;
- default marker and selection-ring textures;
- per-destination marker texture, marker scale, and selection-ring optics.

The picker supports at most 32 destinations and 48 inactive landmarks. It does
not contain the retired transparent-overlay or dynamic route-segment engines.
That keeps the release request small and avoids Papyrus work for features no
shipped provider uses.

## Result contract

`Show` validates and opens a complete request. Selection or cancellation emits
`DNT_ParchmentResult` with the request ID and selected zero-based index (`-1`
for cancel). Generic providers translate that index through their own stable
destination table. The native carriage builder instead retains the ordered
stable IDs and consumes the result through `ConsumeCarriageSelectionId`. The
College builder emits its fixed seven destinations in the same order as the
Papyrus index table.

## Artwork and dependencies

Map artwork remains external and is selected by provider configuration. The
release includes project-owned/edited ferry markers plus Skyrim-derived and
open-permission NORDIC UI symbols documented in `docs/ASSET_POLICY.md` and
`docs/THIRD_PARTY_ASSETS.md`.

Runtime dependencies are SKSE, Address Library, Menu Framework, and the game
runtime pinned by the native build. JContainers is not required.

## Pricing configuration

`SKSE/Plugins/DiegeticTravel.ini` is read once at `kDataLoaded`; changing it
requires a game restart. It controls the carriage distance coefficients,
minimum/rounding step, the flat College fare, optional local/regional/extra
ferry overrides, and whether carriage-hour estimates are shown and marked as
approximate. Ferry overrides feed both the map and the payment transaction.
With no override, ferries follow CFTO's live fare globals by default.

The optional Baan Malur add-on is intentionally excluded: its external quest
owns the fixed 30-gold transaction, so configuring only the displayed price
would be unsafe.

## Verification

From the repository root:

```powershell
cmake --build --preset parchment-ae
ctest --preset parchment-ae
.\tools\Compile-ParchmentPickerPapyrus.ps1
.\tools\Audit-ParchmentPicker.ps1
```

The complete release path is `.\tools\Build-Release.ps1`.

The direct commands above retain symbols for development. The release builder
uses the optimized `parchment-ae-release` build and test presets for the
packaged DLL.
