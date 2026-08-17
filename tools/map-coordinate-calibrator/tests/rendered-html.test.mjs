import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render(path = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(new URL(path, "http://localhost/"), {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the coordinate calibrator shell", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>DNT Map Coordinate Calibrator<\/title>/i);
  assert.match(html, /Map coordinate calibrator/);
  assert.match(html, /Carriage network/);
  assert.match(html, /Wizard guides/);
  assert.match(html, /Mainland ferries/);
  assert.match(html, /Lake Honrich/);
  assert.match(html, /Lake Ilinalta/);
  assert.match(html, /Solstheim ferries/);
  assert.match(html, /Remyris merchant route/);
  assert.match(html, /norden/i);
  assert.match(html, /vanilla/i);
  assert.match(html, /ferry/i);
  assert.match(html, /Copy changed patch/);
  assert.doesNotMatch(html, /codex-preview|SkeletonPreview|Your site is taking shape/);
});

test("server-renders the icon optical-alignment workspace", async () => {
  const response = await render("/icon-alignment");
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /Icon optical alignment/);
  assert.match(html, /Map layout/);
  assert.match(html, /Icon alignment/);
  assert.match(html, /Ring geometry and icon optics change; map anchor and clickbox stay fixed/);
  assert.match(html, /Import optics JSON/);
  assert.match(html, /Alpha bounds/);
  assert.match(html, /norden/i);
  assert.match(html, /vanilla/i);
});

test("builds editable selection arrows from source-matched SVG geometry", async () => {
  const component = await readFile(
    new URL("../app/icon-alignment/IconAlignmentCalibrator.tsx", import.meta.url),
    "utf8",
  );
  const vector = await readFile(
    new URL("../app/icon-alignment/SelectionRingVector.tsx", import.meta.url),
    "utf8",
  );
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");

  assert.match(component, /Selection arrow design/);
  assert.match(component, /SelectionRingVector/);
  assert.match(component, /norden-roundtrip-selection-ring/);
  assert.match(component, /norden-roundtrip-selection-ring-cropped\.png/);
  assert.match(component, /rotation: 105/);
  assert.match(component, /proceduralRing\.rotation - NORDEN_ROUNDTRIP_PREVIEW_BAKED_ROTATION/);
  assert.match(component, /NORDEN_ROUNDTRIP_PREVIEW_BAKED_ROTATION/);
  assert.match(component, /textureRingStyle/);
  assert.match(component, /rotation - NORDEN_ROUNDTRIP_PREVIEW_BAKED_ROTATION/);
  assert.match(component, /ring-rotation-controls/);
  assert.match(component, /Arrow rotation/);
  assert.match(component, /ring-design-switcher/);
  assert.match(component, /Arrow weight/);
  assert.match(component, /Tune feathers separately/);
  assert.match(component, /separate_feathers/);
  assert.match(component, /separateFeathers/);
  assert.match(component, /Feather weight/);
  assert.match(component, /Feather angle/);
  assert.match(component, /Feather root overlap/);
  assert.match(component, /feather_thickness/);
  assert.match(component, /feather_rotation_degrees/);
  assert.match(component, /feather_root_overlap/);
  assert.match(component, /Reference overlay/);
  assert.match(component, /procedural-reference-overlay/);
  assert.match(vector, /THIN_LIGHT_PATH/);
  assert.match(vector, /NORDEN_UPPER_DARK/);
  assert.match(vector, /radialScale/);
  assert.match(vector, /radialInnerRadius/);
  assert.match(vector, /outerRadius/);
  assert.match(vector, /scaleAround/);
  assert.match(vector, /body-radial-weight/);
  assert.match(vector, /arrowheadPath: SourcePath/);
  assert.match(vector, /NORDEN_UPPER_ARROWHEAD/);
  assert.match(vector, /NORDEN_LOWER_ARROWHEAD/);
  assert.match(vector, /<circle cx={source.center.x} cy={source.center.y} r={bodyInnerRadius} fill="black"/);
  assert.match(vector, /bodyDelta < -0\.001 && <SourcePaths omitShadow paths={\[arrow\.arrowheadPath\]}/);
  assert.doesNotMatch(vector, /radialCutPath/);
  assert.doesNotMatch(vector, /angularDistance/);
  assert.doesNotMatch(vector, /arrowheadProtection/);
  assert.doesNotMatch(vector, /<polygon points={arrowheadProtection}/);
  assert.doesNotMatch(vector, /function MaskPaths/);
  assert.match(vector, /body-without-feather/);
  assert.match(vector, /feather-region/);
  assert.match(vector, /featherRootOverlap/);
  assert.match(vector, /separateFeathers/);
  assert.doesNotMatch(vector, /featherScale/);
  assert.doesNotMatch(vector, /feMorphology/);
  assert.match(vector, /source-matched-vector/);
  assert.match(css, /\.procedural-ring-svg\s*{/);
  assert.match(css, /\.procedural-ring-art\.norden/);
  assert.match(css, /\.procedural-reference-overlay/);
  assert.match(css, /\.source-matched-vector/);
});

test("ships the approved, versioned Norden icon-optics baseline", async () => {
  const optics = JSON.parse(
    await readFile(new URL("../public/icon-optics.json", import.meta.url), "utf8"),
  );
  assert.equal(optics.schema_version, 1);
  assert.equal(optics.global_selection_ring_scale, 2);
  assert.equal(optics.offset_space, "icon_half_extent");
  assert.equal(Object.keys(optics.icon_optics.norden).length, 16);
  assert.deepEqual(optics.icon_optics.vanilla, {});
  assert.deepEqual(optics.selection_ring_textures, {
    norden: "Data/textures/DiegeticTravel/norden-roundtrip-selection-ring.dds",
    vanilla: "Data/textures/DiegeticTravel/thin-circle-selection-ring.dds",
    ferry: "Data/textures/DiegeticTravel/parchment-thin-selection-ring.dds",
  });
  assert.deepEqual(
    optics.icon_optics.norden["norden-whiterun-capital"].ring_offset,
    [0.0316, -0.0474],
  );
  assert.equal(
    optics.icon_optics.norden["norden-wood-mill"].ring_scale,
    1.09,
  );
  assert.deepEqual(
    Object.fromEntries(Object.entries(optics.icon_optics.norden).map(([id, profile]) => [id, profile.marker_scale])),
    {
      "norden-whiterun-capital": 1,
      "norden-riften-capital": 0.99,
      "norden-solitude-capital": 1,
      "norden-windhelm-capital": 0.93,
      "norden-markarth-capital": 0.95,
      "norden-dawnstar-capital": 1.01,
      "norden-morthal-capital": 0.95,
      "norden-falkreath-capital": 0.96,
      "norden-winterhold-capital": 0.96,
      "norden-town": 0.8,
      "norden-settlement": 0.8,
      "norden-wood-mill": 0.73,
      "norden-mine": 0.78,
      "norden-farm": 0.78,
      "norden-shipwreck": 0.91,
      "norden-docks": 0.97,
    },
  );
  assert.deepEqual(Object.keys(optics.icon_optics.ferry), ["ferry-docks"]);
  assert.equal(optics.icon_optics.ferry["ferry-docks"].ring_scale, 0.94);
});

test("keeps authoring-only locations separate from playable stops", async () => {
  const merchant = JSON.parse(
    await readFile(new URL("../public/presets/solstheim-merchant.json", import.meta.url), "utf8"),
  );
  const honrich = JSON.parse(
    await readFile(new URL("../public/presets/honrich.json", import.meta.url), "utf8"),
  );

  assert.deepEqual(
    merchant.stops.map((stop) => stop.id),
    ["raven_rock", "baan_malur", "cormaris"],
  );
  assert.deepEqual(
    merchant.authoring_stops.map((stop) => stop.id),
    ["pryai", "llethrin_fel", "sunmul", "seyda_neen", "vivec", "old_silgrad"],
  );
  assert.ok(merchant.authoring_stops.every((stop) => stop.runtime_enabled === false));
  const sunmul = merchant.authoring_stops.find((stop) => stop.id === "sunmul");
  assert.deepEqual(sunmul.map_position, [0.561367, 0.894535]);
  assert.equal(sunmul.position_status, "calibrated");
  assert.equal(merchant.map.marker_theme, "norden_maritime");
  assert.equal(merchant.map.origin_marker, "norden_shipwreck");
  assert.equal(merchant.map.destination_marker, "norden_docks");
  assert.equal(merchant.map.selection_ring, "thin_circle");
  assert.deepEqual(honrich.authoring_stops.map((stop) => stop.id), ["honeyside"]);
  assert.deepEqual(honrich.stops.find((stop) => stop.id === "riften").map_position, [0.905132, 0.835295]);
  assert.deepEqual(honrich.authoring_stops[0].map_position, [0.89365, 0.80508]);
  assert.equal(honrich.authoring_stops[0].position_status, "calibrated");
});

test("ships transparent maritime marker and thin selector previews", async () => {
  const names = [
    "norden-shipwreck.png",
    "norden-docks.png",
    "thin-circle-selection-ring.png",
    "parchment-thin-selection-ring.png",
  ];
  const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (const name of names) {
    const bytes = await readFile(new URL(`../public/markers/${name}`, import.meta.url));
    assert.deepEqual([...bytes.subarray(0, 8)], pngSignature, name);
    assert.ok(bytes.length > 1_000, `${name} should contain rendered artwork`);
  }
});
