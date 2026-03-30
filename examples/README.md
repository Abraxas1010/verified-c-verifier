# Examples

## Verify the Shipped Bundle

This repo ships with a real, verifiable output bundle from the LeanCP pipeline
at `public_material/verified_c_export_bundle/`.

### Hash-only verification (no Lean required)

```bash
leancp-verify \
  --c-file ../public_material/verified_c_export_bundle/output.c \
  --lean-source ../public_material/verified_c_export_bundle/lean_source \
  --certificate ../public_material/verified_c_export_bundle/generation.json \
  --json
```

Expected output: `"accept": true`

### Full verification (requires Lean 4.24.0)

```bash
leancp-verify \
  --c-file ../public_material/verified_c_export_bundle/output.c \
  --lean-source ../public_material/verified_c_export_bundle/lean_source \
  --certificate ../public_material/verified_c_export_bundle/generation.json \
  --full \
  --json
```

This re-runs `lake build` and `lake exe leancp_export` to independently confirm
the C output matches.

## Output Bundle Structure

A generation output bundle contains:

```
output/
├── output.c           — generated C source code
├── generation.json    — generation certificate (SHA-256 chain)
├── certificate.json   — alias for generation.json
└── lean_source/       — snapshot of the Lean source used for generation
    ├── lakefile.lean
    ├── lean-toolchain
    └── HeytingLean/
        └── ...
```

The verifier checks `output.c` + `lean_source/` against `generation.json`.
