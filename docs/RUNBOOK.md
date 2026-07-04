# Runbook — running security gates locally (Linux)

> **Status:** skeleton — filled in M3–M5 as each gate is wired.

## Prerequisites

> **FUSE mount note:** This repo lives on a Google Drive FUSE mount that cannot create
> symlinks. Use the shared off-Drive virtualenv instead of creating one inside the repo.
> See `docs/DECISIONS.md` ADR-005 for the rationale.

```bash
# Bootstrap the shared off-Drive virtualenv (once, e.g. after a machine rebuild).
# It must live OFF the Google Drive mount because venv creates a lib64 -> lib symlink
# that the FUSE driver rejects with EIO.
python3 -m venv /home/sudo/.venvs/devsecops-pipeline

# Install / update deps after changing app/requirements.txt:
/home/sudo/.venvs/devsecops-pipeline/bin/python -m pip install -r app/requirements.txt
/home/sudo/.venvs/devsecops-pipeline/bin/python -m pip install ruff pytest
```

## Lint and test (available from M1)

```bash
/home/sudo/.venvs/devsecops-pipeline/bin/ruff check .
/home/sudo/.venvs/devsecops-pipeline/bin/pytest -q
```

## OPA/conftest gate (M2+)

*(M2: document opa install, opa test policy/, conftest invocation.)*

## Live scanners (M3+)

*(M3: document Semgrep, Trivy fs, Gitleaks, Trivy image, Checkov invocations + SARIF output
paths, and how to run conftest against the generated SARIF locally.)*

## SBOM (M4+)

*(M4: document Syft invocation + CycloneDX output.)*
