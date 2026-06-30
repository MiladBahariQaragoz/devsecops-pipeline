# Plan — devsecops-pipeline

Milestone tracker. Full design: `docs/superpowers/specs/2026-06-30-devsecops-pipeline-design.md`.

**Build approach:** bottom-up. The OPA/Rego **policy gate is validated offline** against committed
SARIF fixtures (M2) *before* any live scanner is wired (M3), so the repo has a tested decision
point early. **Lab is Linux; Terraform is scan-only — no `terraform apply`, no cloud spend.**

## Milestones

- [ ] **M0 — Scaffold** — git + GitHub remote, `pyproject.toml`/repo skeleton, `CLAUDE.md`, docs
  skeleton, `DISCLAIMER.md` (scan-only / no-spend), `.gitignore` (+ `*.tfstate*`, `.terraform/`),
  `.github/workflows/security.yml` shell. *(Linux box)*
- [ ] **M1 — App** — fresh minimal **secure** Flask service in `app/` + `Dockerfile`
  (pinned `python:3.12-slim`) + smoke test; basic CI build green. *(Docker)*
- [ ] **M2 — Policy spine** — `policy/*.rego` (severity threshold + exception/expiry logic) +
  `data/exceptions.yaml` + `opa test policy/`; `conftest` over committed `fixtures/clean/` (passes)
  and `fixtures/failing/` (denies). Gate works **before** any live scanner. *(opa/conftest)*
- [ ] **M3 — Gates wired** — Semgrep (SAST), Trivy fs (SCA), Gitleaks (secrets), Trivy image
  (container), Checkov/tfsec (IaC) → SARIF → conftest. Plant `demo/failing-gates` (one finding per
  gate); prove each fires and blocks the merge. *(scanners)*
- [ ] **M4 — SBOM + IaC** — Syft → CycloneDX artifact per build; GCP Terraform clean baseline in
  `infra/` + Checkov; failing-branch IaC misconfig (public GCS bucket, `0.0.0.0/0` firewall).
  *(syft/checkov)*
- [ ] **M5 — Policy docs + evidence** — `docs/POLICY.md` (threshold + exception request/approval
  workflow); screenshots: green `main`, blocked `demo/failing-gates` PR, exception-suppresses-one
  demo. README per-gate "why it matters" + shift-left rationale.
- [ ] **M6 — Stretch** — DAST (ZAP) gate; Grype-the-SBOM gate; SARIF upload to GitHub
  code-scanning; cosign image signing; pre-commit hardening.

## Definition of done

See spec §13. Headline: a GitHub Actions pipeline with **5 enforcing gates** (SAST, SCA, secrets,
container, IaC) unified by an **OPA/Rego policy-as-code gate** with a tested, dated exception
process, **+ a per-build SBOM** — green on `main`, merge-blocked on a planted-vuln branch, all
provable offline via `opa test` + `conftest` on committed SARIF fixtures.
