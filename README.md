<img src="assets/Apoth3osis.webp" alt="Apoth3osis — formal mathematics and verified software" width="140"/>

<sub><strong>Our tech stack is ontological:</strong><br>
<strong>Hardware — Physics</strong><br>
<strong>Software — Mathematics</strong><br><br>
<strong>Our engineering workflow is simple:</strong> discover, build, grow, learn &amp; teach</sub>

---

<sub>
<strong>Acknowledgment</strong><br>
We humbly thank the collective intelligence of humanity for providing the technology and culture we cherish. We do our best to properly reference the authors of the works utilized herein, though we may occasionally fall short. Our engineering is a reciprocal contribution to a broader formal ecosystem.
</sub>

---

[![License: Apoth3osis License Stack v1](https://img.shields.io/badge/License-Apoth3osis%20License%20Stack%20v1-blue.svg)](LICENSE.md)

# Verified C Verifier

Independently verify that C code was derived from kernel-checked Lean 4 proofs — offline, without calling the issuing API.

When someone gives you a C file, Lean source, and a generation certificate, this tool answers one question: **was this exact C code produced by a verified Lean-to-C pipeline, and has anything been tampered with since?**

## What This Tool Checks

1. **C output integrity** — SHA-256 of the C file you have matches what the pipeline produced
2. **Lean source integrity** — SHA-256 of the Lean source tree matches the certificate
3. **Toolchain match** — the Lean 4 toolchain version matches the certificate
4. **Build success** — the Lean kernel accepted the proofs (exit code 0)
5. **Full re-verification** (optional) — re-runs `lake build` and `lake exe` to independently reproduce the C output

If all checks pass: `accept = true`. If any check fails: `accept = false` with a list of exactly which checks failed.

## Prerequisites

- Python 3.11+
- Lean 4.24.0 via [elan](https://github.com/leanprover/elan) (only for `--full` mode)

Hash-only verification (the default) requires **no Lean installation**.

## Step-by-Step Verification Guide

### Step 1: Clone this repo

```bash
git clone https://github.com/Abraxas1010/verified-c-verifier.git
cd verified-c-verifier
```

### Step 2: Install Python dependencies

```bash
python3 -m pip install -e .
```

### Step 3: Verify the shipped bundle

This repo ships with a real, verifiable output bundle. Try it immediately:

```bash
leancp-verify \
  --c-file public_material/verified_c_export_bundle/output.c \
  --lean-source public_material/verified_c_export_bundle/lean_source \
  --certificate public_material/verified_c_export_bundle/generation.json \
  --json
```

### Step 4: Verify your own artifacts

You need three things from the generation service:
- The **C source file** (the generated output)
- The **Lean source directory** (the proofs that produced it)
- The **generation certificate** (the SHA-256 chain binding them)

```bash
leancp-verify \
  --c-file /path/to/output.c \
  --lean-source /path/to/lean_source/ \
  --certificate /path/to/generation.json \
  --json
```

### Step 5: Read the result

**If verification passes:**

```json
{
  "accept": true,
  "failed_checks": [],
  "c_output_sha256": "eb080fcb...",
  "lean_source_sha256": "a3f1c9d2...",
  "lean_toolchain_match": true,
  "kernel_verdict": "accepted"
}
```

`accept: true` means: the C file matches the certificate, the Lean source matches, and the kernel accepted the proofs.

**If verification fails:**

```json
{
  "accept": false,
  "failed_checks": ["c_output_sha256", "lean_source_sha256"],
  "kernel_verdict": "rejected"
}
```

`failed_checks` tells you exactly what went wrong. Common failures:

| Failed Check | What It Means |
|---|---|
| `c_output_sha256` | The C file doesn't match the certificate — wrong file, or file was modified |
| `lean_source_sha256` | The Lean source doesn't match — source was modified after generation |
| `lean_toolchain_match` | Certificate was generated with a different Lean version than this verifier expects |
| `lean_build_exit_code` | The Lean kernel rejected the proofs (build failed) |
| `certificate_schema` | The certificate JSON doesn't match the expected schema |

### Step 6: Full independent verification (optional)

If you want to go beyond hash checking and independently re-run the Lean kernel:

```bash
leancp-verify \
  --c-file /path/to/output.c \
  --lean-source /path/to/lean_source/ \
  --certificate /path/to/generation.json \
  --full \
  --json
```

This requires Lean 4.24.0 installed via elan. It will:
1. Run `lake build` on the Lean source to kernel-check the proofs
2. Run `lake exe leancp_export` to re-derive the C output
3. Compare the re-derived C output against the provided file

Additional `--full` failure modes:

| Failed Check | What It Means |
|---|---|
| `full_build_missing_lakefile` | The Lean source bundle is missing `lakefile.lean` |
| `full_build_failed` | `lake build` failed — the proofs don't type-check |
| `full_build_timeout` | Build exceeded 600s timeout |
| `full_export_failed` | `lake exe` failed to produce C output |
| `full_c_output_mismatch` | Re-derived C output differs from the provided file |

## Text Output Mode

Omit `--json` for a compact text format:

```bash
leancp-verify \
  --c-file output.c \
  --lean-source lean_source/ \
  --certificate generation.json
```

```
accept: True
failed_checks: []
lean_toolchain_match: True
kernel_verdict: accepted
```

The exit code is `0` for accept and `1` for reject, so you can use it in scripts:

```bash
if leancp-verify --c-file output.c --lean-source lean_source/ --certificate generation.json; then
  echo "Verified"
else
  echo "Verification failed"
fi
```

## Generation Service

Generation certificates are created through the hosted service at:

**[www.agentpmt.com/marketplace/verified-c-from-proof](https://www.agentpmt.com/marketplace/verified-c-from-proof)**

The hosted service accepts Lean 4 specifications and proofs, runs the Lean kernel to verify them, and emits C source code with a generation certificate. It is available as a REST API for integration into CI/CD pipelines, automated workflows, and custom tooling.

**This repo is for independent offline verification.** It lets you confirm generation certificates without any API calls, accounts, or trust in our servers. The mathematical guarantee is free and portable — the Lean 4 kernel is open source.

## What "Accept" Means — and Doesn't Mean

**Accept means:**
- The Lean kernel accepted the proofs (build exit code 0)
- The C output SHA-256 matches the signed certificate
- The Lean source SHA-256 matches the signed certificate
- The Lean toolchain version matches

**Accept does NOT mean:**
- The specification is mathematically correct
- The generated C is portable without additional assumptions
- The C code is constant-time or side-channel safe
- The code is production hardened

The certificate proves **that specific C code was derived from kernel-checked Lean proofs** — nothing more.

## Trust Model

The **Lean 4 kernel** is the sole trusted computing base (TCB). It is:
- Open source ([leanprover/lean4](https://github.com/leanprover/lean4))
- Independently auditable
- The same kernel used by the Mathlib mathematical library

The Python wrapper, CLI, and container infrastructure do NO verification. They orchestrate the Lean kernel and package its results. If you distrust our infrastructure, you can take the Lean source, install Lean 4.24.0 yourself, and run `lake build` + `lake exe leancp_export` independently.

## Certificate Schema

```json
{
  "schema_version": "leancp-generation-certificate-v1",
  "generated_at": "2026-03-30T12:00:00Z",
  "lean_toolchain": "leanprover/lean4:v4.24.0",
  "leancp_library_sha256": "<SHA-256 of LeanCP library oleans>",
  "lean_source_sha256": "<SHA-256 of input Lean source tree>",
  "lean_build_exit_code": 0,
  "sorry_count": 0,
  "admit_count": 0,
  "c_output_sha256": "<SHA-256 of emitted C file>",
  "c_output_deterministic": true,
  "generation_log_sha256": "<SHA-256 of build log>"
}
```

## Repo Layout

- `verifier/` — verification library (models, SHA-256 chain checking, full re-build logic)
- `cli/` — command-line entrypoint (`leancp_verify.py`)
- `public_material/` — shipped verification bundle with real, verifiable artifacts
- `docs/` — verification contract
- `examples/` — usage examples and expected outputs

## License

[Apoth3osis License Stack v1](LICENSE.md)
