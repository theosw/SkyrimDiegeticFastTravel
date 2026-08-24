# Parchment picker design contract

Status: gameplay-proven with mouse and controller at 32:9. The release uses one
native picker for wizard guides, carriages, mainland ferries, Lake Honrich,
Lake Ilinalta, and Solstheim ferries.

## Accepted architecture

The picker is a provider-neutral selection frontend. It owns presentation and
input only. Provider services remain responsible for availability, payment,
time, fade, and movement.

Each request contains bounded value data:

- request/provider IDs and source label;
- external map texture, UV crop, and aspect ratio;
- optional fallback artwork with its own texture, crop, aspect, and affine
  coordinate transform;
- destination IDs, labels, fares, normalized coordinates, and marker optics;
- optional route origin and inactive landmark markers;
- optional payment-label position.

The release deliberately excludes the experimental transparent-overlay and
dynamic route-segment/pathfinding systems. Current maps communicate topology
through provider-filtered markers, round-trip/one-way selection rings, and
inactive dock landmarks.

## Input and lifecycle

- Mouse hover and controller focus select exactly one destination visually.
- Click/confirm returns its zero-based index.
- Escape/cancel returns `-1`.
- No destination receives default focus when the menu first opens.
- HUD layers hidden for the picker are restored on every close path.
- Missing preferred map artwork selects the fallback profile once per request;
  marker art still degrades to its provider fallback and logs a warning.
- `PreferFormalMapArtwork=false` reverses that resolution order for College
  and carriage requests: the calibrated physical profile is tried first and
  the formal chart remains a safety fallback.

## Provider boundary

Generic provider Papyrus builds the request through `DNT_ParchmentNative` and
translates the result index through its stable destination list. Carriages use
the native catalogue builder and consume a stable destination ID, avoiding a
28-stop Papyrus construction loop.

The selected destination is revalidated by the provider service immediately
before payment and travel. Carriages resolve the arrival `ObjectReference`
through the same native catalogue that displayed and quoted the destination;
Papyrus contains no parallel marker table. Apparition compatibility is
evaluated at commit time from the current speed override, so adding or removing
the effect between trips is respected.

## Artwork policy

Third-party map artwork is referenced from installed recommendations and is not
redistributed. Because Menu Framework only opens filesystem files, the native
wrapper materializes an archived Bethesda DDS through Skyrim's resource stream
into a bounded operating-system cache when no loose override exists. Bundled
marker provenance and permissions are recorded in `ASSET_POLICY.md` and
`../THIRD_PARTY_NOTICES.txt`.

Formal wizard/carriage maps use the calibrated FWMF paper-map crop and Norden
symbols by default. If that preferred chart is missing, the complete request
switches to a calibrated vanilla battle-map profile; destinations, route
origins, fare text, and hitboxes all use the same affine transform. The
restart-time display preference selects the same physical profile without
hiding or renaming FWMF assets. Ferry maps
use the rough parchment profile and the project's edited anchor/boat language;
RUSTIC MAPS overrides the same Bethesda paths when installed.

## Verification

The native core has offline tests for request validation, preferred/fallback
coordinate transforms, transformed hitbox separation, layout, controller
navigation, catalogue loading, quotes, and stable
destination enumeration. Provider and package audits additionally
enforce the single native marker resolver across source, DLL, and PEX as well
as exact script/plugin inventories and asset provenance.
