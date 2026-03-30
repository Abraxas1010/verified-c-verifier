from __future__ import annotations

VERIFIER_VERSION = "0.1.0"
GENERATION_SCHEMA_VERSION = "leancp-generation-certificate-v1"
VERIFY_SCHEMA_VERSION = "leancp-verification-report-v1"
LEAN_TOOLCHAIN = "leanprover/lean4:v4.24.0"


def compatibility_contract() -> dict[str, object]:
    return {
        "verifier_version": VERIFIER_VERSION,
        "supported_generation_schema_versions": [GENERATION_SCHEMA_VERSION],
        "supported_verification_schema_versions": [VERIFY_SCHEMA_VERSION],
        "lean_toolchain": LEAN_TOOLCHAIN,
        "mode": "verify",
        "bundle_layout_version": "leancp-service-bundle-v1",
        "accept_means": [
            "Lean build exited with code 0",
            "no unresolved sorry/admit (reported in certificate)",
            "generated C output hash matches certificate",
            "lean source hash matches certificate",
            "Lean toolchain matches certificate",
        ],
        "accept_does_not_mean": [
            "the specification is mathematically correct",
            "the generated C is portable without additional assumptions",
            "the code is production hardened",
            "timing, performance, or side-channel guarantees",
        ],
    }
