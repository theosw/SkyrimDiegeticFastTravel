# Deferred parchment icon themes

Status: authoring/calibration concept only. The beta runtime ships and uses the
Norden theme; it has no icon-theme setting or MCM.

## Decision

Wizard-guide and carriage parchment maps share one user preference:

- `Norden` is the default icon theme.
- `Vanilla` is the fallback and alternate theme.
- Boat maps keep their route-specific dock and ship artwork and ignore this
  preference.

The setting is global because mixing icon languages between the two mainland
travel maps makes the interface harder to learn and doubles the MCM surface
without adding a useful choice.

## Runtime contract

The shared parchment adapter owns one integer setting:

- `0`: Vanilla
- `1`: Norden

Both the wizard and carriage picker scripts read the setting when `OpenMap`
begins. They must not cache it in script state. A change therefore applies to
the next map opened and remains safe for existing saves.

This is not implemented in the beta. The vanilla set remains available as
authoring source but is deliberately excluded from the release ZIP.

## MCM surface

Add one list option under a `Map presentation` page:

`Map icon style: Norden | Vanilla`

The MCM should write only the shared setting. It must not edit coordinates,
replace texture files, restart quests, or touch active parchment requests.

SkyUI becomes a declared dependency only when the MCM quest and script are
actually shipped. Until then, the checked-in map configs and calibrator may
preview both themes without changing the runtime dependency set.

## Asset mapping

Wizard maps use hold-specific Norden capitals or their existing vanilla
palace/city equivalents. The College origin uses the Norden Winterhold capital
or the vanilla College marker.

Carriage maps use the same capital mapping. Minor Norden stops retain their
town, settlement, farm, mill, and mine categories; the Vanilla theme uses the
generic vanilla town marker for those stops.

## Calibration tool

The local map coordinate calibrator previews either icon theme without
changing marker coordinates. Its exported patch records the active preview
theme as metadata only. The draggable payment label exports separately under
`ui_positions`, keeping interface placement independent from travel markers.
