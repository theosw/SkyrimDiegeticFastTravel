"""Generate the beta carriage dialogue manifest without the route graph."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def form_ref(value: str) -> str:
    return value if value.startswith("__formData|") else f"__formData|{value}"


def editor_token(destination_id: str) -> str:
    return "".join(part.capitalize() for part in destination_id.split("_"))


def build_manifest(endpoints: dict, names: dict[str, str]) -> dict:
    destinations = endpoints["destinations"]
    missing_names = sorted(set(destinations) - set(names))
    extra_names = sorted(set(names) - set(destinations))
    if missing_names or extra_names:
        raise ValueError(
            "destination-name keys do not match CFTO destinations: "
            f"missing={missing_names}, extra={extra_names}"
        )

    supported = sorted(destinations, key=lambda item: names[item])
    globals_by_destination = {
        destination: {
            "available": f"DNT_Available_{editor_token(destination)}",
            "cost": f"DNT_Cost_{editor_token(destination)}",
        }
        for destination in supported
    }

    dialogue = endpoints["dialogue"]
    dialogue_destinations = dialogue["destinations"]
    if set(dialogue_destinations) != set(destinations):
        raise ValueError("CFTO dialogue destinations do not match destination numbers")

    origins: dict[str, dict] = {}
    for origin, origin_data in endpoints["origins"].items():
        origins[origin] = {
            "driver": form_ref(origin_data["driver"]),
            "entries": [
                {
                    "destination": destination,
                    "name": names[destination],
                    "cfto_destination": int(destinations[destination]),
                    "globals": globals_by_destination[destination],
                }
                for destination in supported
                if destination != origin
            ],
        }

    return {
        "schema_version": 2,
        "model": "flat_cfto_beta",
        "plugin": "DiegeticTravel.esp",
        "provider": "carriage",
        "cfto": {
            "quest": form_ref(endpoints["quest"]),
            "destination_global": form_ref(endpoints["destination_global"]),
            "free_faction": form_ref(endpoints["free_faction"]),
        },
        "dialogue": {
            "branch": form_ref(dialogue["branch"]),
            "root_topic": form_ref(dialogue["root_topic"]),
            "root_info": form_ref(dialogue["root_info"]),
            "free_root_info": form_ref(dialogue["free_root_info"]),
            "destinations": {
                destination: {
                    "name": names[destination],
                    **{
                        field: form_ref(data[field])
                        for field in ("topic", "success_info", "failure_info")
                    },
                }
                for destination, data in dialogue_destinations.items()
            },
        },
        "globals": globals_by_destination,
        "origins": origins,
        "deferred_custom_destinations": endpoints.get("custom_destinations", {}),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoints", type=Path, required=True)
    parser.add_argument("--names", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    endpoints = json.loads(args.endpoints.read_text(encoding="utf-8"))
    names = json.loads(args.names.read_text(encoding="utf-8"))
    manifest = build_manifest(endpoints, names)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(
        f"Generated flat CFTO manifest: {args.out} "
        f"({len(manifest['globals'])} destinations, {len(manifest['origins'])} origins)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
