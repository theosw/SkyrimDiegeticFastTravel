# Nexus graphics handoff — Diegetic Fast Travel

This handoff is for a separate Codex task working only on graphics for the
Diegetic Fast Travel Nexus mod page. It may edit and test the local image
composers and prepared marketing assets. It must not change gameplay code,
plugins, deployment folders, release packaging, or the user's Mod Organizer 2
profiles unless the user explicitly expands the scope.

This document reflects the working state on 2026-08-18. It supersedes the
graphics implementation details in `docs/NEXUS_PAGES_HANDOFF.md`, which still
describes an older preview/export architecture. That older document remains
useful for page copy, credits, permissions, and gallery planning.

## Objective

Produce a small, coherent set of 16:9 graphics that explains the mod at a
glance:

- physical route maps replace destination-list menus;
- carriage, ferry, and wizard services have distinct maps and icon languages;
- the selection artwork distinguishes round-trip and one-way destinations;
- the warm parchment, cream, dark-brown, and restrained-gold visual language
  remains consistent across the hero, feature, and gallery images;
- text remains legible at Nexus card size and is omitted when the imagery can
  carry the meaning by itself.

Do not publish or upload anything to Nexus from this task. The deliverables are
local PNG candidates and, when useful, improvements to the local composers.

## Read first

1. `docs/NEXUS_PAGE_DRAFT.md` — public copy, requirements, credits, gallery
   order, captions, and the private release checklist.
2. `docs/NEXUS_PAGES_HANDOFF.md` — broader page handoff. Treat its old
   dual-renderer warning for `features.html` as obsolete.
3. `.tools/nexus-thumbnail/index.html` — hero-thumbnail composer.
4. `.tools/nexus-thumbnail/features.html` — shared feature/icon composer and
   the authoritative current graphics implementation.

The entire `.tools/` directory is deliberately ignored by Git. It is safe to
edit locally, but it is not included in repository history or release archives.
Do not remove the ignore rule merely to make these files appear in Git.

## Start the local preview

From the repository root:

```powershell
python -m http.server 8765 --bind 127.0.0.1
```

Open:

- Hero thumbnail: <http://127.0.0.1:8765/.tools/nexus-thumbnail/index.html>
- Feature overview: <http://127.0.0.1:8765/.tools/nexus-thumbnail/features.html>
- Icon showcase: <http://127.0.0.1:8765/.tools/nexus-thumbnail/features.html?mode=icons>

Do not use `file://`. The local images taint the canvas in that mode and the
browser blocks `toDataURL()`, producing a failed export. Successful exports are
downloaded by the browser, normally into `C:\Users\Theo\Downloads`.

## Current composer state

### Feature and icon composer — authoritative WYSIWYG renderer

`features.html` now has one rendering path. The visible preview is the actual
1600 × 900 canvas, scaled to fit the page, and Export downloads that exact
canvas. Framing, shading, text, clipping, icon positions, and control changes
therefore cannot drift between preview and PNG.

The old HTML/CSS visual renderer was removed. Hidden image elements remain only
as the asset bank used by the canvas renderer.

Controls:

| Control | Range | Default | Notes |
| --- | ---: | ---: | --- |
| Icon size | 80–145% | 115% | Scales provider and selection icons. |
| Text size | 80–135% | 110% | Scales canvas-rendered labels. |
| Map brightness | 30–80% | 55% | Applies the common darkening pass. |
| Divider angle | -20° to 20° | 12.04° | Positive values slant left toward the bottom. |
| Ferry position | -80 to +80 px | +16 px | Moves the complete ferry icon/label group horizontally. |
| Arrow rotation | -180° to 180° | 0° | Rotates both selection rings. |
| Selection height | -120 to +120 px | 0 px | Positive values raise the full selection row. |

Text toggles:

- headline;
- service names;
- small service captions;
- route labels.

In `?mode=icons`, the headline and small captions start disabled, while service
names and route labels start enabled. Icon mode exports
`diegetic-fast-travel-icons.png`; feature mode exports
`diegetic-fast-travel-features.png`.

Important hardening already completed:

- both map dividers are mathematically parallel at every angle;
- the default 12.04° angle matches the hero composer's 56% top / 44% bottom
  split on a 1600 × 900 canvas;
- panel clipping and divider strokes use the same calculated geometry;
- selection groups measure the actual `ROUND TRIP` label and move apart only
  when needed, maintaining a 32 px gap at maximum icon/text scale;
- the ferry-position control defaults to a deliberate 16 px rightward optical
  correction and can be tuned without separating the icon from its labels;
- a final 1 px dark-gold frame is drawn last, above shading and divider
  endpoints, to cover tiny edge extensions;
- the large frame, lower shading, route labels, and selection-height control are
  all part of the same exported canvas.

### Hero composer — older architecture

`index.html` combines the ferry and carriage screenshots with one diagonal
split and a title treatment. Its defaults are:

- split at top: 56%;
- split at bottom: 44%;
- equivalent divider angle on a 1600 × 900 canvas: approximately 12.04°;
- title scale: 120%;
- title shown.

It exports `diegetic-fast-travel-thumbnail.png` at 1600 × 900.

Unlike `features.html`, the hero still has separate HTML/CSS preview and canvas
export implementations. If it is changed, either migrate it to the same shared
canvas pattern or verify both paths carefully. Do not assume its preview is
pixel-identical to the downloaded PNG.

## Prepared local assets

All paths below are relative to `.tools/nexus-thumbnail/`.

| File | Purpose |
| --- | --- |
| `boat-map.jpg` | Weathered ferry-map screenshot; also used in the hero. |
| `carriage-map.jpg` | Carriage-map screenshot; also used in the hero. |
| `feature-map.jpg` | Formal wizard-map screenshot. |
| `feature-carriage.png` | Carriage provider icon. |
| `feature-ferry-parchment.png` | Preferred weathered ferry/anchor icon. |
| `feature-ferry.png` | Alternate ferry icon retained for comparison. |
| `feature-magic.png` | Wizard provider icon. |
| `feature-roundtrip.png` | Current calibrated two-arrow selection ring. |
| `feature-oneway.png` | Current calibrated darker one-way arrow. |
| `feature-town.png` | Destination symbol drawn inside both selection rings. |

The round-trip and one-way assets are the accepted matched pair from the current
mod artwork. Do not substitute the earlier thin-arrow versions. The one-way
indicator must remain the darker/right-side arrow, not the white arrow.

Prefer these prepared copies over scraping assets from the installed mod. If an
asset filename changes, update the hidden image bank and every canvas reference.

## Established visual decisions

- Use the current dark one-way arrow and calibrated round-trip ring.
- Keep the selection rings at 0° unless a deliberate composition requires a
  different rotation.
- Keep small explanatory captions off by default.
- Service names and route labels may remain, but judge them at card size.
- The service-name treatment is clean canvas text with shadow; the old gold
  outlines around shaded HTML name plates are gone.
- Keep both feature dividers parallel. The hero-matched 12.04° angle is the
  current default, not a mandatory final choice.
- Preserve the broad gold frame and final 1 px dark-gold finishing edge.
- Avoid adding decorative text simply to fill space. The maps and icon system
  should do most of the explanatory work.

## Recommended graphics task

Work in this order unless the user redirects:

1. Open the icon showcase through localhost and agree on final slider/toggle
   values with the user.
2. Export the icon showcase and inspect the downloaded PNG at its native
   1600 × 900 resolution.
3. Make a temporary 400 × 225 card-size preview and check icon recognition,
   route-label legibility, and overall contrast. Do not replace the 1600 × 900
   deliverable with the small QA preview.
4. Review the hero export. If more hero edits are requested, migrate it to the
   single-canvas renderer before substantial styling work.
5. Produce the remaining gallery graphics from final-release screenshots using
   the order and captions in `docs/NEXUS_PAGE_DRAFT.md`.
6. Keep all outputs local until the release candidate and page checklist pass.

The `.tools/nexus-thumbnail/output/` directory is currently empty. Browser
exports land in Downloads, often with numbered suffixes if a filename already
exists. Do not mistake an older numbered test export for the selected final.
Copy an accepted image into a clearly named workspace output only after the user
chooses it.

## Verification checklist

- [ ] Page is opened through `http://127.0.0.1`, not `file://`.
- [ ] Export status says it used the exact preview canvas.
- [ ] PNG is exactly 1600 × 900 and fully opaque.
- [ ] Preview and downloaded PNG show the same settings.
- [ ] Both dividing lines are parallel and panel clips follow them.
- [ ] No divider endpoint protrudes beyond the final 1 px frame.
- [ ] Round-trip text does not overlap the one-way ring at maximum scale.
- [ ] The one-way arrow is the darker/right-side arrow.
- [ ] Text and icons remain legible at approximately 400 × 225.
- [ ] No unintended clipping occurs at -20°, 12.04°, or 20° divider angles.
- [ ] The final candidate is distinguishable from numbered QA exports.
- [ ] No new third-party art is bundled without permission and correct credit.
- [ ] Nothing has been uploaded or published without explicit approval.

## Content, credit, and safety boundaries

- Preserve the credit distinction between **NORDIC UI** marker artwork and the
  **Norden UI** selection symbol. See `docs/NEXUS_PAGE_DRAFT.md` for exact copy.
- Third-party map textures are supplied by required mods and are not to be
  redistributed casually.
- Preserve the AI-assisted concept-art disclosure in the draft credits.
- Do not promise unverified compatibility or release features in image text.
- Do not deploy builds, launch Skyrim, edit MO2 profiles, or touch save files.
- Do not publish the Nexus page or upload images/files without the user's
  explicit approval.

## Safe actions without further approval

- edit the ignored local composers;
- adjust prepared local marketing assets;
- run the localhost preview server;
- export and inspect local PNGs;
- create temporary card-size QA previews;
- propose image order, captions, and alternative compositions.

Ask before copying in new third-party artwork, moving the composers into tracked
repository scope, publishing anything, or changing the mod/release itself.
