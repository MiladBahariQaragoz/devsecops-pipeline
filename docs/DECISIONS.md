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

## ADR-010 — Fail-fast, retrying downloads for pinned CI tool installs

**Date:** 2026-07-09
**Status:** Accepted
**Context:** The `opa`/`conftest` install steps (ADR-009) fetched the release
assets and their checksum sidecars with `curl -sSL`, which follows redirects
but does **not** fail on a 4xx/5xx response. During a transient GitHub release-
CDN disruption the checksum sidecar download returned an HTML error page; curl
saved it happily, and `sha256sum -c` then failed with the misleading `no
properly formatted checksum lines found` — a real download outage surfacing as
an opaque checksum error, and re-runs kept failing while the CDN was flaky.
**Decision:** Wrap all four tool/checksum downloads in
`curl --fail --retry 3 --retry-delay 2 --retry-all-errors -sSL`. `--fail` makes
a bad HTTP status abort the step with a clear cause instead of poisoning the
checksum file; `--retry`/`--retry-all-errors` rides out transient CDN blips
automatically.
**Consequences:** Transient CDN errors self-heal via retry; a genuine outage
fails loudly at the download, not deceptively at checksum verification. The
pinning + `sha256sum -c` tamper-evidence from ADR-009 is unchanged.

## ADR-011 — Live gates: pinned scanner images emit SARIF; conftest is the sole enforcer

**Date:** 2026-07-09
**Status:** Accepted
**Context:** M3 wires the real scanners behind the M2 policy gate. Two choices had
to be made: (a) how to run each scanner reproducibly, and (b) where enforcement
happens. Marketplace actions (`aquasecurity/trivy-action`, `gitleaks-action`,
`semgrep-action`) each need their own commit-SHA pin and pull transitive action
code; several also fail the job on findings, which would split enforcement across
five places.
**Decision:** Run each scanner in its **pinned official container image** inside
plain `run:` steps — `semgrep/semgrep:1.168.0`, `aquasec/trivy:0.72.0`,
`zricethezav/gitleaks:v8.30.1` — mirroring the pinned-binary discipline already
used for opa/conftest (ADR-009). Every scanner is configured **non-failing**
(Trivy `--exit-code 0`, Gitleaks `--exit-code 0`, Semgrep non-error by default)
and writes SARIF into `sarif/`. A single final `conftest` step over
`sarif/*.sarif` is the **sole enforcement point** — it denies HIGH+ findings
without a valid, unexpired exception, so the merge-blocking decision lives in one
tested place (the M2 policy), not scattered across scanner exit codes.
Trivy runs with **`--ignore-unfixed`** so only actionable (fix-available) HIGH+
CVEs gate; unfixable base-image OS CVEs cannot permanently red `main`.
**Consequences:** Fewer third-party action pins; one uniform SARIF model; the gate
verdict is reproducible offline (M2 fixtures) and live (this job). IaC/Checkov is
deferred to M4 where `infra/` is introduced, so M3 gates only what already exists
(app source, dependencies, secrets, container image).

## ADR-012 — Severity resolution refined for real Semgrep and Gitleaks SARIF

**Date:** 2026-07-09
**Status:** Accepted
**Context:** The M2 policy was authored and unit-tested against hand-written SARIF
fixtures. When the M3 live gates were first run against the `demo/failing-gates`
branch, only the Trivy gates denied — the Semgrep and Gitleaks findings passed
through, despite being real HIGH-value issues. Inspecting the actual tool output
revealed two SARIF conventions the fixtures had not captured:
  1. **Semgrep** omits `level` on each result and instead declares it once on the
     rule (`rules[].defaultConfiguration.level`). The policy only read
     `result.level`, so ERROR-level Semgrep findings fell through to the MEDIUM
     default and did not gate.
  2. **Gitleaks** emits neither `level` nor `security-severity` on its results —
     it carries no severity signal at all. The MEDIUM default meant a committed
     secret did not gate.
**Decision:** Extend `result_severity` with two tiers (see POLICY.md for the full
order): after `result.level`, fall back to the matching rule's
`defaultConfiguration.level` (SARIF-compliant inheritance); and floor any finding
from a tool named `gitleaks` to HIGH, since a detected secret is categorically
high-severity. Added four `opa test` cases (default-config error denies / warning
allowed; gitleaks-no-severity denies; non-gitleaks-no-severity stays MEDIUM).
**Consequences:** All five conventions (result score, rule score, result level,
rule default-config level, gitleaks floor) are covered, so real Semgrep/Gitleaks
output gates correctly. `main` stays green (its clean scans produce zero results);
the offline fixtures still pass/deny unchanged. This is the concrete payoff of the
build order — validating the policy offline first, then discovering the real-SARIF
gaps the moment live scanners ran.
