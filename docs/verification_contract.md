# Verification Contract

## What This Tool Does

Receives C code + Lean proof + generation certificate.
Checks the SHA-256 chain binding them together.
Optionally re-runs the Lean kernel for independent verification (`--full`).
Returns: accept/reject with detailed check results.

## What `accept` Means

A verification report with `accept: true` certifies ALL of the following:

1. **Kernel acceptance**: the certificate records that `lake build` exited with code 0
2. **Sorry/admit transparency**: the certificate records sorry and admit counts;
   these are surfaced for the user's assessment
3. **Hash integrity**: the C output SHA-256 matches the certificate's `c_output_sha256`
4. **Source integrity**: the Lean source SHA-256 matches the certificate's `lean_source_sha256`
5. **Toolchain match**: the Lean toolchain version matches the certificate's `lean_toolchain`

In `--full` mode, additionally:
6. **Independent rebuild check**: `lake build` and `lake exe` re-ran successfully
   on the provided `lean_source` bundle.
7. **Independent re-export**: re-running the export produced byte-identical C output

## What `accept` Does NOT Mean

- **The specification is correct**: `accept` means the proofs type-check. Whether the
  specification captures the customer's intent is the customer's responsibility.
  A perfectly verified proof of the wrong property is still wrong.
- **The C code is portable**: the emitted C targets a specific runtime model (pointer
  width, integer sizes). It may not compile on all platforms without adaptation.
- **The C code is constant-time or side-channel safe**: the export pipeline emits
  structurally correct C. Timing properties depend on the compiler and hardware.
- **The C code is production-hardened**: no fuzzing, stress testing, or defensive
  coding beyond what the Lean specification requires.
- **Absence of undefined behavior in customer-written C extensions**: if the customer
  extends the generated C with manual code, those extensions are outside the certificate.

## Trust Boundary

The **Lean 4 kernel** is the sole trusted computing base (TCB). It is:
- Open source ([leanprover/lean4](https://github.com/leanprover/lean4))
- Independently auditable
- The same kernel used by the Mathlib mathematical library

The Python wrapper, CLI, and container infrastructure do NO verification.
They orchestrate the Lean kernel and package its results. If you distrust our
infrastructure, you can take the Lean source, install Lean 4.24.0 yourself,
and run `lake build` + `lake exe leancp_export` independently.

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

## Compatibility

```json
{
  "verifier_version": "0.1.0",
  "supported_generation_schema_versions": ["leancp-generation-certificate-v1"],
  "supported_verification_schema_versions": ["leancp-verification-report-v1"],
  "lean_toolchain": "leanprover/lean4:v4.24.0",
  "mode": "verify",
  "bundle_layout_version": "leancp-service-bundle-v1"
}
```

Print the current compatibility contract:

```bash
leancp-verify --print-compatibility
```
