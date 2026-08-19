# Nexus page and image-composer handoff

This handoff is for a separate Codex task working only on the Diegetic Fast
Travel Nexus page, gallery plan, thumbnails, and related marketing graphics.
It should not change gameplay code, plugins, deployment folders, or release
packaging unless the user explicitly expands the task.

## Current objective

Prepare a concise, visually legible draft Nexus page and a small set of images
that explain the mod without requiring visitors to read a wall of text.

The current visual direction is:

- foreground the physical maps and their distinct icon languages;
- communicate that carriage drivers, ferrymen, and wizards use maps suited to
  their means and profession;
- show round-trip versus one-way service through the selection-arrow artwork;
- keep thumbnail text extremely sparse because Nexus displays it at a small
  size;
- preserve the warm parchment, cream, dark-brown, and restrained-gold palette.

## Start here

Read these files before editing:

1. `docs/NEXUS_PAGE_DRAFT.md` — public page copy, file-page copy, credits,
   gallery plan, and the private pre-publication checklist.
2. `.tools/nexus-thumbnail/index.html` — two-image diagonal hero-thumbnail
   composer.
3. `.tools/nexus-thumbnail/features.html` — three-map feature and icon-showcase
   composer.

The composer directory is deliberately ignored by Git through `.gitignore`:

```text
.tools/
```

It is present in this shared workspace and safe to edit locally, but it is not
part of repository history or the release archive. Do not remove that ignore
rule merely to make the composer show up in Git. If the user later wants these
tools published, promote them deliberately in a separate cleanup change.

## Run the local preview

From the repository root:

```powershell
python -m http.server 8765 --bind 127.0.0.1
```

Then open:

- Hero thumbnail: <http://127.0.0.1:8765/.tools/nexus-thumbnail/index.html>
- Feature overview: <http://127.0.0.1:8765/.tools/nexus-thumbnail/features.html>
- Icon showcase: <http://127.0.0.1:8765/.tools/nexus-thumbnail/features.html?mode=icons>

If the server is started inside `.tools/nexus-thumbnail` instead, the shorter
URLs used during the original authoring session are:

- <http://127.0.0.1:8765/>
- <http://127.0.0.1:8765/features.html>
- <http://127.0.0.1:8765/features.html?mode=icons>

Do not open the HTML through `file://`; the canvas exporter reports a clearer
error for that case, but browsers may still block local image reads.

## Composer inventory

### `index.html` — hero thumbnail

Combines `boat-map.jpg` and `carriage-map.jpg` with an adjustable diagonal
split. It currently provides:

- separate top and bottom split controls;
- horizontal crop/focus controls for both screenshots;
- title-scale control;
- title visibility toggle;
- live 16:9 preview;
- a 1600 × 900 PNG export named
  `diegetic-fast-travel-thumbnail.png`.

The title treatment is intentionally high-contrast because the Nexus search
thumbnail is small. Always judge this page at approximately Nexus-card size,
not only at full browser width.

### `features.html` — feature overview

Uses a three-way diagonal split:

- carriage map on the left;
- weathered ferry map in the middle;
- formal wizard map on the right.

It shows matching carriage, ferry, and magic icons plus round-trip and one-way
selection artwork. Controls currently include:

- icon size;
- text size;
- map brightness;
- selection-arrow rotation;
- headline visibility;
- service-name visibility;
- small-caption visibility;
- route-label visibility;
- 1600 × 900 PNG export named
  `diegetic-fast-travel-features.png`.

The small socioeconomic captions are OFF by default. This reflects the user's
conclusion that most small text is unnecessary.

### `features.html?mode=icons` — icon showcase

This is a distinct icon-first presentation implemented as a URL mode rather
than a duplicated HTML file. In icon mode:

- the page identifies itself as the icon showcase;
- the headline begins disabled;
- the small captions remain disabled;
- the large service and route labels remain enabled, but each can be disabled;
- all four text groups can be turned off for a completely text-free export.

The preview and canvas exporter use the same toggle state. This was manually
verified in the in-app browser: hidden labels disappear from the preview,
reappear when re-enabled, the exporter updates its status, and there were no
console warnings or errors.

## Local visual assets

All files below are in `.tools/nexus-thumbnail/`:

| File | Purpose |
| --- | --- |
| `boat-map.jpg` | Screenshot used by the hero and ferry panel |
| `carriage-map.jpg` | Screenshot used by the hero and carriage panel |
| `feature-map.jpg` | Formal wizard-map screenshot |
| `feature-carriage.png` | Carriage/service icon |
| `feature-ferry-parchment.png` | Weathered ferry/anchor icon |
| `feature-ferry.png` | Alternate ferry icon retained for comparison |
| `feature-magic.png` | Wizard-service icon |
| `feature-roundtrip.png` | Round-trip selection arrows |
| `feature-oneway.png` | One-way selection indicator |
| `feature-town.png` | Destination icon used inside the selection demo |

Prefer these prepared local assets over scraping new ones from the mod install.
If a screenshot is replaced, preserve the filename unless the HTML is updated
in both its DOM preview and canvas export code.

## Important implementation detail

Both pages draw their exported PNG independently on a canvas. Their on-screen
CSS preview is not simply screenshotted. Any visual change must therefore be
implemented twice:

1. the HTML/CSS preview; and
2. the canvas drawing code in the export handler.

After every meaningful visual change, test both the preview and the downloaded
PNG. The export status appears beneath the controls.

The feature page's icon mode is detected with:

```js
new URLSearchParams(window.location.search).get('mode') === 'icons'
```

Keep the shared implementation unless the two layouts truly diverge; copying
the entire page would create two large canvas renderers that drift apart.

## Content and credit constraints

- The Nexus page is still a draft. Do not publish it or upload a release file.
- The public copy must not promise unverified features or dependencies.
- Third-party map textures are referenced through required mods and are not
  redistributed in the release.
- The colorful location markers are from **NORDIC UI**, not Norden UI. NORDIC
  UI's author instructions permit use but ask users to check SkyUI and SkyHUD
  permissions as well. The current credit text is in
  `docs/NEXUS_PAGE_DRAFT.md`.
- The round-trip selection-symbol credit is separately attributed to Norden UI
  with direct permission.
- Preserve the AI-assisted/concept-art disclosure already included in the
  draft credits.
- Do not infer Nexus upload, translation, patch, or Donation Point permissions
  from dependency permissions; those choices remain with the mod author.

## Copy direction

The current short description is:

> Morrowind-inspired fast travel through physical route maps. Ask carriage
> drivers, ferrymen, and wizard guides where they travel, choose a destination,
> pay the fare, and learn a connected network built around Skyrim's existing
> services.

The long description in `docs/NEXUS_PAGE_DRAFT.md` is accurate but can still be
made shorter. Preserve these points even if it is condensed:

- three provider types: carriages, ferries, and wizard guides;
- physical provider-specific maps rather than a universal destination list;
- mouse and controller support;
- round-trip and one-way distinctions;
- the essential requirements and incompatibility warning;
- the separate, optional Baan Malur file;
- the new-game recommendation for the initial beta;
- concise bug-report instructions and log location.

Avoid explaining every internal architecture decision on the public page.
Nexus visitors need the experience, requirements, compatibility, and support
instructions—not the implementation history.

## Recommended next tasks

Work in this order unless the user redirects:

1. **Polish the icon-showcase composition.** Test fully text-free, service-name
   only, and service-plus-route-label variants at Nexus-card size. The likely
   winner is either text-free or service names only.
2. **Improve the visual socioeconomic story.** Convey the difference through
   the images themselves: formal commissioned atlas for carriage/wizard
   services versus a weathered working chart for ferries. Do not bring back
   explanatory microcopy unless the images fail without it.
3. **Shorten the public description.** Produce a compact first-screen section,
   then requirements, compatibility, installation, credits, and bug reporting.
4. **Choose a gallery order and captions.** Use the plan already present in
   `docs/NEXUS_PAGE_DRAFT.md`; captions should be one sentence and should not
   restate the screenshot.
5. **Verify exported PNGs.** Inspect at 1600 × 900 and at a small Nexus-card
   preview. Check cropping, diagonals, text legibility, icon overlap, and color
   balance.
6. **Only after the release candidate is final,** replace development
   screenshots with captures from that exact build.

## Acceptance checklist for Nexus-page work

- [ ] Hero thumbnail remains readable at small card size.
- [ ] Icon showcase can export with all text disabled.
- [ ] Preview and exported PNG match for every control state used publicly.
- [ ] No browser console warnings or errors.
- [ ] Images are 16:9 and export at 1600 × 900.
- [ ] No third-party artwork is newly bundled without a recorded permission or
      dependency-based plan.
- [ ] NORDIC UI and Norden UI credits remain distinct and accurate.
- [ ] Public copy matches the actual release candidate.
- [ ] Page remains unpublished until the private checklist in
      `docs/NEXUS_PAGE_DRAFT.md` passes.

## Boundaries for the next task

Safe without further approval:

- edit the two local HTML composers and their local copied assets;
- refine the draft Markdown/BBCode;
- run the local HTTP server;
- export and inspect local PNG previews;
- propose gallery ordering and captions.

Ask before:

- publishing the Nexus page;
- uploading files or images to Nexus;
- changing mod code or release dependencies;
- copying additional third-party artwork into the workspace;
- moving the ignored composer into tracked repository scope.
