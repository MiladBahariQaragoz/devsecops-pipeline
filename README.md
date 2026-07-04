# devsecops-pipeline

A GitHub Actions CI/CD pipeline for a small containerised Flask service that **fails the build
on security findings** — five SARIF-emitting gates (Semgrep, Trivy, Gitleaks, Checkov) unified
by an OPA/Rego policy gate (`conftest`) with a dated exception process, plus a Syft CycloneDX
SBOM artifact.

**Full design:** `docs/superpowers/specs/2026-06-30-devsecops-pipeline-design.md`

## Current status

| Milestone | Status |
|-----------|--------|
| M0 — Scaffold | ✅ Done |
| M1 — Secure Flask app + Dockerfile + CI lint/test | ✅ Done |
| M2 — OPA/Rego policy spine + conftest fixtures | ⬜ Planned |
| M3 — Gates wired (5 scanners → SARIF → conftest) | ⬜ Planned |
| M4 — SBOM + GCP Terraform | ⬜ Planned |
| M5 — Policy docs + evidence | ⬜ Planned |

## Security gates (wired in M3)

| Gate | Tool | What it detects |
|------|------|-----------------|
| SAST | Semgrep | SQL injection, XSS, and other code-level bugs |
| SCA | Trivy fs | Known CVEs in Python dependencies |
| Secrets | Gitleaks | Leaked credentials and API keys in source/history |
| Container | Trivy image | CVEs in the base image and installed packages |
| IaC | Checkov | GCP Terraform misconfigurations (public storage, open firewall) |

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

See [DISCLAIMER.md](DISCLAIMER.md). This project is a learning exercise: scan-only, no
`terraform apply`, no cloud spend, no real secrets.
