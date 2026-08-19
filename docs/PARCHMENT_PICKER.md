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
- Missing map or marker artwork logs a warning and retains a usable fallback.

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

Third-party map artwork is referenced from installed dependencies and is not
redistributed. Bundled marker provenance and permissions are recorded in
`ASSET_POLICY.md` and `THIRD_PARTY_ASSETS.md`.

Formal wizard/carriage maps use the calibrated FWMF paper-map crop and Norden
symbols by default. Ferry maps use the rough parchment profile and the
project's edited anchor/boat language.

## Verification

The native core has offline tests for request validation, layout, hitbox
separation, controller navigation, catalogue loading, quotes, and stable
destination enumeration. Provider and package audits additionally
enforce the single native marker resolver across source, DLL, and PEX as well
as exact script/plugin inventories and asset provenance.
