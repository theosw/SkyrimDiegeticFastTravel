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

type Stop = {
  id: string;
  name: string;
  type?: string;
  runtime_enabled?: boolean;
  availability?: string;
  position_status?: string;
  notes?: string;
  map_position: [number, number];
  [key: string]: unknown;
};

type Network = {
  schema_version?: number;
  provider?: string;
  lane?: string;
  map?: {
    uv_crop?: number[];
    art_aspect_ratio?: number;
    selection_ring_scale?: number;
    [key: string]: unknown;
  };
  ui_elements?: UiElementSource[];
  stops: Stop[];
  authoring_stops?: Stop[];
  [key: string]: unknown;
};

type UiElementSource = {
  id: string;
  name: string;
  sample?: string;
  map_position: [number, number];
};

type UiElement = UiElementSource & {
  x: number;
  y: number;
  originalX: number;
  originalY: number;
};

type Marker = Stop & {
  x: number;
  y: number;
  originalX: number;
  originalY: number;
};

type PresetKey =
  | "carriage"
  | "wizard"
  | "north_coast"
  | "lake_honrich"
  | "ilinalta"
  | "solstheim_ferries"
  | "solstheim_merchant";
type FilterKey = "all" | "capital" | "minor";
type IconTheme = "norden" | "vanilla";

const PRESETS: Record<
  PresetKey,
  { label: string; subtitle: string; url: string; mapSource: string }
> = {
  carriage: {
    label: "Carriage network",
    subtitle: "CFTO capitals and on-route stops on the formal chart",
    url: "/presets/carriage.json",
    mapSource: "/wizard-map-reference.jpg",
  },
  wizard: {
    label: "Wizard guides",
    subtitle: "College hub and seven hold capitals",
    url: "/presets/wizard.json",
    mapSource: "/wizard-map-reference.jpg",
  },
  north_coast: {
    label: "Mainland ferries",
    subtitle: "North-coast public ferry network",
    url: "/presets/north-coast.json",
    mapSource: "/map-reference.jpg",
  },
  lake_honrich: {
    label: "Lake Honrich",
    subtitle: "Riften, Heartwood Mill, Ivarstead, and Honeyside",
    url: "/presets/honrich.json",
    mapSource: "/map-reference.jpg",
  },
  ilinalta: {
    label: "Lake Ilinalta",
    subtitle: "Brittleshin Pass, Half-Moon Mill, Guardian Stones",
    url: "/presets/ilinalta.json",
    mapSource: "/map-reference.jpg",
  },
  solstheim_ferries: {
    label: "Solstheim ferries",
    subtitle: "Raven Rock, Tel Mithryn, Skaal Village",
    url: "/presets/solstheim.json",
    mapSource: "/solstheim-ferry-map-reference.jpg",
  },
  solstheim_merchant: {
    label: "Remyris merchant route",
    subtitle: "Raven Rock, Baan Malur, Cormaris",
    url: "/presets/solstheim-merchant.json",
    mapSource: "/solstheim-merchant-map-reference.jpg",
  },
};

function isBoatPreset(preset: PresetKey) {
  return (
    preset === "north_coast" ||
    preset === "lake_honrich" ||
    preset === "ilinalta" ||
    preset === "solstheim_ferries" ||
    preset === "solstheim_merchant"
  );
}

function isFormalPreset(preset: PresetKey) {
  return preset === "wizard" || preset === "carriage";
}

function isNordenMaritimePreset(preset: PresetKey) {
  return preset === "solstheim_merchant";
}

function selectionRingPreview(preset: PresetKey) {
  return isFormalPreset(preset) || isNordenMaritimePreset(preset)
    ? "/markers/thin-circle-selection-ring.png?v=20260808b"
    : "/markers/parchment-thin-selection-ring.png?v=20260808c";
}

function isAuthoringOnly(marker: Marker) {
  return marker.runtime_enabled === false;
}

function availabilityLabel(marker: Marker) {
  return (marker.availability ?? "authoring only").replaceAll("_", " ");
}

const VANILLA_CAPITAL_ICONS: Record<string, string> = {
  college: "winterhold-college",
  winterhold: "winterhold-college",
  whiterun: "whiterun-dragonsreach",
  riften: "riften-mistveil-keep",
  solitude: "solitude-blue-palace",
  windhelm: "windhelm-palace-of-the-kings",
  markarth: "markarth-understone-keep",
  dawnstar: "dawnstar-white-hall",
  morthal: "morthal-highmoon-hall",
  falkreath: "falkreath-jarl-longhouse",
};

const SIX_DECIMALS = 1_000_000;
const MAP_DRAFT_NAMESPACE = "dnt-map-calibrator:v2";

function roundCoordinate(value: number) {
  return Math.round(value * SIX_DECIMALS) / SIX_DECIMALS;
}

function clampCoordinate(value: number) {
  return Math.min(1, Math.max(0, roundCoordinate(value)));
}

function isChanged(item: {
  x: number;
  y: number;
  originalX: number;
  originalY: number;
}) {
  return item.x !== item.originalX || item.y !== item.originalY;
}

function markerIcon(preset: PresetKey, marker: Marker, iconTheme: IconTheme) {
  if (isNordenMaritimePreset(preset)) {
    return marker.id === "raven_rock"
      ? "/markers/norden-shipwreck.png"
      : "/markers/norden-docks.png";
  }

  if (isBoatPreset(preset)) {
    return "/markers/docks-marker.png";
  }

  if (iconTheme === "vanilla") {
    const capitalIcon = VANILLA_CAPITAL_ICONS[marker.id];
    return capitalIcon
      ? `/markers/${capitalIcon}.png`
      : "/markers/town-marker.png";
  }

  if (marker.id === "college") {
    return "/markers/norden-winterhold-capital.png";
  }

  if (marker.type === "capital") {
    return `/markers/norden-${marker.id}-capital.png`;
  }
  if (["mixwater_mill", "halfmoon_mill", "heartwood_mill"].includes(marker.id)) {
    return "/markers/norden-wood-mill.png";
  }
  if (marker.id === "soljunds_sinkhole") {
    return "/markers/norden-mine.png";
  }
  if (["lakeview_manor", "heljarchen_hall", "winstad_manor"].includes(marker.id)) {
    return "/markers/norden-farm.png";
  }
  if (
    [
      "darkwater_crossing",
      "kynesgrove",
      "karthwasten",
      "shors_stone",
      "stonehills",
    ].includes(marker.id)
  ) {
    return "/markers/norden-settlement.png";
  }
  return "/markers/norden-town.png";
}

function markerWidth(preset: PresetKey, marker: Marker) {
  if (isBoatPreset(preset)) return 3.7;
  return marker.type === "capital" || marker.type === "origin" ? 4.35 : 2.75;
}

function downloadJson(filename: string, value: unknown) {
  const blob = new Blob([`${JSON.stringify(value, null, 2)}\n`], {
    type: "application/json",
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

function copyText(text: string) {
  if (navigator.clipboard?.writeText) {
    return navigator.clipboard.writeText(text);
  }
  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.appendChild(textarea);
  textarea.select();
  document.execCommand("copy");
  textarea.remove();
  return Promise.resolve();
}

export function MapCoordinateCalibrator() {
  const [preset, setPreset] = useState<PresetKey>("carriage");
  const [network, setNetwork] = useState<Network | null>(null);
  const [markers, setMarkers] = useState<Marker[]>([]);
  const [uiElements, setUiElements] = useState<UiElement[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedUiId, setSelectedUiId] = useState<string | null>(null);
  const [filter, setFilter] = useState<FilterKey>("all");
  const [iconTheme, setIconTheme] = useState<IconTheme>("norden");
  const [query, setQuery] = useState("");
  const [showLabels, setShowLabels] = useState(false);
  const [showGrid, setShowGrid] = useState(false);
  const [showAuthoringStops, setShowAuthoringStops] = useState(false);
  const [markerScale, setMarkerScale] = useState(1);
  const [selectionRingScale, setSelectionRingScale] = useState(2);
  const [originalSelectionRingScale, setOriginalSelectionRingScale] = useState(2);
  const [mapOpacity, setMapOpacity] = useState(1);
  const [mapSource, setMapSource] = useState(PRESETS.carriage.mapSource);
  const [notice, setNotice] = useState("Loading current coordinates…");
  const mapRef = useRef<HTMLDivElement>(null);
  const dragIdRef = useRef<string | null>(null);
  const customMapUrlRef = useRef<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    fetch(PRESETS[preset].url)
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json() as Promise<Network>;
      })
      .then((data) => {
        if (cancelled) return;
        const draftKey = `${MAP_DRAFT_NAMESPACE}:${preset}:positions`;
        const uiDraftKey = `${MAP_DRAFT_NAMESPACE}:${preset}:ui-positions`;
        const ringDraftKey = `${MAP_DRAFT_NAMESPACE}:${preset}:selection-ring-scale`;
        let draft: Record<string, [number, number]> = {};
        let uiDraft: Record<string, [number, number]> = {};
        try {
          draft = JSON.parse(localStorage.getItem(draftKey) ?? "{}");
          uiDraft = JSON.parse(localStorage.getItem(uiDraftKey) ?? "{}");
        } catch {
          draft = {};
          uiDraft = {};
        }
        const loadedMarkers = [...data.stops, ...(data.authoring_stops ?? [])].map((stop) => {
          const saved = draft[stop.id];
          return {
            ...stop,
            x: saved?.[0] ?? stop.map_position[0],
            y: saved?.[1] ?? stop.map_position[1],
            originalX: stop.map_position[0],
            originalY: stop.map_position[1],
          };
        });
        const loadedUiElements = (data.ui_elements ?? []).map((element) => {
          const saved = uiDraft[element.id];
          return {
            ...element,
            x: saved?.[0] ?? element.map_position[0],
            y: saved?.[1] ?? element.map_position[1],
            originalX: element.map_position[0],
            originalY: element.map_position[1],
          };
        });
        const sourceRingScale = Number(data.map?.selection_ring_scale ?? 2);
        const savedRingScale = Number(localStorage.getItem(ringDraftKey) ?? sourceRingScale);
        setNetwork(data);
        setMarkers(loadedMarkers);
        setUiElements(loadedUiElements);
        setOriginalSelectionRingScale(sourceRingScale);
        setSelectionRingScale(Number.isFinite(savedRingScale) ? savedRingScale : sourceRingScale);
        setNotice(
          Object.keys(draft).length || Object.keys(uiDraft).length
            ? "Restored your local draft."
            : "Ready. Drag a marker or use the arrow keys for fine nudges.",
        );
      })
      .catch((error: Error) => {
        if (!cancelled) setNotice(`Could not load preset: ${error.message}`);
      });

    return () => {
      cancelled = true;
    };
  }, [preset]);

  useEffect(() => {
    if (!network || markers.length === 0) return;
    const positions = Object.fromEntries(
      markers.map((marker) => [marker.id, [marker.x, marker.y]]),
    );
    localStorage.setItem(
      `${MAP_DRAFT_NAMESPACE}:${preset}:positions`,
      JSON.stringify(positions),
    );
  }, [markers, network, preset]);

  useEffect(() => {
    if (!network || uiElements.length === 0) return;
    const positions = Object.fromEntries(
      uiElements.map((element) => [element.id, [element.x, element.y]]),
    );
    localStorage.setItem(
      `${MAP_DRAFT_NAMESPACE}:${preset}:ui-positions`,
      JSON.stringify(positions),
    );
  }, [network, preset, uiElements]);

  useEffect(() => {
    if (!network) return;
    localStorage.setItem(
      `${MAP_DRAFT_NAMESPACE}:${preset}:selection-ring-scale`,
      String(selectionRingScale),
    );
  }, [network, preset, selectionRingScale]);

  useEffect(() => {
    return () => {
      if (customMapUrlRef.current) URL.revokeObjectURL(customMapUrlRef.current);
    };
  }, []);

  const selected = useMemo(
    () => markers.find((marker) => marker.id === selectedId) ?? null,
    [markers, selectedId],
  );

  const selectedUi = useMemo(
    () => uiElements.find((element) => element.id === selectedUiId) ?? null,
    [selectedUiId, uiElements],
  );

  const changedCount = useMemo(
    () =>
      markers.filter(isChanged).length +
      uiElements.filter(isChanged).length +
      (selectionRingScale !== originalSelectionRingScale ? 1 : 0),
    [markers, originalSelectionRingScale, selectionRingScale, uiElements],
  );

  const authoringStopCount = useMemo(
    () => markers.filter(isAuthoringOnly).length,
    [markers],
  );

  const visibleMarkers = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return markers.filter((marker) => {
      if (isAuthoringOnly(marker) && !showAuthoringStops) return false;
      if (filter === "capital" && marker.type !== "capital") return false;
      if (filter === "minor" && marker.type === "capital") return false;
      if (
        normalizedQuery &&
        !marker.name.toLowerCase().includes(normalizedQuery) &&
        !marker.id.toLowerCase().includes(normalizedQuery)
      ) {
        return false;
      }
      return true;
    });
  }, [filter, markers, query, showAuthoringStops]);

  function selectPreset(nextPreset: PresetKey) {
    if (nextPreset === preset) return;
    if (customMapUrlRef.current) {
      URL.revokeObjectURL(customMapUrlRef.current);
      customMapUrlRef.current = null;
    }
    setNetwork(null);
    setMarkers([]);
    setUiElements([]);
    setSelectedId(null);
    setSelectedUiId(null);
    setFilter("all");
    setShowAuthoringStops(false);
    setSelectionRingScale(2);
    setOriginalSelectionRingScale(2);
    setPreset(nextPreset);
    setMapSource(PRESETS[nextPreset].mapSource);
    setNotice("Loading current coordinates…");
  }

  function updateMarker(id: string, x: number, y: number) {
    setMarkers((current) =>
      current.map((marker) =>
        marker.id === id
          ? { ...marker, x: clampCoordinate(x), y: clampCoordinate(y) }
          : marker,
      ),
    );
  }

  function updateUiElement(id: string, x: number, y: number) {
    setUiElements((current) =>
      current.map((element) =>
        element.id === id
          ? { ...element, x: clampCoordinate(x), y: clampCoordinate(y) }
          : element,
      ),
    );
  }

  function pointerCoordinates(event: PointerEvent<HTMLElement>) {
    const rect = mapRef.current?.getBoundingClientRect();
    if (!rect) return null;
    return {
      x: (event.clientX - rect.left) / rect.width,
      y: (event.clientY - rect.top) / rect.height,
    };
  }

  function updateFromPointer(id: string, event: PointerEvent<HTMLElement>) {
    const coordinates = pointerCoordinates(event);
    if (coordinates) updateMarker(id, coordinates.x, coordinates.y);
  }

  function updateUiFromPointer(id: string, event: PointerEvent<HTMLElement>) {
    const coordinates = pointerCoordinates(event);
    if (coordinates) updateUiElement(id, coordinates.x, coordinates.y);
  }

  function beginMarkerDrag(id: string, event: PointerEvent<HTMLButtonElement>) {
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    dragIdRef.current = `marker:${id}`;
    setSelectedId(id);
    setSelectedUiId(null);
    updateFromPointer(id, event);
  }

  function continueMarkerDrag(id: string, event: PointerEvent<HTMLButtonElement>) {
    if (dragIdRef.current !== `marker:${id}`) return;
    updateFromPointer(id, event);
  }

  function beginUiDrag(id: string, event: PointerEvent<HTMLButtonElement>) {
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    dragIdRef.current = `ui:${id}`;
    setSelectedUiId(id);
    setSelectedId(null);
    updateUiFromPointer(id, event);
  }

  function continueUiDrag(id: string, event: PointerEvent<HTMLButtonElement>) {
    if (dragIdRef.current !== `ui:${id}`) return;
    updateUiFromPointer(id, event);
  }

  function endDrag(event: PointerEvent<HTMLButtonElement>) {
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    dragIdRef.current = null;
  }

  function nudgeMarker(id: string, event: KeyboardEvent<HTMLButtonElement>) {
    const marker = markers.find((item) => item.id === id);
    const rect = mapRef.current?.getBoundingClientRect();
    if (!marker || !rect || !event.key.startsWith("Arrow")) return;
    event.preventDefault();
    const amount = event.shiftKey ? 10 : 1;
    const xStep = amount / rect.width;
    const yStep = amount / rect.height;
    const nextX =
      marker.x +
      (event.key === "ArrowRight" ? xStep : event.key === "ArrowLeft" ? -xStep : 0);
    const nextY =
      marker.y +
      (event.key === "ArrowDown" ? yStep : event.key === "ArrowUp" ? -yStep : 0);
    updateMarker(id, nextX, nextY);
  }

  function nudgeUiElement(id: string, event: KeyboardEvent<HTMLButtonElement>) {
    const element = uiElements.find((item) => item.id === id);
    const rect = mapRef.current?.getBoundingClientRect();
    if (!element || !rect || !event.key.startsWith("Arrow")) return;
    event.preventDefault();
    const amount = event.shiftKey ? 10 : 1;
    const xStep = amount / rect.width;
    const yStep = amount / rect.height;
    const nextX =
      element.x +
      (event.key === "ArrowRight" ? xStep : event.key === "ArrowLeft" ? -xStep : 0);
    const nextY =
      element.y +
      (event.key === "ArrowDown" ? yStep : event.key === "ArrowUp" ? -yStep : 0);
    updateUiElement(id, nextX, nextY);
  }

  function resetSelected() {
    if (selected) {
      updateMarker(selected.id, selected.originalX, selected.originalY);
      setNotice(`${selected.name} reset to its checked-in coordinates.`);
    } else if (selectedUi) {
      updateUiElement(selectedUi.id, selectedUi.originalX, selectedUi.originalY);
      setNotice(`${selectedUi.name} reset to its checked-in coordinates.`);
    }
  }

  function resetAll() {
    setMarkers((current) =>
      current.map((marker) => ({
        ...marker,
        x: marker.originalX,
        y: marker.originalY,
      })),
    );
    setUiElements((current) =>
      current.map((element) => ({
        ...element,
        x: element.originalX,
        y: element.originalY,
      })),
    );
    localStorage.removeItem(`${MAP_DRAFT_NAMESPACE}:${preset}:positions`);
    localStorage.removeItem(`${MAP_DRAFT_NAMESPACE}:${preset}:ui-positions`);
    localStorage.removeItem(`${MAP_DRAFT_NAMESPACE}:${preset}:selection-ring-scale`);
    setSelectionRingScale(originalSelectionRingScale);
    setNotice("All markers, layout elements, and selection-ring scale reset to the current source values.");
  }

  function makePatch(includeAll = false) {
    const exported = includeAll ? markers : markers.filter(isChanged);
    const runtimeExported = exported.filter((marker) => !isAuthoringOnly(marker));
    const authoringExported = exported.filter(isAuthoringOnly);
    const exportedUi = includeAll ? uiElements : uiElements.filter(isChanged);
    return {
      schema_version: 1,
      generated_by: "DNT Map Coordinate Calibrator",
      preset,
      icon_theme_preview: isNordenMaritimePreset(preset)
        ? "norden_maritime"
        : isBoatPreset(preset)
          ? null
          : iconTheme,
      selection_ring_preview: selectionRingPreview(preset),
      coordinate_space: {
        origin: "top-left",
        x: "normalized 0..1, left to right",
        y: "normalized 0..1, top to bottom",
        art_aspect_ratio: network?.map?.art_aspect_ratio ?? 1.35809,
        uv_crop: network?.map?.uv_crop ?? [0, 0, 1, 0.736328],
      },
      positions: Object.fromEntries(
        runtimeExported.map((marker) => [
          marker.id,
          [roundCoordinate(marker.x), roundCoordinate(marker.y)],
        ]),
      ),
      authoring_positions: Object.fromEntries(
        authoringExported.map((marker) => [
          marker.id,
          [roundCoordinate(marker.x), roundCoordinate(marker.y)],
        ]),
      ),
      ui_positions: Object.fromEntries(
        exportedUi.map((element) => [
          element.id,
          [roundCoordinate(element.x), roundCoordinate(element.y)],
        ]),
      ),
      visual_settings: { selection_ring_scale: roundCoordinate(selectionRingScale) },
      changes: Object.fromEntries(
        runtimeExported.map((marker) => [
          marker.id,
          {
            name: marker.name,
            from: [marker.originalX, marker.originalY],
            to: [roundCoordinate(marker.x), roundCoordinate(marker.y)],
            delta: [
              roundCoordinate(marker.x - marker.originalX),
              roundCoordinate(marker.y - marker.originalY),
            ],
          },
        ]),
      ),
      authoring_changes: Object.fromEntries(
        authoringExported.map((marker) => [
          marker.id,
          {
            name: marker.name,
            availability: marker.availability ?? "authoring_only",
            from: [marker.originalX, marker.originalY],
            to: [roundCoordinate(marker.x), roundCoordinate(marker.y)],
            delta: [
              roundCoordinate(marker.x - marker.originalX),
              roundCoordinate(marker.y - marker.originalY),
            ],
          },
        ]),
      ),
      ui_changes: Object.fromEntries(
        exportedUi.map((element) => [
          element.id,
          {
            name: element.name,
            from: [element.originalX, element.originalY],
            to: [roundCoordinate(element.x), roundCoordinate(element.y)],
            delta: [
              roundCoordinate(element.x - element.originalX),
              roundCoordinate(element.y - element.originalY),
            ],
          },
        ]),
      ),
      visual_changes:
        includeAll || selectionRingScale !== originalSelectionRingScale
          ? {
              selection_ring_scale: {
                name: "Selection ring scale",
                from: originalSelectionRingScale,
                to: roundCoordinate(selectionRingScale),
                delta: roundCoordinate(selectionRingScale - originalSelectionRingScale),
              },
            }
          : {},
    };
  }

  function makeUpdatedNetwork() {
    if (!network) return null;
    return {
      ...network,
      map: {
        ...(network.map ?? {}),
        selection_ring_scale: roundCoordinate(selectionRingScale),
      },
      stops: network.stops.map((stop) => {
        const marker = markers.find((item) => item.id === stop.id);
        return marker
          ? {
              ...stop,
              map_position: [roundCoordinate(marker.x), roundCoordinate(marker.y)],
            }
          : stop;
      }),
      authoring_stops: (network.authoring_stops ?? []).map((stop) => {
        const marker = markers.find((item) => item.id === stop.id);
        return marker
          ? {
              ...stop,
              map_position: [roundCoordinate(marker.x), roundCoordinate(marker.y)],
            }
          : stop;
      }),
      ui_elements: (network.ui_elements ?? []).map((element) => {
        const current = uiElements.find((item) => item.id === element.id);
        return current
          ? {
              ...element,
              map_position: [roundCoordinate(current.x), roundCoordinate(current.y)],
            }
          : element;
      }),
    };
  }

  async function copyPatch() {
    const patch = makePatch(false);
    await copyText(`${JSON.stringify(patch, null, 2)}\n`);
    setNotice(
      changedCount
        ? `Copied ${changedCount} changed coordinate${changedCount === 1 ? "" : "s"}.`
        : "Nothing has moved yet; copied an empty patch.",
    );
  }

  function loadReferenceMap(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    if (customMapUrlRef.current) URL.revokeObjectURL(customMapUrlRef.current);
    const url = URL.createObjectURL(file);
    customMapUrlRef.current = url;
    setMapSource(url);
    setNotice(`Using local reference image: ${file.name}`);
    event.target.value = "";
  }

  function importCoordinates(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    file
      .text()
      .then((text) => JSON.parse(text) as Record<string, unknown>)
      .then((data) => {
        const positions: Record<string, [number, number]> = {};
        const uiPositions: Record<string, [number, number]> = {};
        if (data.positions && typeof data.positions === "object") {
          Object.assign(positions, data.positions);
        }
        if (data.authoring_positions && typeof data.authoring_positions === "object") {
          Object.assign(positions, data.authoring_positions);
        }
        if (Array.isArray(data.stops)) {
          for (const stop of data.stops as Stop[]) {
            if (stop.id && Array.isArray(stop.map_position)) {
              positions[stop.id] = stop.map_position;
            }
          }
        }
        if (Array.isArray(data.authoring_stops)) {
          for (const stop of data.authoring_stops as Stop[]) {
            if (stop.id && Array.isArray(stop.map_position)) {
              positions[stop.id] = stop.map_position;
            }
          }
        }
        if (data.ui_positions && typeof data.ui_positions === "object") {
          Object.assign(uiPositions, data.ui_positions);
        }
        if (Array.isArray(data.ui_elements)) {
          for (const element of data.ui_elements as UiElementSource[]) {
            if (element.id && Array.isArray(element.map_position)) {
              uiPositions[element.id] = element.map_position;
            }
          }
        }
        const importedVisualSettings =
          data.visual_settings && typeof data.visual_settings === "object"
            ? (data.visual_settings as Record<string, unknown>)
            : data.map && typeof data.map === "object"
              ? (data.map as Record<string, unknown>)
              : null;
        const importedRingScale = Number(importedVisualSettings?.selection_ring_scale);
        const knownIds = new Set(markers.map((marker) => marker.id));
        const importedIds = Object.keys(positions).filter((id) => knownIds.has(id));
        const knownUiIds = new Set(uiElements.map((element) => element.id));
        const importedUiIds = Object.keys(uiPositions).filter((id) => knownUiIds.has(id));
        setMarkers((current) =>
          current.map((marker) => {
            const position = positions[marker.id];
            return position
              ? {
                  ...marker,
                  x: clampCoordinate(Number(position[0])),
                  y: clampCoordinate(Number(position[1])),
                }
              : marker;
          }),
        );
        setUiElements((current) =>
          current.map((element) => {
            const position = uiPositions[element.id];
            return position
              ? {
                  ...element,
                  x: clampCoordinate(Number(position[0])),
                  y: clampCoordinate(Number(position[1])),
                }
              : element;
          }),
        );
        if (Number.isFinite(importedRingScale)) {
          setSelectionRingScale(Math.min(2.8, Math.max(1.2, importedRingScale)));
        }
        const importedCount =
          importedIds.length +
          importedUiIds.length +
          (Number.isFinite(importedRingScale) ? 1 : 0);
        setNotice(`Imported ${importedCount} matching coordinate set${importedCount === 1 ? "" : "s"}.`);
      })
      .catch(() => setNotice("That file was not a supported coordinate patch or network JSON."));
    event.target.value = "";
  }

  return (
    <main className="calibrator-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Diegetic Fast Travel / developer tool</p>
          <h1>Map coordinate calibrator</h1>
        </div>
        <nav className="tool-navigation" aria-label="Calibrator pages">
          <Link href="/" className="active" aria-current="page">Map layout</Link>
          <Link href="/icon-alignment">Icon alignment</Link>
        </nav>
        <div className="topbar-status" aria-live="polite">
          <span className={changedCount ? "status-dot changed" : "status-dot"} />
          {changedCount} changed
        </div>
      </header>

      <section className="workspace">
        <aside className="panel marker-panel" aria-label="Marker list">
          <div className="preset-switcher" role="tablist" aria-label="Network preset">
            {(Object.keys(PRESETS) as PresetKey[]).map((key) => (
              <button
                className={preset === key ? "preset-button active" : "preset-button"}
                key={key}
                onClick={() => selectPreset(key)}
                role="tab"
                aria-selected={preset === key}
              >
                <strong>{PRESETS[key].label}</strong>
                <span>{PRESETS[key].subtitle}</span>
              </button>
            ))}
          </div>

          <label className="search-field">
            <span>Find a marker</span>
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Windhelm, Ilinalta…"
            />
          </label>

          {preset === "carriage" && (
            <div className="segmented" aria-label="Marker filter">
              {(["all", "capital", "minor"] as FilterKey[]).map((key) => (
                <button
                  key={key}
                  className={filter === key ? "active" : ""}
                  onClick={() => setFilter(key)}
                >
                  {key}
                </button>
              ))}
            </div>
          )}

          {(preset === "carriage" || preset === "wizard") && (
            <div className="segmented two" aria-label="Icon theme preview">
              {(["norden", "vanilla"] as IconTheme[]).map((theme) => (
                <button
                  key={theme}
                  className={iconTheme === theme ? "active" : ""}
                  onClick={() => setIconTheme(theme)}
                >
                  {theme}
                </button>
              ))}
            </div>
          )}

          {authoringStopCount > 0 && (
            <div className="authoring-toggle">
              <input
                id="show-authoring-stops"
                type="checkbox"
                checked={showAuthoringStops}
                onChange={(event) => {
                  const next = event.target.checked;
                  setShowAuthoringStops(next);
                  if (!next && selected && isAuthoringOnly(selected)) {
                    setSelectedId(null);
                  }
                }}
              />
              <label htmlFor="show-authoring-stops">
                <strong>Authoring-only locations</strong>
                <small>{authoringStopCount} one-way, locked, or incomplete</small>
              </label>
            </div>
          )}

          <div className="marker-list">
            {visibleMarkers.map((marker) => (
              <button
                key={marker.id}
                className={`${selectedId === marker.id ? "marker-row active" : "marker-row"} ${isAuthoringOnly(marker) ? "authoring-only" : ""}`}
                onClick={() => {
                  setSelectedId(marker.id);
                  setSelectedUiId(null);
                }}
              >
                <img src={markerIcon(preset, marker, iconTheme)} alt="" />
                <span>
                  <strong>{marker.name}</strong>
                  <small>{marker.x.toFixed(6)}, {marker.y.toFixed(6)}</small>
                  {isAuthoringOnly(marker) && (
                    <em>{availabilityLabel(marker)}</em>
                  )}
                </span>
                {isChanged(marker) && <i aria-label="Changed" />}
              </button>
            ))}
            {uiElements.length > 0 && (
              <>
                <p className="list-section-label">Layout elements</p>
                {uiElements.map((element) => (
                  <button
                    key={element.id}
                    className={selectedUiId === element.id ? "marker-row active" : "marker-row"}
                    onClick={() => {
                      setSelectedUiId(element.id);
                      setSelectedId(null);
                    }}
                  >
                    <span className="ui-row-glyph">Aa</span>
                    <span>
                      <strong>{element.name}</strong>
                      <small>{element.x.toFixed(6)}, {element.y.toFixed(6)}</small>
                    </span>
                    {isChanged(element) && <i aria-label="Changed" />}
                  </button>
                ))}
              </>
            )}
          </div>
        </aside>

        <section className="map-column">
          <div className="map-toolbar">
            <div className="toolbar-group">
              <label className="file-button">
                Load map image
                <input type="file" accept="image/*" onChange={loadReferenceMap} />
              </label>
              <button
                onClick={() => {
                  setMapSource(PRESETS[preset].mapSource);
                  setNotice(
                    preset === "wizard" || preset === "carriage"
                      ? "Using the local Skyrim Paper Map reference crop."
                      : preset === "solstheim_ferries"
                        ? "Using the local square-corrected Solstheim physical-map crop."
                        : preset === "solstheim_merchant"
                          ? "Using the installed Solstheim and Baan Malur map reference."
                      : "Using the bundled local RUSTIC MAPS reference crop.",
                  );
                }}
              >
                Use reference crop
              </button>
              <label className="file-button secondary">
                Import JSON
                <input type="file" accept="application/json,.json" onChange={importCoordinates} />
              </label>
            </div>
            <div className="toolbar-group toggles">
              <label><input type="checkbox" checked={showLabels} onChange={(event) => setShowLabels(event.target.checked)} /> Labels</label>
              <label><input type="checkbox" checked={showGrid} onChange={(event) => setShowGrid(event.target.checked)} /> Grid</label>
            </div>
          </div>

          <div className="map-stage">
            <div
              className={`map-art ${showGrid ? "show-grid" : ""}`}
              ref={mapRef}
              style={{ aspectRatio: String(network?.map?.art_aspect_ratio ?? 1.35809) }}
            >
              <img
                className="map-image"
                src={mapSource}
                alt={`${PRESETS[preset].label} parchment map reference`}
                draggable={false}
                style={{ opacity: mapOpacity }}
                onError={() => setNotice("Reference image missing. Use ‘Load map image’ to choose a local PNG or JPG.")}
              />
              {visibleMarkers.map((marker) => (
                <button
                  key={marker.id}
                  className={`map-marker ring-map-marker ${selectedId === marker.id ? "selected" : ""} ${isChanged(marker) ? "moved" : ""} ${isAuthoringOnly(marker) ? "authoring-only" : ""}`}
                  style={{
                    left: `${marker.x * 100}%`,
                    top: `${marker.y * 100}%`,
                    width: `${markerWidth(preset, marker) * markerScale}%`,
                  }}
                  title={`${marker.name}: ${marker.x.toFixed(6)}, ${marker.y.toFixed(6)}${isAuthoringOnly(marker) ? ` · ${availabilityLabel(marker)}` : ""}`}
                  aria-label={`${marker.name}. ${isAuthoringOnly(marker) ? `${availabilityLabel(marker)}. Authoring only. ` : ""}X ${marker.x.toFixed(6)}, Y ${marker.y.toFixed(6)}. Drag or use arrow keys to move.`}
                  onPointerDown={(event) => beginMarkerDrag(marker.id, event)}
                  onPointerMove={(event) => continueMarkerDrag(marker.id, event)}
                  onPointerUp={endDrag}
                  onPointerCancel={endDrag}
                  onKeyDown={(event) => nudgeMarker(marker.id, event)}
                >
                  {selectedId === marker.id && (
                    <img
                      className="selection-ring-preview"
                      src={selectionRingPreview(preset)}
                      alt=""
                      draggable={false}
                      style={{ width: `${(selectionRingScale / 1.12) * 100}%` }}
                    />
                  )}
                  <img className="marker-icon" src={markerIcon(preset, marker, iconTheme)} alt="" draggable={false} />
                  {showLabels && <span>{marker.name}</span>}
                </button>
              ))}
              {uiElements.map((element) => (
                <button
                  key={element.id}
                  className={`map-ui-element ${selectedUiId === element.id ? "selected" : ""} ${isChanged(element) ? "moved" : ""}`}
                  style={{
                    left: `${element.x * 100}%`,
                    top: `${element.y * 100}%`,
                  }}
                  title={`${element.name}: ${element.x.toFixed(6)}, ${element.y.toFixed(6)}`}
                  aria-label={`${element.name}. X ${element.x.toFixed(6)}, Y ${element.y.toFixed(6)}. Drag or use arrow keys to move.`}
                  onPointerDown={(event) => beginUiDrag(element.id, event)}
                  onPointerMove={(event) => continueUiDrag(element.id, event)}
                  onPointerUp={endDrag}
                  onPointerCancel={endDrag}
                  onKeyDown={(event) => nudgeUiElement(element.id, event)}
                >
                  {element.sample ?? element.name}
                </button>
              ))}
            </div>
          </div>

          <footer className="map-footer">
            <span aria-live="polite">{notice}</span>
            <span>Arrow = 1 px · Shift + Arrow = 10 px</span>
          </footer>
        </section>

        <aside className="panel inspector" aria-label="Marker inspector">
          <div>
            <p className="eyebrow">Selected marker</p>
            {selected ? (
              <>
                <div className="selected-title">
                  <img src={markerIcon(preset, selected, iconTheme)} alt="" />
                  <div>
                    <h2>{selected.name}</h2>
                    <code>{selected.id}</code>
                    {isAuthoringOnly(selected) && (
                      <span className="availability-badge">{availabilityLabel(selected)}</span>
                    )}
                  </div>
                </div>
                {isAuthoringOnly(selected) && (
                  <div className="authoring-note">
                    <strong>Authoring only</strong>
                    <p>{selected.notes ?? "This location is not enabled in the playable network."}</p>
                    {selected.position_status && <small>Position: {selected.position_status}</small>}
                  </div>
                )}
                <div className="coordinate-grid">
                  <label>
                    <span>X / left → right</span>
                    <input
                      type="number"
                      min="0"
                      max="1"
                      step="0.000001"
                      value={selected.x.toFixed(6)}
                      onChange={(event) => updateMarker(selected.id, Number(event.target.value), selected.y)}
                    />
                  </label>
                  <label>
                    <span>Y / top → bottom</span>
                    <input
                      type="number"
                      min="0"
                      max="1"
                      step="0.000001"
                      value={selected.y.toFixed(6)}
                      onChange={(event) => updateMarker(selected.id, selected.x, Number(event.target.value))}
                    />
                  </label>
                </div>
                <div className="delta-card">
                  <span>Checked in</span>
                  <code>{selected.originalX.toFixed(6)}, {selected.originalY.toFixed(6)}</code>
                  <span>Delta</span>
                  <code className={isChanged(selected) ? "delta-changed" : ""}>
                    {roundCoordinate(selected.x - selected.originalX).toFixed(6)}, {roundCoordinate(selected.y - selected.originalY).toFixed(6)}
                  </code>
                </div>
                <button className="wide-button" onClick={resetSelected} disabled={!isChanged(selected)}>
                  Reset selected
                </button>
              </>
            ) : selectedUi ? (
              <>
                <div className="selected-title">
                  <span className="selected-ui-glyph">Aa</span>
                  <div>
                    <h2>{selectedUi.name}</h2>
                    <code>{selectedUi.id}</code>
                  </div>
                </div>
                <div className="coordinate-grid">
                  <label>
                    <span>X / left → right</span>
                    <input
                      type="number"
                      min="0"
                      max="1"
                      step="0.000001"
                      value={selectedUi.x.toFixed(6)}
                      onChange={(event) => updateUiElement(selectedUi.id, Number(event.target.value), selectedUi.y)}
                    />
                  </label>
                  <label>
                    <span>Y / top → bottom</span>
                    <input
                      type="number"
                      min="0"
                      max="1"
                      step="0.000001"
                      value={selectedUi.y.toFixed(6)}
                      onChange={(event) => updateUiElement(selectedUi.id, selectedUi.x, Number(event.target.value))}
                    />
                  </label>
                </div>
                <div className="delta-card">
                  <span>Checked in</span>
                  <code>{selectedUi.originalX.toFixed(6)}, {selectedUi.originalY.toFixed(6)}</code>
                  <span>Delta</span>
                  <code className={isChanged(selectedUi) ? "delta-changed" : ""}>
                    {roundCoordinate(selectedUi.x - selectedUi.originalX).toFixed(6)}, {roundCoordinate(selectedUi.y - selectedUi.originalY).toFixed(6)}
                  </code>
                </div>
                <button className="wide-button" onClick={resetSelected} disabled={!isChanged(selectedUi)}>
                  Reset selected
                </button>
              </>
            ) : (
              <div className="empty-selection">
                <span>+</span>
                <p>Select a marker or layout element on the map or in the list.</p>
              </div>
            )}
          </div>

          <div className="preview-controls">
            <label>
              <span>Preview zoom (not exported) <b>{Math.round(markerScale * 100)}%</b></span>
              <input type="range" min="0.6" max="1.6" step="0.05" value={markerScale} onChange={(event) => setMarkerScale(Number(event.target.value))} />
            </label>
            <label>
              <span>Selection ring extent <b>{selectionRingScale.toFixed(2)}×</b></span>
              <input
                type="range"
                min="1.2"
                max="2.8"
                step="0.05"
                value={selectionRingScale}
                onChange={(event) => setSelectionRingScale(Number(event.target.value))}
              />
            </label>
            <label>
              <span>Map opacity <b>{Math.round(mapOpacity * 100)}%</b></span>
              <input type="range" min="0.25" max="1" step="0.05" value={mapOpacity} onChange={(event) => setMapOpacity(Number(event.target.value))} />
            </label>
          </div>

          <div className="export-card">
            <div>
              <p className="eyebrow">Export</p>
              <h3>{changedCount} coordinate change{changedCount === 1 ? "" : "s"}</h3>
            </div>
            <button className="primary-button" onClick={copyPatch}>Copy changed patch</button>
            <button
              onClick={() => downloadJson(`${preset}-coordinates-all.json`, makePatch(true))}
            >
              Download all coordinates
            </button>
            <button
              onClick={() => {
                const updated = makeUpdatedNetwork();
                if (updated) downloadJson(`${preset}-network-updated.json`, updated);
              }}
              disabled={!network}
            >
              Download updated network
            </button>
            <button className="danger-button" onClick={resetAll} disabled={!changedCount}>
              Discard local draft
            </button>
          </div>
        </aside>
      </section>
    </main>
  );
}
