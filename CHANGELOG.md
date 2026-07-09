# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Right-sized scope for a hobby/portfolio project: **cut the IaC gate** (Checkov + GCP
  Terraform) and the M6 stretch gates (DAST, Grype, cosign, pre-commit). Ships as 4 live
  gates (SAST, SCA, secrets, container) + a per-build SBOM, unified by the OPA/Rego policy
  gate. `plan.md`, `README.md`, and `CLAUDE.md` updated to match; the `security.yml` IaC
  TODO was removed. See ADR-013.

### Added
- M3 live security gates: a `security-gates` CI job runs four real scanners in pinned
  official images — Semgrep (SAST, `p/python`), Trivy fs (SCA, `requirements.txt`),
  Gitleaks (secrets, full history), Trivy image (container) — each emitting SARIF into
  `sarif/`. A single `conftest` step over the live SARIF is the sole enforcement point,
  denying HIGH+ findings without a valid exception. Scanners run non-failing; Trivy uses
  `--ignore-unfixed` so unfixable base-image OS CVEs don't red `main`. SARIF uploaded as a
  build artifact. IaC/Checkov deferred to M4 (needs `infra/`). See ADR-011.
- Policy severity resolution refined for real scanner output (ADR-012): honor a rule's
  `defaultConfiguration.level` when a result omits `level` (Semgrep), and floor Gitleaks
  findings to HIGH (secrets carry no severity in SARIF). +4 `opa test` cases (now 25).

### Fixed
- Test fixture flake: the shared-cache in-memory SQLite DB was destroyed when its last
  connection closed, causing an intermittent `no such table: items`. The `client`
  fixture now holds a keepalive connection open for the test's lifetime.
- CI tool installs (`opa`, `conftest`) now download with `curl --fail --retry`, so a
  transient release-CDN error aborts loudly at the download instead of poisoning the
  checksum file and failing with a misleading "no properly formatted checksum lines"
  error. See ADR-010.

## [0.2.0] — 2026-07-09

### Added
- M2 policy spine: OPA/Rego policy gate validated offline before any live scanner.
  - `policy/severity.rego` — severity normalization (SARIF level + `security-severity`)
    and HIGH/CRITICAL threshold deny rule; fails closed on missing/garbage severity.
  - `policy/exceptions.rego` — dated exception matching (rule id + optional path scope)
    with fail-closed expiry handling for missing/malformed/calendar-invalid dates.
  - `data/exceptions.yaml` — documented exception schema (empty baseline).
  - `fixtures/clean/` and `fixtures/failing/` — SARIF fixtures for all 5 planned gates
    (Semgrep, Trivy fs, Trivy image, Checkov, Gitleaks); one planted finding per gate.
  - CI: `opa-policy-tests` (`opa test policy/`, 21 tests) + `conftest-fixtures` gate
    (clean passes, failing denies), both on pinned, checksum-verified binaries.
- `docs/POLICY.md`: threshold, resolution order, and exception request/approval workflow.
- `docs/DECISIONS.md`: ADR-006..ADR-009 (M2 policy design decisions).

## [0.1.0] — 2026-06-30

### Added
- M0 scaffold: CLAUDE.md, DISCLAIMER.md, LICENSE, CHANGELOG.md, README.md, plan.md,
  .gitignore, docs skeleton (POLICY.md, DECISIONS.md, RUNBOOK.md).
- M1: minimal secure Flask service (app/), Dockerfile (python:3.12-slim, non-root),
  pytest smoke test, ruff config (pyproject.toml), CI lint+test job green on main.
  Future gate stages stubbed in .github/workflows/security.yml.
