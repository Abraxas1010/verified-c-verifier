from __future__ import annotations

from typing import Literal

from pydantic import BaseModel


class GenerationCertificate(BaseModel):
    schema_version: Literal["leancp-generation-certificate-v1"]
    generated_at: str
    lean_toolchain: str
    leancp_library_sha256: str
    lean_source_sha256: str
    lean_build_exit_code: int
    sorry_count: int
    admit_count: int
    c_output_sha256: str
    c_output_deterministic: bool
    generation_log_sha256: str


class VerificationReport(BaseModel):
    accept: bool
    checked_at: str
    failed_checks: list[str]
    lean_source_sha256: str | None = None
    c_output_sha256: str | None = None
    certificate_sha256: str | None = None
    lean_toolchain_match: bool | None = None
    kernel_verdict: str | None = None
