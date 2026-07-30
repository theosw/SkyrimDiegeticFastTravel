from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from .compiler import (
    build_dialogue_manifest,
    compile_runtime,
    validate_endpoint_config,
)


def _read_json(path: Path) -> dict[str, object]:
    with path.open(encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def _write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False)
        stream.write("\n")


def _compile(args: argparse.Namespace) -> int:
    graph = _read_json(args.graph)
    endpoints = _read_json(args.endpoints)
    sensors = _read_json(args.sensors) if args.sensors else None
    runtime, report = compile_runtime(
        graph,
        providers=("carriage",),
        sensor_overrides=sensors,
    )

    endpoint_issues = validate_endpoint_config(runtime, endpoints)
    report["endpoint_issues"] = endpoint_issues
    report["deferred_custom_destinations"] = endpoints.get("custom_destinations", {})

    sensor_issues = report["providers"]["carriage"]["sensor_issues"]
    errors = [
        issue
        for issue in [*sensor_issues, *endpoint_issues]
        if issue.get("severity") == "error"
    ]
    report["release_ready"] = not errors

    dialogue_manifest = build_dialogue_manifest(runtime, endpoints)
    args.out.mkdir(parents=True, exist_ok=True)
    _write_json(args.out / "runtime.json", runtime)
    _write_json(args.out / "dialogue_manifest.json", dialogue_manifest)
    _write_json(args.out / "validation_report.json", report)

    provider_report = report["providers"]["carriage"]
    print(
        "carriage: "
        f"{provider_report['serviced_nodes']} stops, "
        f"{provider_report['route_pairs']} ordered routes, "
        f"{provider_report['average_candidates']} average candidates"
    )
    print(
        f"proximity attachments: {len(provider_report['auto_attached'])}; "
        f"sensor errors: {len(sensor_issues)}; "
        f"endpoint errors: {len(endpoint_issues)}"
    )
    print(f"release ready: {'yes' if report['release_ready'] else 'no'}")

    if errors and not args.allow_incomplete_sensors:
        print(
            "compile failed: release data has unresolved validation errors; "
            "see validation_report.json",
            file=sys.stderr,
        )
        return 2
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="diegetic-travel")
    subparsers = parser.add_subparsers(dest="command", required=True)
    compile_parser = subparsers.add_parser(
        "compile",
        help="compile an authored graph into provider-specific runtime data",
    )
    compile_parser.add_argument("--graph", type=Path, required=True)
    compile_parser.add_argument("--endpoints", type=Path, required=True)
    compile_parser.add_argument("--sensors", type=Path)
    compile_parser.add_argument("--out", type=Path, required=True)
    compile_parser.add_argument(
        "--allow-incomplete-sensors",
        action="store_true",
        help="write diagnostic output and return success despite missing live sensors",
    )
    compile_parser.set_defaults(handler=_compile)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        return int(args.handler(args))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
