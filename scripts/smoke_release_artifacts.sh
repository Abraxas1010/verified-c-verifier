#!/usr/bin/env bash
# smoke_release_artifacts.sh — build wheel, install in clean venv, verify bundle
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[smoke] Building wheel..."
python3 -m pip wheel --no-deps --wheel-dir "${TMP_DIR}/wheel" . 2>/dev/null

echo "[smoke] Installing in clean venv..."
python3 -m venv "${TMP_DIR}/venv"
"${TMP_DIR}/venv/bin/pip" install --quiet "${TMP_DIR}/wheel"/*.whl

echo "[smoke] Running leancp-verify --version..."
"${TMP_DIR}/venv/bin/leancp-verify" --version

echo "[smoke] Running leancp-verify --print-compatibility..."
"${TMP_DIR}/venv/bin/leancp-verify" --print-compatibility >/dev/null

echo "[smoke] Verifying shipped bundle via installed CLI..."
"${TMP_DIR}/venv/bin/leancp-verify" \
  --c-file "${ROOT}/public_material/verified_c_export_bundle/output.c" \
  --lean-source "${ROOT}/public_material/verified_c_export_bundle/lean_source" \
  --certificate "${ROOT}/public_material/verified_c_export_bundle/generation.json" \
  --json >/dev/null

echo "[smoke] ALL SMOKE CHECKS PASSED"
