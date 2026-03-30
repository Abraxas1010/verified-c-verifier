#!/usr/bin/env bash
# verify_negative_cases.sh — verify mode must reject tampered inputs
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Use the shipped bundle as the valid baseline
BUNDLE="${ROOT}/public_material/verified_c_export_bundle"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

expect_reject() {
  local label="$1"
  shift
  set +e
  output=$(leancp-verify "$@" --json 2>&1)
  rc=$?
  set -e
  if [ $rc -eq 0 ]; then
    echo "  FAIL [${label}]: unexpectedly accepted" >&2
    FAIL=$((FAIL + 1))
  else
    echo "  PASS [${label}]"
    PASS=$((PASS + 1))
  fi
}

echo "[negative] Missing C file..."
expect_reject "missing_c_file" \
  --c-file "${TMP_DIR}/nonexistent.c" \
  --lean-source "${BUNDLE}/lean_source" \
  --certificate "${BUNDLE}/generation.json"

echo "[negative] Missing certificate..."
expect_reject "missing_cert" \
  --c-file "${BUNDLE}/output.c" \
  --lean-source "${BUNDLE}/lean_source" \
  --certificate "${TMP_DIR}/nonexistent.json"

echo "[negative] Malformed certificate JSON..."
echo "not-json" > "${TMP_DIR}/malformed_certificate.json"
expect_reject "malformed_cert" \
  --c-file "${BUNDLE}/output.c" \
  --lean-source "${BUNDLE}/lean_source" \
  --certificate "${TMP_DIR}/malformed_certificate.json"

echo "[negative] Missing Lean source..."
expect_reject "missing_lean" \
  --c-file "${BUNDLE}/output.c" \
  --lean-source "${TMP_DIR}/nonexistent_dir" \
  --certificate "${BUNDLE}/generation.json"

echo "[negative] Tampered C file..."
cp "${BUNDLE}/output.c" "${TMP_DIR}/tampered.c"
echo "// tampered" >> "${TMP_DIR}/tampered.c"
expect_reject "tampered_c" \
  --c-file "${TMP_DIR}/tampered.c" \
  --lean-source "${BUNDLE}/lean_source" \
  --certificate "${BUNDLE}/generation.json"

echo "[negative] Wrong toolchain in certificate..."
python3 -c "
import json
cert = json.load(open('${BUNDLE}/generation.json'))
cert['lean_toolchain'] = 'leanprover/lean4:v4.25.0'
json.dump(cert, open('${TMP_DIR}/bad_toolchain.json','w'), indent=2)
"
expect_reject "wrong_toolchain" \
  --c-file "${BUNDLE}/output.c" \
  --lean-source "${BUNDLE}/lean_source" \
  --certificate "${TMP_DIR}/bad_toolchain.json"

echo "[negative] Wrong C hash in certificate..."
python3 -c "
import json
cert = json.load(open('${BUNDLE}/generation.json'))
cert['c_output_sha256'] = 'deadbeef' * 8
json.dump(cert, open('${TMP_DIR}/bad_hash.json','w'), indent=2)
"
expect_reject "wrong_c_hash" \
  --c-file "${BUNDLE}/output.c" \
  --lean-source "${BUNDLE}/lean_source" \
  --certificate "${TMP_DIR}/bad_hash.json"

echo ""
echo "[verify-negative] ${PASS} passed, ${FAIL} failed"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
