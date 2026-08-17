# Selection-ring web-vector handoff

Updated: 2026-08-16

## Current result

The `/icon-alignment` page renders the thin and Norden round-trip arrows from
source-matched inline SVG paths. At neutral settings, the procedural layer and
the shipped texture share the same silhouette, scale, orientation, colors, and
transparent canvas placement.

The earlier circular generator is rejected. Although its sliders worked, it
replaced the authored asymmetry, arrowhead shoulders, fork shapes, bevel, and
shadow with idealized geometry. The difference was obvious when compared with
the texture.

This remains a browser-calibrator feature. Runtime DDS textures and the native
parchment renderer are unchanged.

## Implementation map

| File | Responsibility |
| --- | --- |
| `app/icon-alignment/SelectionRingVector.tsx` | Exact thin trace, exact four-layer Norden source geometry, and complete-arrow SVG morphology. |
| `app/icon-alignment/IconAlignmentCalibrator.tsx` | Texture/procedural selection, design selection, weight and rotation controls, comparison opacity, persistence, and JSON import/export. |
| `app/globals.css` | Layer colors, source shadows/outlines, crossfade stacking, and inspector styling. |
| `public/markers/thin-circle-selection-ring.png` | Thin reference texture. |
| `public/markers/norden-roundtrip-selection-ring.png` | Norden reference texture. |
| `tests/rendered-html.test.mjs` | Structural coverage for source paths, morphology, and the reference overlay. |

The original Norden vector source is
`../../assets/norden-interface/selection-ring/norden-roundtrip-selection-ring.svg`.
Its two grey shadow paths, light lower arrow, and dark upper arrow are retained
as separate SVG layers at neutral settings. The thin light and dark contours
are traced from the shipped 512-square PNG and retain its authored
irregularities.

## Editing model

- **Arrow weight** applies SVG erosion or dilation to each complete authored
  arrow.
- **Arrow rotation** rotates the complete ring as one unit.
- Existing ring X/Y offset, ring width, marker size, and theme controls continue
  to work independently.
- Neutral weights are `2.8%` for thin and `6.4%` for Norden. At the neutral
  value, the morphology filters are bypassed and the original paths render
  directly.
- The current Norden editor is the accepted fallback baseline at `5.2%` arrow
  weight and above. Below `5.2%`, erosion starts collapsing the narrow fork
  tines before the broader body, so those lower values are not considered
  production-safe.
- Independent fork-tail scaling is deliberately not exposed. The split-mask
  experiment produced visible seams and detached-looking tines at low weights;
  a clean independent control would require genuinely split paths or a proper
  vector morph rather than transforms applied to clipped regions.

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

## State and export

- Browser drafts use `dnt-procedural-selection-ring:v4`.
- Exported `procedural_selection_ring` records `render_mode`, `design`,
  `body_thickness`, `thickness_unit`, and `rotation_degrees`.
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
