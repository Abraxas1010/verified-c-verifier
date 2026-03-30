from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import GenerationCertificate, VerificationReport
from .version import LEAN_TOOLCHAIN


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def _hash_dir(path: Path) -> str:
    """Deterministic hash of .lean source files in a directory tree.

    Only hashes ``.lean`` files (sorted by relative path), skipping
    ``.lake`` (build cache) and ``.tmp`` (ephemeral artifacts).
    """
    if path.is_file():
        return sha256_hex(path.read_bytes())
    if not path.is_dir():
        return ""
    skip = {".lake", ".tmp"}
    digest = hashlib.sha256()
    for fpath in sorted(path.rglob("*.lean")):
        if skip & set(fpath.parts):
            continue
        digest.update(fpath.relative_to(path).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(fpath.read_bytes())
        digest.update(b"\n")
    return digest.hexdigest()


def verify_generation(
    c_file: Path,
    lean_source: Path,
    certificate: Path,
    *,
    full: bool = False,
    export_target: str | None = None,
) -> VerificationReport:
    """Verify a generation certificate against its artifacts.

    Hash-only mode (default): checks SHA-256 chain without running Lean.
    Full mode (--full): re-runs ``lake build`` and ``leancp_export``
    to independently re-derive all certificate claims.

    Args:
        c_file: Path to the emitted C source file.
        lean_source: Path to the Lean project directory.
        certificate: Path to the generation certificate JSON.
        full: If True, re-run Lean build + export for independent verification.
        export_target: Lake executable target name.
    """
    failed: list[str] = []

    # Input existence checks
    if not c_file.is_file():
        failed.append("c_file_missing")
    if not lean_source.exists():
        failed.append("lean_source_missing")
    if not certificate.is_file():
        failed.append("certificate_missing")

    if failed:
        return VerificationReport(
            accept=False,
            checked_at=now_utc(),
            failed_checks=failed,
            lean_toolchain_match=None,
            kernel_verdict="input_error",
        )

    # Parse certificate
    cert_data = _read_json(certificate)
    try:
        cert = GenerationCertificate.model_validate(cert_data)
    except Exception as exc:
        return VerificationReport(
            accept=False,
            checked_at=now_utc(),
            failed_checks=[f"certificate_schema:{exc}"],
            lean_toolchain_match=None,
            kernel_verdict="certificate_reject",
        )

    # Check 1: C output hash matches certificate
    observed_c_hash = sha256_hex(c_file.read_bytes())
    if cert.c_output_sha256 and observed_c_hash != cert.c_output_sha256:
        failed.append("c_output_sha256")

    # Check 2: Lean source hash matches certificate
    source_hash = _hash_dir(lean_source)
    if source_hash != cert.lean_source_sha256:
        failed.append("lean_source_sha256")

    # Check 3: Toolchain version matches
    toolchain_match = cert.lean_toolchain == LEAN_TOOLCHAIN
    if not toolchain_match:
        failed.append("lean_toolchain_match")

    # Check 4: Build exit code was 0
    if cert.lean_build_exit_code != 0:
        failed.append("lean_build_exit_code")

    # Full verification mode: re-run Lean build + export
    if full and not failed:
        full_failures = _full_verify(lean_source, c_file, export_target)
        failed.extend(full_failures)

    accept = not failed
    return VerificationReport(
        accept=accept,
        checked_at=now_utc(),
        failed_checks=failed,
        lean_source_sha256=source_hash,
        c_output_sha256=observed_c_hash,
        certificate_sha256=sha256_hex(certificate.read_bytes()),
        lean_toolchain_match=toolchain_match,
        kernel_verdict="accepted" if accept else "rejected",
    )


def _full_verify(
    lean_source: Path,
    c_file: Path,
    export_target: str | None,
) -> list[str]:
    """Re-run lake build + export and compare against provided C file."""
    failed: list[str] = []
    target = export_target or "leancp_export"
    if not (lean_source / "lakefile.lean").exists():
        failed.append("full_build_missing_lakefile")
        return failed

    build_dir = lean_source

    try:
        build = subprocess.run(
            ["lake", "build", target],
            cwd=str(build_dir),
            capture_output=True,
            text=True,
            timeout=600,
        )
    except subprocess.TimeoutExpired:
        failed.append("full_build_timeout")
        return failed

    if build.returncode != 0:
        failed.append("full_build_failed")
        return failed

    # Re-run export and compare C output
    with tempfile.NamedTemporaryFile(suffix=".c", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        export = subprocess.run(
            ["lake", "exe", target, "--output", str(tmp_path)],
            cwd=str(build_dir),
            capture_output=True,
            text=True,
            timeout=120,
        )
        if export.returncode != 0 or not tmp_path.exists():
            failed.append("full_export_failed")
        else:
            regen_hash = sha256_hex(tmp_path.read_bytes())
            original_hash = sha256_hex(c_file.read_bytes())
            if regen_hash != original_hash:
                failed.append("full_c_output_mismatch")
    except subprocess.TimeoutExpired:
        failed.append("full_export_timeout")
    finally:
        if tmp_path.exists():
            tmp_path.unlink()

    return failed
