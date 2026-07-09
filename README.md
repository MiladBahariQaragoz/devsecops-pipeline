# devsecops-pipeline

A GitHub Actions CI/CD pipeline for a small containerised Flask service that **fails the build
on security findings** — four SARIF-emitting gates (Semgrep, Trivy fs, Gitleaks, Trivy image)
unified by an OPA/Rego policy gate (`conftest`) with a dated exception process, plus a Syft
CycloneDX SBOM artifact.

**Full design:** `docs/superpowers/specs/2026-06-30-devsecops-pipeline-design.md`

## Current status

| Milestone | Status |
|-----------|--------|
| M0 — Scaffold | ✅ Done |
| M1 — Secure Flask app + Dockerfile + CI lint/test | ✅ Done |
| M2 — OPA/Rego policy spine + conftest fixtures | ✅ Done |
| M3 — Gates wired (4 scanners → SARIF → conftest) | ✅ Done |
| M4 — SBOM (Syft CycloneDX) | ✅ Done |
| M5 — Policy docs + evidence | ⬜ Planned |

> **Scope:** deliberately right-sized for a hobby/portfolio project. The IaC gate (Checkov +
> Terraform) and stretch gates (DAST, Grype, cosign) were cut — see `plan.md`.

## Security gates (wired in M3)

| Gate | Tool | What it detects |
|------|------|-----------------|
| SAST | Semgrep | SQL injection, XSS, and other code-level bugs |
| SCA | Trivy fs | Known CVEs in Python dependencies |
| Secrets | Gitleaks | Leaked credentials and API keys in the working tree |
| Container | Trivy image | CVEs in the base image and installed packages |

Each gate emits SARIF, which a single **OPA/Rego policy gate** (`conftest`) evaluates. A
HIGH-or-above finding with no valid, unexpired exception blocks the merge.

## Running locally

> **FUSE mount note:** If your working tree is on a network filesystem (e.g. Google Drive via
> rclone FUSE), `python3 -m venv .venv` will fail with an EIO symlink error. Create the
> virtualenv off the mount instead. See [`docs/RUNBOOK.md`](docs/RUNBOOK.md) for the
> off-repo venv setup used by this project.

```bash
# Virtualenv (standard — works on a local filesystem)
python3 -m venv .venv
.venv/bin/python -m pip install -r app/requirements.txt ruff pytest
.venv/bin/python -m pip install -e .

# Lint
.venv/bin/ruff check .

# Test
.venv/bin/python -m pytest -q

# Run the app
FLASK_SECRET_KEY=dev .venv/bin/python -m flask --app app run
```

## Disclaimer

See [DISCLAIMER.md](DISCLAIMER.md). This project is a learning exercise: scan-only, no cloud
spend, no real secrets.
