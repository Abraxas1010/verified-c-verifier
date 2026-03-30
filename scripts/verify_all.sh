#!/usr/bin/env bash
# verify_all.sh — verify shipped bundle + negative cases
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[1/3] Compatibility contract..."
leancp-verify --print-compatibility >/dev/null
echo "  PASS"

echo "[2/3] Shipped public_material bundle verification..."
leancp-verify \
  --c-file "${ROOT}/public_material/verified_c_export_bundle/output.c" \
  --lean-source "${ROOT}/public_material/verified_c_export_bundle/lean_source" \
  --certificate "${ROOT}/public_material/verified_c_export_bundle/generation.json" \
  --json >/dev/null
echo "  PASS"

echo "[3/3] Negative cases..."
"${ROOT}/scripts/verify_negative_cases.sh"

echo ""
echo "[verify_all] ALL CHECKS PASSED"
