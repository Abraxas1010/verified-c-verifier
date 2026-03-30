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

**Don't trust us. Verify.**

---

## Why This Exists

Someone hands you a C file and tells you it was "mathematically proven correct." Why should you believe them?

You shouldn't. Not because they're lying — but because trust is the wrong foundation for critical software. Trust is a social mechanism. Mathematics is not social. A proof either type-checks or it doesn't. A hash either matches or it doesn't. These are facts, not promises.

This tool lets you check those facts yourself — on your own machine, offline, without any API calls, accounts, or dependencies on our infrastructure. The mathematical guarantee is not something we sell. It is something we *prove*, and this verifier lets you confirm it independently.

## What This Tool Does

When you receive C code from the [verified-c-from-proof](https://github.com/Abraxas1010/verified-c-from-proof) generation service, you also receive:

- **The Lean 4 source** — the complete specification and proof that the C code was derived from
- **A generation certificate** — a SHA-256 chain binding the proof to the C output

This verifier checks that chain. It answers one question: **was this exact C file produced by the verified pipeline from this exact proof, and has anything been tampered with since?**

### The checks

| # | Check | What It Proves |
|---|-------|---------------|
| 1 | C output SHA-256 | The C file you received is exactly what the pipeline produced — not modified, not substituted |
| 2 | Lean source SHA-256 | The proof you received is exactly what was used to generate the C — not edited after the fact |
| 3 | Toolchain match | The Lean version used for generation matches what this verifier expects |
| 4 | Build exit code | The Lean kernel accepted the proofs — they type-checked, they're valid |
| 5 | Full re-derivation (optional) | Re-runs the entire Lean build and C export to independently reproduce the output |

If all checks pass: `accept = true`. If any fail: `accept = false` with exactly which checks failed and why.

## Why This Matters

### The trust boundary is one thing

The **Lean 4 kernel** — an open-source type checker — is the sole trusted computing base. Everything else (our Python code, our CLI, our cloud infrastructure, our business) is outside the trust boundary.

You don't need to trust our code. You don't need to trust our servers. You don't even need to trust this verifier. Install [Lean 4.24.0](https://github.com/leanprover/lean4) and run `lake build` on the source yourself. If it compiles, the proofs are valid. That's not our claim — that's how type theory works.

### Testing finds bugs. Proofs eliminate them.

A test suite with 100% line coverage can still miss a buffer overflow on one specific input. A formal proof covers *every* input, *every* execution path, *every* edge case — not by trying them all, but by mathematical induction over the structure of the program. The Lean kernel checks that induction. This verifier checks that the kernel's verdict hasn't been forged.

### The verification is free

We charge for the generation service — running the Lean kernel, building the export pipeline, maintaining the infrastructure. The verification is free, open-source, and runs offline. We designed it this way because verification that depends on the vendor's infrastructure isn't real verification.

## Prerequisites

- Python 3.11+
- Lean 4.24.0 via [elan](https://github.com/leanprover/elan) (only for `--full` mode)

Hash-only verification (the default) requires **no Lean installation** and completes in seconds.

## Step-by-Step Guide

### 1. Clone and install

```bash
git clone https://github.com/Abraxas1010/verified-c-verifier.git
cd verified-c-verifier
python3 -m pip install -e .
```

### 2. Try it now — verify the shipped bundle

This repo ships with a real output bundle from the pipeline. No setup required:

```bash
leancp-verify \
  --c-file public_material/verified_c_export_bundle/output.c \
  --lean-source public_material/verified_c_export_bundle/lean_source \
  --certificate public_material/verified_c_export_bundle/generation.json \
  --json
```

You should see `"accept": true`. That's a real certificate for real C code derived from a real kernel-checked Lean proof — and you just verified it on your own machine.

### 3. Verify your own artifacts

You need three things from the generation service:
- The **C source file** (`output.c`)
- The **Lean source directory** (`lean_source/`)
- The **generation certificate** (`generation.json`)

```bash
leancp-verify \
  --c-file /path/to/output.c \
  --lean-source /path/to/lean_source/ \
  --certificate /path/to/generation.json \
  --json
```

### 4. Read the result

**Accepted:**

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

**Rejected:**

```json
{
  "accept": false,
  "failed_checks": ["c_output_sha256"],
  "kernel_verdict": "rejected"
}
```

`failed_checks` tells you exactly what failed:

| Failed Check | Meaning |
|---|---|
| `c_output_sha256` | The C file was modified or substituted after generation |
| `lean_source_sha256` | The Lean source was modified after generation |
| `lean_toolchain_match` | Generated with a different Lean version |
| `lean_build_exit_code` | The Lean kernel rejected the proofs |
| `certificate_schema` | Certificate format is invalid or unrecognized |

### 5. Full independent re-derivation (optional)

If hash checking isn't enough and you want to re-run the Lean kernel yourself:

```bash
leancp-verify \
  --c-file /path/to/output.c \
  --lean-source /path/to/lean_source/ \
  --certificate /path/to/generation.json \
  --full \
  --json
```

This requires Lean 4.24.0 via elan. It will:
1. Run `lake build` to independently kernel-check every proof in the source
2. Run `lake exe leancp_export` to re-derive the C output from scratch
3. Compare the re-derived output byte-for-byte against the file you received

If the hashes match, the C code you have is *exactly* what those proofs produce. Not similar. Not equivalent. Identical.

## Use in scripts

Exit code `0` = accepted, `1` = rejected:

```bash
if leancp-verify --c-file output.c --lean-source lean_source/ --certificate generation.json; then
  echo "Verified — this C code is the proven output of the supplied Lean proofs"
else
  echo "REJECTED — do not use this artifact"
fi
```

## Generation Service

Certificates are created through the hosted generation service at:

**[www.agentpmt.com/marketplace/verified-c-from-proof](https://www.agentpmt.com/marketplace/verified-c-from-proof)**

Submit Lean 4 specifications and proofs. Get back verified C code with a generation certificate. The service runs the Lean kernel on our infrastructure so you don't have to maintain a build environment. It is available as a REST API for CI/CD integration.

**This repo is for independent offline verification.** It exists so you never have to trust our service to know your artifacts are genuine.

## What "Accept" Means — Precisely

**Accept certifies:**
- The Lean kernel accepted the proofs (type-checked, no holes)
- The C output is the deterministic product of those proofs
- The SHA-256 chain is intact from proof to artifact
- The toolchain version is consistent

**Accept does NOT certify:**
- That the specification captures your intent (you wrote the spec — review it)
- That the C is portable to all architectures (it targets a specific runtime model)
- That the C is constant-time (timing depends on compiler and hardware)
- That the C is production-hardened (no fuzzing beyond what the proof covers)

A proof of the wrong theorem is still a valid proof. We verify the *proof*, not the *intent*.

Full details: [docs/verification_contract.md](docs/verification_contract.md)

## Repo Layout

- `verifier/` — verification library (models, SHA-256 chain checking, full re-build)
- `cli/` — command-line entrypoint (`leancp_verify.py`)
- `public_material/` — shipped verification bundle with real, verifiable artifacts
- `docs/` — verification contract
- `examples/` — usage examples

## License

[Apoth3osis License Stack v1](LICENSE.md)
