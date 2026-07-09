# Plan — devsecops-pipeline

Milestone tracker. Full design: `docs/superpowers/specs/2026-06-30-devsecops-pipeline-design.md`.

**Build approach:** bottom-up. The OPA/Rego **policy gate is validated offline** against committed
SARIF fixtures (M2) *before* any live scanner is wired (M3), so the repo has a tested decision
point early. **Lab is Linux.**

**Scope note (2026-07-09):** deliberately right-sized for a hobby/portfolio project. The IaC gate
(Checkov + GCP Terraform) and the M6 stretch gates (DAST, Grype, cosign, pre-commit) were **cut** —
they add CI ceremony without changing the core story. Ships as **4 live gates** (SAST, SCA, secrets,
container) + a per-build **SBOM**, unified by the OPA/Rego policy gate.

## Milestones

- [x] **M0 — Scaffold** — git + GitHub remote, `pyproject.toml`/repo skeleton, `CLAUDE.md`, docs
  skeleton, `DISCLAIMER.md` (scan-only / no-spend), `.gitignore` (+ `*.tfstate*`, `.terraform/`),
  `.github/workflows/security.yml` shell. *(Linux box)*
- [x] **M1 — App** — fresh minimal **secure** Flask service in `app/` + `Dockerfile`
  (pinned `python:3.12-slim`) + smoke test; basic CI build green. *(Docker)*
- [x] **M2 — Policy spine** — `policy/*.rego` (severity threshold + exception/expiry logic) +
  `data/exceptions.yaml` + `opa test policy/`; `conftest` over committed `fixtures/clean/` (passes)
  and `fixtures/failing/` (denies). Gate works **before** any live scanner. *(opa/conftest)*
- [x] **M3 — Gates wired** — Semgrep (SAST), Trivy fs (SCA), Gitleaks (secrets), Trivy image
  (container) → SARIF → conftest, all in one `security-gates` job (scanners emit SARIF, conftest
  enforces). Plant `demo/failing-gates` (one finding per gate); prove each fires and blocks the
  merge. *(scanners)*
- [ ] **M4 — SBOM** — Syft → CycloneDX artifact per build, uploaded as a build artifact. No new
  gate — the SBOM is evidence, not an enforcement point. *(syft)*
- [ ] **M5 — Policy docs + evidence** — `docs/POLICY.md` (threshold + exception request/approval
  workflow); screenshots: green `main`, blocked `demo/failing-gates` PR, exception-suppresses-one
  demo. README per-gate "why it matters" + shift-left rationale.

**Cut (see scope note above):** ~~M4 IaC — Checkov + GCP Terraform~~; ~~M6 stretch — DAST (ZAP),
Grype-the-SBOM, SARIF upload to code-scanning, cosign, pre-commit~~.

## Definition of done

Headline: a GitHub Actions pipeline with **4 enforcing gates** (SAST, SCA, secrets, container)
unified by an **OPA/Rego policy-as-code gate** with a tested, dated exception process, **+ a
per-build SBOM** — green on `main`, merge-blocked on a planted-vuln branch, all provable offline
via `opa test` + `conftest` on committed SARIF fixtures.
