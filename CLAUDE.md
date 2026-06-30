# CLAUDE.md — devsecops-pipeline

Project guide for Claude and agentic workers.

## What this repo is

A self-paced learning project: a GitHub Actions CI/CD pipeline for a small containerised Flask
service that **fails the build on security findings** (5 SARIF-emitting gates unified by an
OPA/Rego policy gate). Full design: `docs/superpowers/specs/2026-06-30-devsecops-pipeline-design.md`.

**Lab: Linux. Terraform: scan-only — no `terraform apply`, no cloud spend.**

## Repo info

- Remote: https://github.com/MiladBahariQaragoz/devsecops-pipeline
- Default branch: `main`
- Work on feature branches; never push directly to `main`.

## Stack

- Python 3.12 (CI + Docker); local Python may differ — always use the venv.
- Flask, SQLite (stdlib), pytest, ruff.
- Docker image: `python:3.12-slim` (pinned digest in Dockerfile).
- CI: GitHub Actions (`.github/workflows/security.yml`).
- Security gates (M2+): Semgrep, Trivy, Gitleaks, Checkov, conftest (OPA/Rego).

## Virtualenv (Linux — ALWAYS use this)

> **Note:** This repo lives on a Google Drive FUSE mount that cannot create symlinks.
> `python3 -m venv .venv` fails with EIO inside the repo directory. The local virtualenv
> lives **off-Drive** at `~/.venvs/devsecops-pipeline` (see `docs/DECISIONS.md` ADR-005).
> Use the absolute venv path for all local tooling.

```bash
# Lint
/home/sudo/.venvs/devsecops-pipeline/bin/ruff check .

# Test
/home/sudo/.venvs/devsecops-pipeline/bin/pytest -q

# Install deps after updating requirements.txt
/home/sudo/.venvs/devsecops-pipeline/bin/python -m pip install -r app/requirements.txt

# Run the app locally (for manual smoke testing only)
FLASK_SECRET_KEY=dev /home/sudo/.venvs/devsecops-pipeline/bin/python -m flask --app app run
```

CI uses Python 3.12; the off-Drive venv may use a different version — that is fine for lint
and test (no C-extension deps). Docker and CI are the authoritative runtimes.

## Verification gate (run before every commit — spec §12)

```bash
/home/sudo/.venvs/devsecops-pipeline/bin/ruff check .
/home/sudo/.venvs/devsecops-pipeline/bin/pytest -q
# After M2: opa test policy/
# After M2: conftest run --policy policy/ fixtures/
```

All checks must be green before committing. Never fake a pass.

## Git workflow

- Branch: `<type>/<short-kebab>` (e.g. `feat/m1-flask-app`).
- Atomic commits; conventional messages: `feat`/`fix`/`refactor`/`chore`/`docs`/`test`.
- Push after every intentional commit.
- No `--no-verify`; no `--author`; no `Co-Authored-By` trailer.
- Docs updated in the same commit as the code they describe.

## Cost & safety invariants (non-negotiable)

- No `terraform apply`; no live cloud; no billable resources in v1.
- Planted "secret" on `demo/failing-gates` is an obvious fake (never a real credential).
- Vulnerable artifacts never deployed; ephemeral CI containers torn down with the job.
- `.env*` is git-ignored.

## Docs discipline

`CLAUDE.md` and `docs/` are committed. Update `README.md`, `CHANGELOG.md`, `plan.md`,
`docs/POLICY.md`, `docs/DECISIONS.md`, `docs/RUNBOOK.md`, and `app/README.md` in the same commit
as the code they describe. A task is not done until its doc is current.
