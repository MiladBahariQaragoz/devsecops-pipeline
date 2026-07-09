# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
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
