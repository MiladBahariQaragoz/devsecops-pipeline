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

## ADR-006 — Separate `policy/` (logic) from top-level `data/` (exception allowlist)

**Date:** 2026-07-05
**Status:** Accepted
**Context:** The design spec's illustrative repo tree (§4.2) nests the
exception allowlist at `policy/data/exceptions.yaml`. `opa test policy/` only
walks the `policy/` directory tree; unit tests must not depend on the real
allowlist file to stay deterministic and offline.
**Decision:** Keep `data/exceptions.yaml` at the repo root, separate from
`policy/`. `opa test` unit tests inject exception fixtures directly
via Rego's `with data.exceptions as [...]` override — they never read the
real file. `conftest` (locally and in CI) loads the real file explicitly via
`--data data`. Confirmed against conftest's own docs and source
(`parser/parser.go`, `docs/options.md`): a YAML file's top-level keys merge
directly into the `data` document — a file with a top-level `exceptions:` key
becomes exactly `data.exceptions` in Rego, regardless of the file's path.
**Consequences:** `opa test` never touches the filesystem for exception data,
keeping unit tests hermetic. Real exception data flows through exactly one
path (`--data data`), matching this plan's own front-matter treatment of
`policy/**` and `data/**` as separate touched-file globs.

## ADR-007 — Severity normalization: priority-ordered resolution, HIGH threshold, CVSS bucket cutoffs

**Date:** 2026-07-05
**Status:** Accepted
**Context:** SARIF has no single universal severity field; scanners disagree
on where severity lives (`result.properties["security-severity"]`, rule-level
`properties["security-severity"]`, or just `level`).
**Decision:** Resolve severity in priority order (result-level score →
rule-level score → `level` mapping → MEDIUM default); bucket numeric scores
using the standard CVSS v3.1 Qualitative Severity Rating Scale (CRITICAL
≥9.0, HIGH ≥7.0, MEDIUM ≥4.0, else LOW); default deny threshold is HIGH.
**Consequences:** One normalization function (`result_severity`) handles all
five planned scanners without per-tool special-casing in the `deny` rule
itself; a scanner that sets no severity information at all defaults to MEDIUM
(visible, non-blocking) rather than silently passing as LOW or hard-failing
as CRITICAL.

## ADR-008 — Exception schema: fail-closed expiry, optional path scoping

**Date:** 2026-07-05
**Status:** Accepted
**Context:** Need dated exceptions (spec §7) that can't silently live
forever, and ideally can scope to one location rather than blanket-suppressing
a rule id repo-wide.
**Decision:** Required fields `rule`, `reason`, `owner`, `expires`
(`YYYY-MM-DD`); optional `path` (suffix match against the SARIF result's
location URI). Expiry cutoff is end-of-day (23:59:59 UTC) of the `expires`
date. Missing or malformed `expires` is treated as expired (fail closed) —
validated with a regex format guard before parsing, so a garbled date cannot
crash the Rego evaluation with a hard `time.parse_rfc3339_ns` error.
**Consequences:** A typo'd date fails safe (denies) rather than failing open
(silently permanent). Path scoping is a simple suffix match, not a full glob —
documented as a known limitation in `docs/POLICY.md`.

## ADR-009 — Pinned, checksum-verified OPA v1.18.2 / conftest v0.68.2; Rego authored in v1 syntax

**Date:** 2026-07-05
**Status:** Accepted
**Context:** Issue #6 (L.3) flagged that the M1-era CI stub pinned OPA to an
unpinned `latest`-resolving URL and had a broken conftest install (the tarball
was downloaded onto the exact path `tar` then tried to read from).
**Decision:** Pin OPA to `v1.18.2` (latest at authoring time, verified via `gh
api repos/open-policy-agent/opa/releases/latest`) using the
`opa_linux_amd64_static` asset plus its `.sha256` sidecar, verified with
`sha256sum -c`. Pin conftest to `v0.68.2` using the `Linux_x86_64.tar.gz`
asset plus the release's combined `checksums.txt`, downloading the tarball to
a distinct filename before extracting (fixing the self-overwrite bug) and
removing it afterward. Both tools are current enough that Rego is authored
directly in v1 syntax (`deny contains msg if { ... }`, `some x in y`) with no
`future.keywords` imports — matching conftest's own current README examples.
**Consequences:** CI installs are deterministic and tamper-evident; resolves
the OPA/conftest portion of issue #6 (the Gitleaks allow-list portion, L.2,
stays open for M3). Any future Rego file in this repo must stay v1-syntax
consistent.
