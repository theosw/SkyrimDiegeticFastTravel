# Selection-ring web-vector handoff

Updated: 2026-08-17

## Current result

The `/icon-alignment` page renders the thin and Norden round-trip arrows from
source-matched inline SVG paths. At neutral settings, the procedural layer and
the shipped texture share the same silhouette, scale, orientation, colors, and
transparent canvas placement.

The earlier circular generator is rejected. Although its sliders worked, it
replaced the authored asymmetry, arrowhead shoulders, fork shapes, bevel, and
shadow with idealized geometry. The difference was obvious when compared with
the texture.

The editable geometry remains a browser-calibrator feature. The accepted
cropped Norden raster is also built into the runtime round-trip DDS; the native
renderer remains unchanged because the final rotation is baked during the
asset build.

The checked-in cropped Norden raster is now the default comparison/design
source and its requested final orientation is `105` degrees. The PNG already
contains `37` degrees of authored rotation, so texture mode applies the
remaining `68` degrees at render time. Exported JSON records the final
orientation (`rotation_degrees: 105`), rather than that implementation delta.

## Implementation map

| File | Responsibility |
| --- | --- |
| `app/icon-alignment/SelectionRingVector.tsx` | Exact thin trace, exact four-layer Norden source geometry, independent radial body/feather weighting, anchored root overlap, and constrained feather rotation. |
| `app/icon-alignment/IconAlignmentCalibrator.tsx` | Texture/procedural selection, design selection, body/feather controls, comparison opacity, persistence, and JSON import/export. |
| `app/globals.css` | Layer colors, source shadows/outlines, crossfade stacking, and inspector styling. |
| `public/markers/thin-circle-selection-ring.png` | Thin reference texture. |
| `public/markers/norden-roundtrip-selection-ring-cropped.png` | Accepted cropped Norden round-trip texture. |
| `tests/rendered-html.test.mjs` | Structural coverage for source paths, radial weighting, and the reference overlay. |

The original Norden vector source is
`../../assets/norden-interface/selection-ring/norden-roundtrip-selection-ring.svg`.
Its two grey shadow paths, light lower arrow, and dark upper arrow are retained
as separate SVG layers at neutral settings. The thin light and dark contours
are traced from the shipped 512-square PNG and retain its authored
irregularities.

## Editing model

- **Arrow weight** keeps the authored outside contour fixed. For a lower value,
  an explicit circular mask advances only the inner radius of the arc. Each
  arrowhead is also stored as an exact subpath extracted from the authored
  contour and composited back untouched, so the mask cannot cut its tip or
  center-facing shoulder. For a higher value, a sweep of
  inward-scaled copies fills toward the center without expanding the outside
  radius. Thin and Norden use source-measured outer radii (`178` in the
  512-unit Thin canvas and `33` in the 100-unit Norden canvas), avoiding a
  shared-radius estimate that could erase the irregular Norden arc at 1%. This
  avoids both clipped heads and the rectangular shoulders produced by the
  rejected protection-box experiment.
- **Tune feathers separately** controls whether the renderer splits out the
  feather regions. When unchecked, feather-specific controls are hidden and
  the complete authored arrow contour receives Arrow weight as one piece; no
  feather clip, root overlap, or feather rotation is applied.
- **Feather weight** runs the same radial operation over the source feather
  region. It does not translate the tines or move their outside radius, so their
  authored centerlines and spacing remain stable as their inner edge changes.
- **Feather angle** rotates each feather region around a design-specific root
  pivot. The range is deliberately constrained to `-12` through `12` degrees.
- **Feather root overlap** extends the feather region into the arrow body. The
  body and feather passes are composited with an overlap instead of meeting at
  a clipped edge, which keeps the attached tine continuous at low body weights.
- **Arrow rotation** rotates the complete ring as one unit.
- Existing ring X/Y offset, ring width, marker size, and theme controls continue
  to work independently.
- Neutral weights are `2.8%` for thin and `6.4%` for Norden. At the neutral
  value, the radial masks and sweeps are bypassed and the original paths render
  directly.
- The previous complete-contour implementation remains available at commit
  `a9ea84b` on branch `codex/selection-ring-5-2-baseline`. That fallback is
  considered solid at `5.2%` Norden arrow weight and above.
- The rejected feather experiment scaled clipped tine regions around shared
  origins. That changed their spacing and exposed hard mask seams. The current
  implementation uses the ring center as the radial eligibility test and uses
  authored root pivots plus overlap for attachment.

## Transparency verification

In procedural mode, **Reference overlay** crossfades between the vector and the
shipped texture:

- `0%`: procedural SVG only.
- `50%`: half vector and half texture. Misalignment appears as doubled or soft
  edges, making this the main verification view.
- `100%`: shipped texture only.

The `0%`, `50%`, and `100%` preset buttons make the comparison repeatable. The
slider supports 5% increments for closer inspection.

To verify a neutral design:

1. Run `npm run dev` and open `http://localhost:3000/icon-alignment`.
2. Select **Procedural**, then **Thin** or **Norden**.
3. Press **Reset** to restore the source weight and zero rotation.
4. Alternate between the three opacity presets.
5. At `50%`, check the outer contour, inner contour, arrowhead points, fork
   endpoints, and transparent padding. No doubled geometry should appear.

The neutral vectors and textures coincide geometrically. The texture-only
state is slightly softer because it is rasterized.

The 2026-08-16 browser pass also checked Norden at `1.0%`, `3.0%`, and `5.2%`
body weight with unified feathers, plus `4.0%` body / `5.2%` feathers with a
`4.0%` root overlap and constrained feather rotation at `-8` degrees. Thin was
checked at `1.0%` body / `2.8%` feathers. The tines and arrowheads retained their
spacing and remained joined at their authored roots.

The follow-up radial pass checked Norden at `1.0%`, `4.4%`, and `8.0%` body
weights, a separate `8.0%` feather weight, and Thin at `1.0%`. Across those
cases the authored outside radius stayed fixed and weight changed only on the
center-facing edge. Neutral Norden was rechecked at `50%` reference opacity.

The later inner-cutoff correction replaced low-weight intersection against a
scaled copy with a literal black inner circle in the alpha mask. The scaled-copy
method could erase thin radial projections; the circle cannot affect any source
pixel outside the requested inner radius.

## State and export

- Browser drafts use `dnt-procedural-selection-ring:v7`. This avoids restoring
  the rejected split-and-scale draft schema.
- Exported `procedural_selection_ring` records `render_mode`, `design`,
  `body_thickness`, `separate_feathers`, `feather_thickness`, `feather_rotation_degrees`,
  `feather_root_overlap`, `thickness_unit`, and `rotation_degrees`.
- Comparison opacity is intentionally a local inspection aid and is not
  exported.
- Map anchors and clickboxes remain fixed.

## Verification

From `tools/map-coordinate-calibrator`:

```powershell
npm test
npm run lint
```

The production build and all six tests pass. Lint has no errors; its nine
`@next/next/no-img-element` warnings predate this work. `git diff --check`
reports no whitespace errors, only the repository's existing CRLF notices.
