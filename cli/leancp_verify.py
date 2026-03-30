from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from verifier.verify import verify_generation
from verifier.version import VERIFIER_VERSION, compatibility_contract


def _write_or_print(payload: object, as_json: bool) -> None:
    if as_json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        if isinstance(payload, dict):
            for key, val in payload.items():
                print(f"{key}: {val}")
        else:
            print(payload)


def main(argv: list[str] | None = None) -> int:
    raw = list(sys.argv[1:] if argv is None else argv)

    # Early exits that don't require the full argument set
    if "--version" in raw:
        print(VERIFIER_VERSION)
        return 0
    if "--print-compatibility" in raw:
        print(json.dumps(compatibility_contract(), indent=2, sort_keys=True))
        return 0

    parser = argparse.ArgumentParser(
        prog="leancp-verify",
        description="Independently verify LeanCP generation certificates.",
    )
    parser.add_argument("--c-file", required=True, help="Path to emitted C source.")
    parser.add_argument("--lean-source", required=True, help="Path to Lean source directory.")
    parser.add_argument("--certificate", required=True, help="Path to generation certificate JSON.")
    parser.add_argument("--full", action="store_true", help="Re-run Lean build + export for independent verification.")
    parser.add_argument("--export-target", default=None, help="Lake exe target name (for --full mode).")
    parser.add_argument("--json", action="store_true", help="Emit structured JSON output.")
    args = parser.parse_args(raw)

    report = verify_generation(
        c_file=Path(args.c_file).resolve(),
        lean_source=Path(args.lean_source).resolve(),
        certificate=Path(args.certificate).resolve(),
        full=args.full,
        export_target=args.export_target,
    )
    _write_or_print(report.model_dump(), args.json)
    return 0 if report.accept else 1


if __name__ == "__main__":
    raise SystemExit(main())
