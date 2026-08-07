import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
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
  assert.match(html, /Copy changed patch/);
  assert.doesNotMatch(html, /codex-preview|SkeletonPreview|Your site is taking shape/);
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
  assert.deepEqual(honrich.authoring_stops.map((stop) => stop.id), ["honeyside"]);
});
