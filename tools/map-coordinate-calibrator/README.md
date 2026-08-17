# DNT Map Coordinate Calibrator

Local developer tool for placing parchment-menu markers and optically aligning
selection rings in the exact spaces used by `DNTParchmentPicker`.

## Start it

From this directory:

```powershell
npm run sync
npm run dev
```

Open `http://localhost:3000`.

- **Map layout** (`/`) calibrates destination and payment-label coordinates.
- **Icon alignment** (`/icon-alignment`) calibrates the selection ring once per
  shared icon asset without moving the destination coordinate or clickbox.

`npm run sync` copies the current carriage, mainland ferry, Lake Honrich, Lake Ilinalta,
Solstheim ferry, and wizard-map networks; converts the exact in-game DDS marker
textures to browser previews; and builds local reference images from the RUSTIC
MAPS and Skyrim Paper Map sources plus the installed Solstheim and Baan Malur
chart. The Solstheim tabs include both the square-corrected physical ferry map
used by the local ferrymen and the regional chart used to author Captain
Remyris's merchant route. These generated assets are ignored by Git and must
not be redistributed.

## Calibrate

1. Choose **Carriage network**, **Wizard guides**, **Mainland ferries**,
   **Lake Honrich**, **Lake Ilinalta**, **Solstheim ferries**, or
   **Remyris merchant route**.
2. For carriage or wizard maps, switch between **Norden** and **Vanilla** icon
   previews without changing coordinates.
3. Enable **Authoring-only locations** to place one-way, quest-locked, broken,
   or otherwise incomplete stops. They are styled separately and exported under
   `authoring_positions`; the tool never folds them into the playable `stops` list.
4. Select a destination and tune the independent **Selection ring extent**
   slider. Formal maps and the Remyris chart preview the thin neutral selector;
   parchment ferry maps preview the parchment-colored selector. The chosen
   value is retained in the browser and exported as
   `visual_settings.selection_ring_scale`.
5. Drag markers or the payment label into place. Select one and use the arrow
   keys for one-pixel nudges; hold Shift for ten-pixel nudges.
6. Read or type normalized X/Y values in the inspector. X grows left-to-right;
   Y grows top-to-bottom.
7. Use **Copy changed patch** for a small reviewable JSON patch, or download a
   complete updated network JSON.

Draft positions are stored only in this browser. The tool never edits the mod
or deploys to LoreRim by itself.

## Align a selection ring to an icon

1. Open **Icon alignment** and select the **Norden**, **Vanilla**, or **Ferry**
   icon family. Ferry contains the selectable physical-map anchor asset;
   Captain Remyris's formal-map maritime symbols remain under Norden.
2. In **Selection arrow design**, compare the shipped texture with the
   source-matched inline-SVG web vector. Choose the **Thin** or **Norden**
   silhouette, then tune body weight, source-anchored feather weight, feather
   angle, feather-root overlap, and whole-ring rotation. Weight changes preserve
   the authored outside radius and move only the center-facing edge. Disable
   **Tune feathers separately** to hide the feather controls and apply Arrow
   weight to the complete authored contour as one piece. Use the reference
   overlay slider or the 0/50/100%
   presets to crossfade the procedural layer against the shipped texture;
   neutral settings should not produce doubled edges at 50%. Geometry settings
   are included in exported optics JSON under `procedural_selection_ring`; see
   `SELECTION_RING_HANDOFF.md` for implementation and verification details.
3. Drag the ring, nudge it with the arrow keys, or seed it from either the
   alpha-bounds center or alpha-weighted visual centroid. The cyan rectangle is
   the visible alpha extent; the cyan and orange dots show those two centers.
4. Tune the **Marker size multiplier** to resize that shared icon type in the
   native menu. It is exported as `marker_scale`; map coordinates and clickboxes
   remain fixed. The generic **Preview zoom** on the Map layout page is only a
   browser aid and is deliberately not exported.
5. Tune the per-icon ring width multiplier. This changes only the ring. Ring
   offsets continue to use the resized icon's half-extent, matching runtime.
6. Copy a changed-only patch or download the complete `icon-optics.json`.

Offsets are normalized in icon-half-extent units: `1.0` moves the ring by half
the rendered icon width or height. The native picker exposes
`SetDestinationMarkerScale`, `SetSelectionRingScale`, and
`SetDestinationSelectionRingStyle` so exported values can be applied directly
by each provider.

The Norden theme also includes the exact `Shipwreck` and `Docks` sprites used
by Captain Remyris. The map-layout preview treats Raven Rock as the fixed ship
origin and keeps every destination as an anchor while the thin selector is
overlaid independently. Selecting a destination therefore never replaces its
marker with the ship icon.

The Ferry theme aligns the parchment-colored selector to the selectable anchor.
The boat remains a fixed, non-selectable route-origin marker, so it deliberately
has no selection-ring profile. Ferry optical settings are exported separately
under `icon_optics.ferry`, so tuning physical ferry maps cannot disturb the
Norden or vanilla profiles.
