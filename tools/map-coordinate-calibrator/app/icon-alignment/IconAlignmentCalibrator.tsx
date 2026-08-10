"use client";

import Link from "next/link";
import {
  type ChangeEvent,
  type KeyboardEvent,
  type PointerEvent,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

type IconTheme = "norden" | "vanilla" | "ferry";

type IconDefinition = {
  id: string;
  label: string;
  theme: IconTheme;
  preview: string;
  texture: string;
  usedBy: string;
};

type IconOptic = {
  offsetX: number;
  offsetY: number;
  ringScale: number;
  markerScale: number;
  originalOffsetX: number;
  originalOffsetY: number;
  originalRingScale: number;
  originalMarkerScale: number;
};

type AlphaAnalysis = {
  bounds: [number, number, number, number];
  boundsCenter: [number, number];
  centroid: [number, number];
  suggestedOffset: [number, number];
  centroidOffset?: [number, number];
  coverage: number;
};

type OpticsDocument = {
  schema_version?: number;
  selection_ring_texture?: string;
  selection_ring_textures?: Partial<Record<IconTheme, string>>;
  global_selection_ring_scale?: number;
  offset_space?: string;
  icon_optics?: Partial<Record<IconTheme, Record<string, {
    texture?: string;
    ring_offset?: [number, number];
    ring_scale?: number;
    marker_scale?: number;
  }>>>;
};

const ICONS: IconDefinition[] = [
  { id: "norden-whiterun-capital", label: "Whiterun", theme: "norden", preview: "/markers/norden-whiterun-capital.png", texture: "Data/textures/DiegeticTravel/norden-whiterun-capital.dds", usedBy: "Whiterun" },
  { id: "norden-riften-capital", label: "Riften", theme: "norden", preview: "/markers/norden-riften-capital.png", texture: "Data/textures/DiegeticTravel/norden-riften-capital.dds", usedBy: "Riften" },
  { id: "norden-solitude-capital", label: "Solitude", theme: "norden", preview: "/markers/norden-solitude-capital.png", texture: "Data/textures/DiegeticTravel/norden-solitude-capital.dds", usedBy: "Solitude" },
  { id: "norden-windhelm-capital", label: "Windhelm", theme: "norden", preview: "/markers/norden-windhelm-capital.png", texture: "Data/textures/DiegeticTravel/norden-windhelm-capital.dds", usedBy: "Windhelm" },
  { id: "norden-markarth-capital", label: "Markarth", theme: "norden", preview: "/markers/norden-markarth-capital.png", texture: "Data/textures/DiegeticTravel/norden-markarth-capital.dds", usedBy: "Markarth" },
  { id: "norden-dawnstar-capital", label: "Dawnstar", theme: "norden", preview: "/markers/norden-dawnstar-capital.png", texture: "Data/textures/DiegeticTravel/norden-dawnstar-capital.dds", usedBy: "Dawnstar" },
  { id: "norden-morthal-capital", label: "Morthal", theme: "norden", preview: "/markers/norden-morthal-capital.png", texture: "Data/textures/DiegeticTravel/norden-morthal-capital.dds", usedBy: "Morthal" },
  { id: "norden-falkreath-capital", label: "Falkreath", theme: "norden", preview: "/markers/norden-falkreath-capital.png", texture: "Data/textures/DiegeticTravel/norden-falkreath-capital.dds", usedBy: "Falkreath" },
  { id: "norden-winterhold-capital", label: "Winterhold / College", theme: "norden", preview: "/markers/norden-winterhold-capital.png", texture: "Data/textures/DiegeticTravel/norden-winterhold-capital.dds", usedBy: "Winterhold and College hub" },
  { id: "norden-town", label: "Town", theme: "norden", preview: "/markers/norden-town.png", texture: "Data/textures/DiegeticTravel/norden-town.dds", usedBy: "Rorikstead, Ivarstead, inns" },
  { id: "norden-settlement", label: "Settlement", theme: "norden", preview: "/markers/norden-settlement.png", texture: "Data/textures/DiegeticTravel/norden-settlement.dds", usedBy: "Crossings and villages" },
  { id: "norden-wood-mill", label: "Wood mill", theme: "norden", preview: "/markers/norden-wood-mill.png", texture: "Data/textures/DiegeticTravel/norden-wood-mill.dds", usedBy: "Half-Moon, Mixwater, Heartwood" },
  { id: "norden-mine", label: "Mine", theme: "norden", preview: "/markers/norden-mine.png", texture: "Data/textures/DiegeticTravel/norden-mine.dds", usedBy: "Soljund's Sinkhole" },
  { id: "norden-farm", label: "Farm / manor", theme: "norden", preview: "/markers/norden-farm.png", texture: "Data/textures/DiegeticTravel/norden-farm.dds", usedBy: "Hearthfire manors" },
  { id: "norden-shipwreck", label: "Ship / origin", theme: "norden", preview: "/markers/norden-shipwreck.png", texture: "Data/textures/DiegeticTravel/norden-shipwreck.dds", usedBy: "Captain Remyris at Raven Rock" },
  { id: "norden-docks", label: "Docks / destination", theme: "norden", preview: "/markers/norden-docks.png", texture: "Data/textures/DiegeticTravel/norden-docks.dds", usedBy: "Captain Remyris destinations" },
  { id: "whiterun-dragonsreach", label: "Whiterun", theme: "vanilla", preview: "/markers/whiterun-dragonsreach.png", texture: "Data/textures/DiegeticTravel/whiterun-dragonsreach.dds", usedBy: "Whiterun" },
  { id: "riften-mistveil-keep", label: "Riften", theme: "vanilla", preview: "/markers/riften-mistveil-keep.png", texture: "Data/textures/DiegeticTravel/riften-mistveil-keep.dds", usedBy: "Riften" },
  { id: "solitude-blue-palace", label: "Solitude", theme: "vanilla", preview: "/markers/solitude-blue-palace.png", texture: "Data/textures/DiegeticTravel/solitude-blue-palace.dds", usedBy: "Solitude" },
  { id: "windhelm-palace-of-the-kings", label: "Windhelm", theme: "vanilla", preview: "/markers/windhelm-palace-of-the-kings.png", texture: "Data/textures/DiegeticTravel/windhelm-palace-of-the-kings.dds", usedBy: "Windhelm" },
  { id: "markarth-understone-keep", label: "Markarth", theme: "vanilla", preview: "/markers/markarth-understone-keep.png", texture: "Data/textures/DiegeticTravel/markarth-understone-keep.dds", usedBy: "Markarth" },
  { id: "dawnstar-white-hall", label: "Dawnstar", theme: "vanilla", preview: "/markers/dawnstar-white-hall.png", texture: "Data/textures/DiegeticTravel/dawnstar-white-hall.dds", usedBy: "Dawnstar" },
  { id: "morthal-highmoon-hall", label: "Morthal", theme: "vanilla", preview: "/markers/morthal-highmoon-hall.png", texture: "Data/textures/DiegeticTravel/morthal-highmoon-hall.dds", usedBy: "Morthal" },
  { id: "falkreath-jarl-longhouse", label: "Falkreath", theme: "vanilla", preview: "/markers/falkreath-jarl-longhouse.png", texture: "Data/textures/DiegeticTravel/falkreath-jarl-longhouse.dds", usedBy: "Falkreath" },
  { id: "winterhold-college", label: "Winterhold / College", theme: "vanilla", preview: "/markers/winterhold-college.png", texture: "Data/textures/DiegeticTravel/winterhold-college.dds", usedBy: "Winterhold and College hub" },
  { id: "town-marker", label: "Town / minor stop", theme: "vanilla", preview: "/markers/town-marker.png", texture: "Data/textures/DiegeticTravel/town-marker.dds", usedBy: "All non-capital stops" },
  { id: "ferry-docks", label: "Anchor / destination", theme: "ferry", preview: "/markers/docks-marker.png", texture: "Data/textures/DiegeticTravel/docks-marker.dds", usedBy: "Destinations on physical ferry maps" },
];

const OPTICS_DRAFT_KEY = "dnt-icon-optics:v7";

const SELECTION_RING_PREVIEWS: Record<IconTheme, string> = {
  norden: "/markers/thin-circle-selection-ring.png?v=20260808b",
  vanilla: "/markers/thin-circle-selection-ring.png?v=20260808b",
  ferry: "/markers/parchment-thin-selection-ring.png?v=20260808c",
};

const SELECTION_RING_TEXTURES: Record<IconTheme, string> = {
  norden: "Data/textures/DiegeticTravel/thin-circle-selection-ring.dds",
  vanilla: "Data/textures/DiegeticTravel/thin-circle-selection-ring.dds",
  ferry: "Data/textures/DiegeticTravel/parchment-thin-selection-ring.dds",
};

function round(value: number) {
  return Math.round(value * 10_000) / 10_000;
}

function clamp(value: number, minimum: number, maximum: number) {
  return Math.min(maximum, Math.max(minimum, round(value)));
}

function changed(optic: IconOptic) {
  return optic.offsetX !== optic.originalOffsetX ||
    optic.offsetY !== optic.originalOffsetY ||
    optic.ringScale !== optic.originalRingScale ||
    optic.markerScale !== optic.originalMarkerScale;
}

function initialOptics(document: OpticsDocument) {
  return Object.fromEntries(ICONS.map((icon) => {
    const source = document.icon_optics?.[icon.theme]?.[icon.id];
    const offsetX = Number(source?.ring_offset?.[0] ?? 0);
    const offsetY = Number(source?.ring_offset?.[1] ?? 0);
    const ringScale = Number(source?.ring_scale ?? 1);
    const markerScale = Number(source?.marker_scale ?? 1);
    return [icon.id, {
      offsetX,
      offsetY,
      ringScale,
      markerScale,
      originalOffsetX: offsetX,
      originalOffsetY: offsetY,
      originalRingScale: ringScale,
      originalMarkerScale: markerScale,
    } satisfies IconOptic];
  }));
}

function downloadJson(filename: string, value: unknown) {
  const blob = new Blob([`${JSON.stringify(value, null, 2)}\n`], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

async function copyText(text: string) {
  if (navigator.clipboard?.writeText) return navigator.clipboard.writeText(text);
  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.appendChild(textarea);
  textarea.select();
  document.execCommand("copy");
  textarea.remove();
}

async function analyzeAlpha(source: string): Promise<AlphaAnalysis> {
  const image = new Image();
  image.src = source;
  await image.decode();
  const canvas = document.createElement("canvas");
  canvas.width = image.naturalWidth;
  canvas.height = image.naturalHeight;
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (!context) throw new Error("Canvas analysis is unavailable.");
  context.drawImage(image, 0, 0);
  const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
  let minX = canvas.width;
  let minY = canvas.height;
  let maxX = -1;
  let maxY = -1;
  let alphaTotal = 0;
  let weightedX = 0;
  let weightedY = 0;
  let visiblePixels = 0;
  for (let y = 0; y < canvas.height; y += 1) {
    for (let x = 0; x < canvas.width; x += 1) {
      const alpha = pixels[(y * canvas.width + x) * 4 + 3];
      if (alpha <= 16) continue;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
      alphaTotal += alpha;
      weightedX += x * alpha;
      weightedY += y * alpha;
      visiblePixels += 1;
    }
  }
  if (maxX < minX || maxY < minY || alphaTotal === 0) {
    throw new Error("The icon has no visible alpha pixels.");
  }
  const bounds: AlphaAnalysis["bounds"] = [
    minX / canvas.width,
    minY / canvas.height,
    (maxX + 1) / canvas.width,
    (maxY + 1) / canvas.height,
  ];
  const boundsCenter: AlphaAnalysis["boundsCenter"] = [
    (bounds[0] + bounds[2]) / 2,
    (bounds[1] + bounds[3]) / 2,
  ];
  const centroid: AlphaAnalysis["centroid"] = [
    (weightedX / alphaTotal + 0.5) / canvas.width,
    (weightedY / alphaTotal + 0.5) / canvas.height,
  ];
  return {
    bounds,
    boundsCenter,
    centroid,
    suggestedOffset: [
      round((boundsCenter[0] - 0.5) * 2),
      round((boundsCenter[1] - 0.5) * 2),
    ],
    centroidOffset: [
      round((centroid[0] - 0.5) * 2),
      round((centroid[1] - 0.5) * 2),
    ],
    coverage: visiblePixels / (canvas.width * canvas.height),
  };
}

export function IconAlignmentCalibrator() {
  const [theme, setTheme] = useState<IconTheme>("norden");
  const [selectedId, setSelectedId] = useState(ICONS[0].id);
  const [optics, setOptics] = useState<Record<string, IconOptic>>({});
  const [globalRingScale, setGlobalRingScale] = useState(2);
  const [alphaAnalysis, setAlphaAnalysis] = useState<{ iconId: string; result: AlphaAnalysis } | null>(null);
  const [showAlphaBounds, setShowAlphaBounds] = useState(true);
  const [notice, setNotice] = useState("Loading checked-in icon optics…");
  const [loaded, setLoaded] = useState(false);
  const frameRef = useRef<HTMLDivElement>(null);
  const draggingRef = useRef(false);

  const themeIcons = useMemo(() => ICONS.filter((icon) => icon.theme === theme), [theme]);
  const selectedIcon = ICONS.find((icon) => icon.id === selectedId) ?? themeIcons[0];
  const selectedOptic = selectedIcon ? optics[selectedIcon.id] : undefined;
  const analysis = alphaAnalysis?.iconId === selectedIcon?.id ? alphaAnalysis.result : null;
  const visualCentroidOffset: [number, number] | null = analysis ?
    analysis.centroidOffset ?? [
      round((analysis.centroid[0] - 0.5) * 2),
      round((analysis.centroid[1] - 0.5) * 2),
    ] : null;
  const changedCount = Object.values(optics).filter(changed).length;

  useEffect(() => {
    let cancelled = false;
    fetch("/icon-optics.json")
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json() as Promise<OpticsDocument>;
      })
      .then((document) => {
        if (cancelled) return;
        const source = initialOptics(document);
        let draft: Record<string, Pick<IconOptic, "offsetX" | "offsetY" | "ringScale" | "markerScale">> = {};
        try {
          draft = JSON.parse(localStorage.getItem(OPTICS_DRAFT_KEY) ?? "{}");
        } catch {
          draft = {};
        }
        const restored = Object.fromEntries(Object.entries(source).map(([id, optic]) => [
          id,
          { ...optic, ...(draft[id] ?? {}) },
        ]));
        setOptics(restored);
        setGlobalRingScale(Number(document.global_selection_ring_scale ?? 2));
        setLoaded(true);
        setNotice(Object.keys(draft).length ? "Restored your local icon-optics draft." : "Ready. Drag the ring or use the controls for optical alignment.");
      })
      .catch((error: Error) => setNotice(`Could not load icon optics: ${error.message}`));
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    if (!loaded) return;
    const draft = Object.fromEntries(Object.entries(optics).map(([id, optic]) => [id, {
      offsetX: optic.offsetX,
      offsetY: optic.offsetY,
      ringScale: optic.ringScale,
      markerScale: optic.markerScale,
    }]));
    localStorage.setItem(OPTICS_DRAFT_KEY, JSON.stringify(draft));
  }, [loaded, optics]);

  useEffect(() => {
    if (!selectedIcon) return;
    let cancelled = false;
    analyzeAlpha(selectedIcon.preview)
      .then((result) => { if (!cancelled) setAlphaAnalysis({ iconId: selectedIcon.id, result }); })
      .catch((error: Error) => { if (!cancelled) setNotice(`Alpha analysis failed: ${error.message}`); });
    return () => { cancelled = true; };
  }, [selectedIcon]);

  function selectTheme(nextTheme: IconTheme) {
    setTheme(nextTheme);
    const first = ICONS.find((icon) => icon.theme === nextTheme);
    if (first) setSelectedId(first.id);
  }

  function updateSelected(values: Partial<Pick<IconOptic, "offsetX" | "offsetY" | "ringScale" | "markerScale">>) {
    if (!selectedIcon) return;
    setOptics((current) => ({
      ...current,
      [selectedIcon.id]: { ...current[selectedIcon.id], ...values },
    }));
  }

  function pointerOffset(event: PointerEvent<HTMLElement>) {
    const rect = frameRef.current?.getBoundingClientRect();
    if (!rect) return null;
    const renderedMarkerScale = selectedOptic?.markerScale ?? 1;
    return {
      offsetX: clamp((event.clientX - (rect.left + rect.width / 2)) / (rect.width / 2) / renderedMarkerScale, -0.75, 0.75),
      offsetY: clamp((event.clientY - (rect.top + rect.height / 2)) / (rect.height / 2) / renderedMarkerScale, -0.75, 0.75),
    };
  }

  function beginRingDrag(event: PointerEvent<HTMLButtonElement>) {
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    draggingRef.current = true;
    const next = pointerOffset(event);
    if (next) updateSelected(next);
  }

  function continueRingDrag(event: PointerEvent<HTMLButtonElement>) {
    if (!draggingRef.current) return;
    const next = pointerOffset(event);
    if (next) updateSelected(next);
  }

  function endRingDrag(event: PointerEvent<HTMLButtonElement>) {
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
    draggingRef.current = false;
  }

  function nudgeRing(event: KeyboardEvent<HTMLButtonElement>) {
    if (!selectedOptic || !event.key.startsWith("Arrow")) return;
    event.preventDefault();
    const step = event.shiftKey ? 0.05 : 0.01;
    updateSelected({
      offsetX: clamp(selectedOptic.offsetX + (event.key === "ArrowRight" ? step : event.key === "ArrowLeft" ? -step : 0), -0.75, 0.75),
      offsetY: clamp(selectedOptic.offsetY + (event.key === "ArrowDown" ? step : event.key === "ArrowUp" ? -step : 0), -0.75, 0.75),
    });
  }

  function resetSelected() {
    if (!selectedOptic) return;
    updateSelected({
      offsetX: selectedOptic.originalOffsetX,
      offsetY: selectedOptic.originalOffsetY,
      ringScale: selectedOptic.originalRingScale,
      markerScale: selectedOptic.originalMarkerScale,
    });
    setNotice(`${selectedIcon.label} reset to its checked-in optical alignment.`);
  }

  function resetAll() {
    setOptics((current) => Object.fromEntries(Object.entries(current).map(([id, optic]) => [id, {
      ...optic,
      offsetX: optic.originalOffsetX,
      offsetY: optic.originalOffsetY,
      ringScale: optic.originalRingScale,
      markerScale: optic.originalMarkerScale,
    }])));
    localStorage.removeItem(OPTICS_DRAFT_KEY);
    setNotice("All icon optics reset to checked-in values.");
  }

  function makeDocument(includeAll: boolean) {
    const entries = ICONS.filter((icon) => {
      const optic = optics[icon.id];
      return optic && (includeAll || changed(optic));
    });
    const byTheme = (targetTheme: IconTheme) => Object.fromEntries(entries
      .filter((icon) => icon.theme === targetTheme)
      .map((icon) => {
        const optic = optics[icon.id];
        return [icon.id, {
          texture: icon.texture,
          ring_offset: [round(optic.offsetX), round(optic.offsetY)],
          ring_scale: round(optic.ringScale),
          marker_scale: round(optic.markerScale),
        }];
      }));
    return {
      schema_version: 1,
      generated_by: "DNT Icon Alignment Calibrator",
      selection_ring_texture: "Data/textures/DiegeticTravel/thin-circle-selection-ring.dds",
      selection_ring_textures: SELECTION_RING_TEXTURES,
      global_selection_ring_scale: globalRingScale,
      offset_space: "icon_half_extent",
      coordinate_notes: {
        origin: "marker icon center",
        x: "positive moves the ring right by one icon half-extent",
        y: "positive moves the ring down by one icon half-extent",
        marker_scale: "multiplier applied after the provider base size",
        map_positions_and_hitboxes: "unchanged",
      },
      icon_optics: {
        norden: byTheme("norden"),
        vanilla: byTheme("vanilla"),
        ferry: byTheme("ferry"),
      },
    };
  }

  async function copyChanged() {
    await copyText(`${JSON.stringify(makeDocument(false), null, 2)}\n`);
    setNotice(changedCount ? `Copied ${changedCount} changed icon optic${changedCount === 1 ? "" : "s"}.` : "Nothing is adjusted yet; copied an empty optics patch.");
  }

  function importOptics(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    file.text()
      .then((text) => JSON.parse(text) as OpticsDocument)
      .then((document) => {
        let imported = 0;
        setOptics((current) => {
          const next = { ...current };
          for (const icon of ICONS) {
            const source = document.icon_optics?.[icon.theme]?.[icon.id];
            if (!source) continue;
            const offsetX = Number(source.ring_offset?.[0]);
            const offsetY = Number(source.ring_offset?.[1]);
            const ringScale = Number(source.ring_scale);
            const markerScale = Number(source.marker_scale);
            next[icon.id] = {
              ...next[icon.id],
              ...(Number.isFinite(offsetX) ? { offsetX: clamp(offsetX, -0.75, 0.75) } : {}),
              ...(Number.isFinite(offsetY) ? { offsetY: clamp(offsetY, -0.75, 0.75) } : {}),
              ...(Number.isFinite(ringScale) ? { ringScale: clamp(ringScale, 0.6, 1.6) } : {}),
              ...(Number.isFinite(markerScale) ? { markerScale: clamp(markerScale, 0.5, 2.0) } : {}),
            };
            imported += 1;
          }
          return next;
        });
        setNotice(`Imported ${imported} matching icon optic${imported === 1 ? "" : "s"}.`);
      })
      .catch(() => setNotice("That file was not a supported icon-optics JSON document."));
    event.target.value = "";
  }

  const markerScale = selectedOptic?.markerScale ?? 1;
  const ringLeft = selectedOptic ? 50 + selectedOptic.offsetX * markerScale * 50 : 50;
  const ringTop = selectedOptic ? 50 + selectedOptic.offsetY * markerScale * 50 : 50;
  const ringWidth = selectedOptic ? (globalRingScale / 1.12) * selectedOptic.ringScale * markerScale * 100 : 178.571;

  return (
    <main className="calibrator-shell icon-calibrator-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Diegetic Fast Travel / developer tool</p>
          <h1>Icon optical alignment</h1>
        </div>
        <nav className="tool-navigation" aria-label="Calibrator pages">
          <Link href="/">Map layout</Link>
          <Link href="/icon-alignment" className="active" aria-current="page">Icon alignment</Link>
        </nav>
        <div className="topbar-status" aria-live="polite">
          <span className={changedCount ? "status-dot changed" : "status-dot"} />
          {changedCount} changed
        </div>
      </header>

      <section className="icon-workspace">
        <aside className="panel icon-list-panel" aria-label="Icon type list">
          <div className="segmented three icon-theme-switcher" aria-label="Icon theme">
            {(["norden", "vanilla", "ferry"] as IconTheme[]).map((item) => (
              <button key={item} className={theme === item ? "active" : ""} onClick={() => selectTheme(item)}>{item}</button>
            ))}
          </div>
          <div className="icon-type-list">
            {themeIcons.map((icon) => {
              const optic = optics[icon.id];
              return (
                <button key={icon.id} className={selectedIcon?.id === icon.id ? "icon-type-row active" : "icon-type-row"} onClick={() => setSelectedId(icon.id)}>
                  <img src={icon.preview} alt="" />
                  <span><strong>{icon.label}</strong><small>{icon.id}</small></span>
                  {optic && changed(optic) && <i aria-label="Changed" />}
                </button>
              );
            })}
          </div>
        </aside>

        <section className="alignment-column">
          <div className="map-toolbar alignment-toolbar">
            <div className="toolbar-group">
              <label className="file-button secondary">Import optics JSON<input type="file" accept="application/json,.json" onChange={importOptics} /></label>
              <button onClick={() => setShowAlphaBounds((current) => !current)}>{showAlphaBounds ? "Hide" : "Show"} alpha bounds</button>
            </div>
            <span>Ring and icon optics change; map anchor and clickbox stay fixed.</span>
          </div>
          <div className="alignment-stage">
            <div className="alignment-board">
              <div className="alignment-crosshair horizontal" />
              <div className="alignment-crosshair vertical" />
              <div className="alignment-anchor" ref={frameRef}>
                {analysis && showAlphaBounds && (
                  <>
                    <div className="alpha-bounds" style={{ left: `${50 + (analysis.bounds[0] - 0.5) * markerScale * 100}%`, top: `${50 + (analysis.bounds[1] - 0.5) * markerScale * 100}%`, width: `${(analysis.bounds[2] - analysis.bounds[0]) * markerScale * 100}%`, height: `${(analysis.bounds[3] - analysis.bounds[1]) * markerScale * 100}%` }} />
                    <div className="alpha-center bounds-center" style={{ left: `${50 + (analysis.boundsCenter[0] - 0.5) * markerScale * 100}%`, top: `${50 + (analysis.boundsCenter[1] - 0.5) * markerScale * 100}%` }} title="Alpha bounds center" />
                    <div className="alpha-center centroid" style={{ left: `${50 + (analysis.centroid[0] - 0.5) * markerScale * 100}%`, top: `${50 + (analysis.centroid[1] - 0.5) * markerScale * 100}%` }} title="Alpha-weighted centroid" />
                  </>
                )}
                {selectedIcon && <img className="alignment-icon" style={{ width: `${markerScale * 100}%`, height: `${markerScale * 100}%` }} src={selectedIcon.preview} alt={`${selectedIcon.label} icon`} draggable={false} />}
                {selectedOptic && (
                  <button
                    className="alignment-ring"
                    style={{ left: `${ringLeft}%`, top: `${ringTop}%`, width: `${ringWidth}%` }}
                    aria-label={`Selection ring for ${selectedIcon.label}. Drag or use arrow keys to align.`}
                    onPointerDown={beginRingDrag}
                    onPointerMove={continueRingDrag}
                    onPointerUp={endRingDrag}
                    onPointerCancel={endRingDrag}
                    onKeyDown={nudgeRing}
                  >
                    <img src={SELECTION_RING_PREVIEWS[selectedIcon.theme]} alt="" draggable={false} />
                  </button>
                )}
              </div>
              <div className="alignment-legend">
                <span><i className="bounds-swatch" /> Alpha bounds</span>
                <span><i className="bounds-dot" /> Bounds center</span>
                <span><i className="centroid-dot" /> Alpha centroid</span>
              </div>
            </div>
          </div>
          <footer className="map-footer"><span aria-live="polite">{notice}</span><span>Arrow = 0.01 · Shift + Arrow = 0.05</span></footer>
        </section>

        <aside className="panel inspector icon-inspector" aria-label="Icon alignment inspector">
          {selectedIcon && selectedOptic ? (
            <>
              <div>
                <p className="eyebrow">Selected icon type</p>
                <div className="selected-title"><img src={selectedIcon.preview} alt="" /><div><h2>{selectedIcon.label}</h2><code>{selectedIcon.id}</code></div></div>
                <div className="authoring-note"><strong>Shared asset</strong><p>{selectedIcon.usedBy}</p><small>{selectedIcon.texture}</small></div>
                <div className="coordinate-grid optical-grid">
                  <label><span>Ring X offset</span><input type="number" min="-0.75" max="0.75" step="0.01" value={selectedOptic.offsetX.toFixed(4)} onChange={(event) => updateSelected({ offsetX: clamp(Number(event.target.value), -0.75, 0.75) })} /></label>
                  <label><span>Ring Y offset</span><input type="number" min="-0.75" max="0.75" step="0.01" value={selectedOptic.offsetY.toFixed(4)} onChange={(event) => updateSelected({ offsetY: clamp(Number(event.target.value), -0.75, 0.75) })} /></label>
                </div>
                <div className="preview-controls optical-controls">
                  <label><span>Marker size multiplier <b>{selectedOptic.markerScale.toFixed(2)}×</b></span><input type="range" min="0.5" max="2" step="0.01" value={selectedOptic.markerScale} onChange={(event) => updateSelected({ markerScale: Number(event.target.value) })} /></label>
                  <label><span>Ring width multiplier <b>{selectedOptic.ringScale.toFixed(2)}×</b></span><input type="range" min="0.6" max="1.6" step="0.01" value={selectedOptic.ringScale} onChange={(event) => updateSelected({ ringScale: Number(event.target.value) })} /></label>
                  <label><span>Horizontal offset <b>{selectedOptic.offsetX.toFixed(2)}</b></span><input type="range" min="-0.75" max="0.75" step="0.01" value={selectedOptic.offsetX} onChange={(event) => updateSelected({ offsetX: Number(event.target.value) })} /></label>
                  <label><span>Vertical offset <b>{selectedOptic.offsetY.toFixed(2)}</b></span><input type="range" min="-0.75" max="0.75" step="0.01" value={selectedOptic.offsetY} onChange={(event) => updateSelected({ offsetY: Number(event.target.value) })} /></label>
                </div>
                {analysis && visualCentroidOffset && (
                  <div className="alpha-analysis-card">
                    <span>Alpha bounds seed</span><code>{analysis.suggestedOffset[0].toFixed(4)}, {analysis.suggestedOffset[1].toFixed(4)}</code>
                    <span>Visual centroid seed</span><code>{visualCentroidOffset[0].toFixed(4)}, {visualCentroidOffset[1].toFixed(4)}</code>
                    <span>Alpha coverage</span><code>{(analysis.coverage * 100).toFixed(1)}%</code>
                    <button onClick={() => { updateSelected({ offsetX: analysis.suggestedOffset[0], offsetY: analysis.suggestedOffset[1] }); setNotice(`Seeded ${selectedIcon.label} from its visible alpha bounds.`); }}>Use alpha-bounds center</button>
                    <button onClick={() => { updateSelected({ offsetX: visualCentroidOffset[0], offsetY: visualCentroidOffset[1] }); setNotice(`Seeded ${selectedIcon.label} from its alpha-weighted visual centroid.`); }}>Use visual centroid</button>
                  </div>
                )}
                <button className="wide-button" onClick={resetSelected} disabled={!changed(selectedOptic)}>Reset selected</button>
              </div>
              <div className="export-card">
                <div><p className="eyebrow">Export</p><h3>{changedCount} optical change{changedCount === 1 ? "" : "s"}</h3></div>
                <button className="primary-button" onClick={copyChanged}>Copy changed optics</button>
                <button onClick={() => downloadJson("icon-optics-all.json", makeDocument(true))}>Download all icon optics</button>
                <button className="danger-button" onClick={resetAll} disabled={!changedCount}>Discard local draft</button>
              </div>
            </>
          ) : <div className="empty-selection"><span>+</span><p>Select an icon type to begin alignment.</p></div>}
        </aside>
      </section>
    </main>
  );
}
