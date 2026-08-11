# Native parchment destination picker

`DNTParchmentPicker.dll` is the shared native UI and carriage-catalogue runtime
for Diegetic Travel. It presents a blocking Menu Framework window, owns input
and texture lifetime, and returns a stable selection result. It does not charge
the player, advance game time, or move actors.

## Release responsibilities

- `ParchmentCore` validates bounded requests, layout, hitboxes, marker optics,
  controller navigation, presentations, route origins, and inactive landmarks.
- `ParchmentMenu` owns one active menu session, texture caches, HUD suppression,
  mouse/controller input, rendering, and mod-event result delivery.
- `TravelCatalog` loads the flat carriage catalogue from
  `travel_catalog.tsv`.
- `TravelRuntime` resolves carriage origins, builds the native request, quotes
  fare/hours, maps the selected index back to a stable destination ID, and
  resolves arrival markers.
- `Papyrus.cpp` exposes the small provider-neutral native API plus the carriage
  request/quote bindings.

Papyrus provider scripts supply request metadata and perform Skyrim world
mutation after native selection: gate revalidation, payment, time advancement,
fade, and movement.

## Request contract

A provider may set:

- source label and footer position;
- map texture, crop, and aspect ratio;
- route-origin marker and inactive route landmarks;
- default marker and selection-ring textures;
- per-destination marker texture, marker scale, and selection-ring optics;
- an optional actor-targeted voice/subtitle presentation.

The picker supports at most 32 destinations and 48 inactive landmarks. It does
not contain the retired transparent-overlay or dynamic route-segment engines.
That keeps the release request small and avoids Papyrus work for presentation
features that no shipped provider uses.

## Result contract

`Show` validates and opens a complete request. Selection or cancellation emits
`DNT_ParchmentResult` with the request ID and selected zero-based index (`-1`
for cancel). Generic providers translate that index through their own stable
destination table. The native carriage builder instead retains the ordered
stable IDs and consumes the result through `ConsumeCarriageSelectionId`.

## Artwork and dependencies

Map artwork remains external and is selected by provider configuration. The
release includes project-owned/edited ferry markers plus Skyrim-derived and
authorized Norden symbols documented in `docs/ASSET_POLICY.md` and
`docs/THIRD_PARTY_ASSETS.md`.

Runtime dependencies are SKSE, Address Library, Menu Framework, and the game
runtime pinned by the native build. JContainers is not required.

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
