# Architecture Decision Records

> Decisions are logged here as they are made. Format: context → options → decision → consequences.

## ADR-001 — Policy-as-code engine: OPA/Rego via conftest

**Date:** 2026-06-30  
**Status:** Accepted  
**Context:** Need a single decision point that evaluates SARIF from multiple scanners uniformly  
and blocks CI on HIGH+ findings unless an exception is present and unexpired.  
**Decision:** Use OPA/Rego evaluated by `conftest`. Scanners normalise to SARIF; Rego decides
pass/fail. `opa test` unit-tests the policy offline against committed SARIF fixtures.  
**Consequences:** Learning curve for Rego; deterministic offline testability; single enforcement
point regardless of which scanner produced a finding.

## ADR-002 — IaC target: GCP Terraform, scan-only

**Date:** 2026-06-30  
**Status:** Accepted  
**Context:** Need an IaC gate to demonstrate Checkov/tfsec detection. Author has GCP experience.  
**Decision:** GCP Terraform under `infra/`, scanned statically only. `terraform apply` is never
run in v1. No GCP project, no service account, no billable resource.  
**Consequences:** Zero cloud cost; IaC gate is demonstrable without credentials.

## ADR-003 — Base image: python:3.12-slim (pinned)

**Date:** 2026-06-30  
**Status:** Accepted  
**Context:** Container gate (Trivy image) needs a clean baseline on `main`. The failing branch
swaps to an EOL, CVE-laden image to make the gate fire.  
**Decision:** Pin `python:3.12-slim` (LTS, actively patched). In a production context, pin to a
digest; for this learning repo, pinning the tag is sufficient for the demo contrast.  
**Consequences:** Trivy image scan on `main` will be clean; swapping to `python:3.9` on
`demo/failing-gates` produces a clear Trivy HIGH+ finding.

## ADR-004 — MIT license for a public learning repo

**Date:** 2026-06-30  
**Status:** Accepted  
**Context:** The repo is public and portfolio-facing. License needed for clarity.  
**Decision:** MIT — permissive, standard for personal/portfolio projects.  
**Consequences:** Anyone can fork/adapt; attribution required in redistributions.

## ADR-005 — Local virtualenv lives off-Drive

**Date:** 2026-06-30  
**Status:** Accepted  
**Context:** The repository is stored on a Google Drive FUSE mount (`rclone`). The FUSE driver
does not support symlink creation (returns EIO). Python's `venv` module creates a `lib64 → lib`
symlink during setup, so `python3 -m venv .venv` fails inside the repo directory.  
**Options considered:**
- In-repo `.venv` — fails due to FUSE symlink restriction.
- System pip — unavailable / unsafe.
- Off-Drive venv at `~/.venvs/devsecops-pipeline` — works; reading on-Drive code from an off-Drive venv succeeds.
**Decision:** Maintain the project virtualenv at `~/.venvs/devsecops-pipeline`. All local
lint/test commands use the absolute path `/home/sudo/.venvs/devsecops-pipeline/bin/...`.
CI and Docker use `python:3.12-slim` and are unaffected by this constraint.  
**Consequences:** Local developer experience diverges slightly from CI (different Python version);
documented in CLAUDE.md and RUNBOOK.md. Off-Drive venv must be re-created if the machine is
rebuilt (bootstrap instructions in RUNBOOK.md).
