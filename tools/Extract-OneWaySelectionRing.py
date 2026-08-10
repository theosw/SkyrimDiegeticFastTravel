#!/usr/bin/env python3
"""Derive the lower Norden selection arrow without altering the licensed source art."""

from __future__ import annotations

import argparse
import copy
import xml.etree.ElementTree as ET
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    document = ET.parse(args.input)
    source_root = document.getroot()
    namespace = "http://www.w3.org/2000/svg"
    group = source_root.find(f"{{{namespace}}}g")
    if group is None:
        raise RuntimeError("Norden selection-ring source has no top-level group")
    paths = group.findall(f"{{{namespace}}}path")
    if not paths:
        raise RuntimeError("Norden selection-ring source has no path geometry")

    output_root = ET.Element(source_root.tag, source_root.attrib)
    output_group = ET.SubElement(output_root, group.tag, group.attrib)
    # The source's first path is the light lower/bottom travel arrow. Keeping
    # its original page and transform preserves exact runtime alignment.
    output_group.append(copy.deepcopy(paths[0]))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(output_root).write(args.output, encoding="utf-8", xml_declaration=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
