#!/usr/bin/env python3
"""Report openapi.yaml endpoints that no Gherkin scenario in features/ exercises.

Endpoints are (METHOD, PATH) pairs taken from the `paths:` section of the spec.
Feature coverage is detected from step lines of the form:

    When I send a <METHOD> request to "<path>"

Concrete path segments (``/pet/10``) and Scenario Outline placeholders
(``/pet/<petId>``) are matched against templated spec segments (``/pet/{petId}``).
Query strings are ignored.

Exit status is 1 when at least one endpoint is uncovered. When GITHUB_OUTPUT is
set, `uncovered` (newline-separated, multiline output) and `uncovered_count`
are written to it.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import yaml

HTTP_METHODS = ("get", "put", "post", "delete", "options", "head", "patch", "trace")
STEP_RE = re.compile(
    r'^\s*(?:When|And|But|Given|Then|\*)\s+I send an?\s+([A-Za-z]+)\s+request to\s+"([^"]+)"',
    re.IGNORECASE,
)


def load_spec_endpoints(spec_path: Path) -> set[tuple[str, str]]:
    with spec_path.open(encoding="utf-8") as fh:
        spec = yaml.safe_load(fh)
    endpoints: set[tuple[str, str]] = set()
    for path, item in (spec.get("paths") or {}).items():
        if not isinstance(item, dict):
            continue
        for method in HTTP_METHODS:
            if method in item:
                endpoints.add((method.upper(), path))
    return endpoints


def extract_feature_requests(features_dir: Path) -> list[tuple[str, str, str]]:
    requests: list[tuple[str, str, str]] = []
    for feature in sorted(features_dir.glob("*.feature")):
        for lineno, line in enumerate(feature.read_text(encoding="utf-8").splitlines(), 1):
            match = STEP_RE.match(line)
            if match:
                requests.append((match.group(1).upper(), match.group(2), f"{feature.name}:{lineno}"))
    return requests


def strip_query(path: str) -> str:
    return path.split("?", 1)[0].split("#", 1)[0]


def is_param_segment(segment: str) -> bool:
    return segment.startswith("{") and segment.endswith("}")


def match_spec_path(concrete: str, spec_paths: set[str]) -> str | None:
    """Resolve a concrete request path to its templated spec path.

    A literal match wins (``/pet/findByStatus`` over ``/pet/{petId}``); otherwise
    the first template whose non-parameter segments all match is returned.
    """
    concrete = strip_query(concrete).rstrip("/") or "/"
    if concrete in spec_paths:
        return concrete
    concrete_segments = concrete.split("/")
    candidates = []
    for spec_path in spec_paths:
        spec_segments = spec_path.rstrip("/").split("/")
        if len(spec_segments) != len(concrete_segments):
            continue
        if all(
            is_param_segment(s) or s == c
            for s, c in zip(spec_segments, concrete_segments)
        ):
            candidates.append(spec_path)
    if not candidates:
        return None
    # Prefer the template with the fewest parameters (most specific).
    candidates.sort(key=lambda p: sum(is_param_segment(s) for s in p.split("/")))
    return candidates[0]


def write_github_output(uncovered: list[tuple[str, str]]) -> None:
    output_file = os.environ.get("GITHUB_OUTPUT")
    if not output_file:
        return
    lines = [f"{method} {path}" for method, path in uncovered]
    with open(output_file, "a", encoding="utf-8") as fh:
        fh.write(f"uncovered_count={len(uncovered)}\n")
        fh.write("uncovered<<EOF_UNCOVERED\n")
        fh.write("\n".join(lines) + ("\n" if lines else ""))
        fh.write("EOF_UNCOVERED\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--spec", default="src/main/resources/openapi.yaml", type=Path)
    parser.add_argument("--features", default="features", type=Path)
    args = parser.parse_args()

    if not args.spec.is_file():
        print(f"error: spec not found: {args.spec}", file=sys.stderr)
        return 2

    endpoints = load_spec_endpoints(args.spec)
    spec_paths = {path for _, path in endpoints}

    if not args.features.is_dir():
        print(f"warning: features directory not found: {args.features} (treating as no coverage)")
    requests = extract_feature_requests(args.features) if args.features.is_dir() else []

    covered: dict[tuple[str, str], list[str]] = {}
    unmatched: list[tuple[str, str, str]] = []
    for method, raw_path, location in requests:
        spec_path = match_spec_path(raw_path, spec_paths)
        if spec_path is None or (method, spec_path) not in endpoints:
            unmatched.append((method, raw_path, location))
            continue
        covered.setdefault((method, spec_path), []).append(location)

    uncovered = sorted(ep for ep in endpoints if ep not in covered)

    print(f"Spec: {args.spec} ({len(endpoints)} endpoints)")
    print(f"Features: {args.features} ({len(requests)} request steps in {len(list(args.features.glob('*.feature'))) if args.features.is_dir() else 0} files)")
    print()
    print("Covered endpoints:")
    for method, path in sorted(covered):
        print(f"  [x] {method:6} {path}  ({len(covered[(method, path)])} steps)")
    if unmatched:
        print()
        print("Request steps not matching any spec endpoint:")
        for method, path, location in unmatched:
            print(f"  [?] {method:6} {path}  ({location})")
    print()
    if uncovered:
        print(f"UNCOVERED endpoints ({len(uncovered)}):")
        for method, path in uncovered:
            print(f"  [ ] {method:6} {path}")
    else:
        print("All endpoints are covered by feature scenarios.")

    write_github_output(uncovered)
    return 1 if uncovered else 0


if __name__ == "__main__":
    sys.exit(main())
