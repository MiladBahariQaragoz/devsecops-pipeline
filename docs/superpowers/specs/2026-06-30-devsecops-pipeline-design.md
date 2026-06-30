# Design — DevSecOps CI/CD Pipeline with Security Gates (`devsecops-pipeline`)

- **Date:** 2026-06-30
- **Status:** Approved (brainstorming)
- **Project:** personal hobby / self-paced learning project (own git repo → GitHub `devsecops-pipeline`)
- **Remote:** https://github.com/MiladBahariQaragoz/devsecops-pipeline
- **Estimated effort:** 3–4 weeks
- **Lab environment:** Linux (native security tooling; no `terraform apply`, no cloud spend by default)

## 1. Summary

A GitHub Actions CI/CD pipeline for a small containerised service that **fails the build on
security findings**, with every gate explained. The repository is the build-time / supply-chain
counterpart to project 04 (`webapp-pentest-range`): where project 04 *finds* vulnerabilities by
pentest, this project *prevents and gates* them at merge time and proves software supply-chain
hygiene.

Five independent security gates each emit a common report format (**SARIF**) which is evaluated by
a single **OPA/Rego policy gate** (`conftest`). The policy fails the build on any HIGH-or-above
finding that does not carry a valid, unexpired exception — so "policy as code" and the exception
process are executable, not prose. A Software Bill of Materials (SBOM) is produced on every build.

The headline evidence is a contrast: a clean `main` branch whose pipeline is green, and a
deliberately-failing branch (`demo/failing-gates`) that re-introduces exactly one finding per gate
and is **blocked from merging** — plus an exception demo that clears one finding while the rest
still block, proving the exception workflow is real.

Why this project: it is a self-paced learning project, built for fun. The author already enjoys
Docker + GCP + Git + CI/CD work, and this is a natural place to go deeper on the security side —
learning to "shift left" and add the "Sec" by building a pipeline that *ships* secure software,
complementing the companion pentest project's (`webapp-pentest-range`) offensive story.

## 2. Goal & non-goals

**Goal.** Produce a public, reproducible repository with a GitHub Actions pipeline in which ≥4
(actually 5) distinct security gates are wired and *enforcing*: each blocks a merge on
high-severity findings via a single policy-as-code decision point, an SBOM is produced per build,
and the whole thing is demonstrated by a green clean branch and a blocked failing branch — all
traceable from a finding → its SARIF result → the Rego rule that denied it → the planted cause.

**Non-goals (YAGNI / scope guards).**
- Not a re-implementation of any scanner — the pipeline *runs* Semgrep / Trivy / Gitleaks /
  Checkov and *evaluates* their SARIF; it does not reinvent their detection logic.
- Not a pentest project — discovery, manual exploitation, and the OWASP WSTG report belong to
  project 04. SAST overlap is intentional; the novel value here is SCA, secrets, container, and
  IaC gates + policy-as-code + the exception process + SBOM.
- **No `terraform apply`, no live cloud, no billable resources in v1.** The Terraform is scanned
  statically only. See §4.3 cost-safety invariant.
- Not a DAST project — OWASP ZAP / runtime scanning is a documented stretch goal (project 04
  already demonstrates ZAP), kept out of v1 to avoid duplication and CI flakiness.
- Not a multi-app monorepo — one small sample service is enough to exercise every gate.

## 3. Decisions locked during brainstorming

| # | Decision | Choice |
|---|----------|--------|
| Q1 | Policy-as-code engine (the spine) | **OPA / Rego evaluated by `conftest`** — scanners normalise to SARIF, Rego decides pass/fail; `opa test` unit-tests the policy and committed SARIF fixtures prove it offline |
| Q2 | IaC target | **GCP Terraform, scan-only** (matches owner's GCP strength); never applied — no cloud account or cost |
| Q3 | Sample app | **Fresh minimal Flask service** written for this repo (secure on `main`); the failing branch re-plants one finding per gate |
| Q4 | DAST gate (OWASP ZAP) | **Deferred to stretch** — v1 ships 5 enforcing gates + SBOM, already beyond the README's ≥4 |
| a | CI platform | **GitHub Actions** (whole portfolio is on GitHub) |
| b | SBOM | **Syft → CycloneDX** JSON build artifact; "Grype the SBOM" is a stretch gate |
| c | Scanner consolidation | **Trivy** does double duty: SCA (filesystem) **and** container-image scan, both SARIF |
| d | Lab environment | **Linux** — native tooling, Linux-first standing commands; no Windows venv path quirks |

## 4. Architecture

### 4.1 Pipeline flow

```
 developer push / pull request
        │
        ▼
 GitHub Actions ───── scanners (each → SARIF) ─────────────────┐
   ├─ Semgrep          SAST        → semgrep.sarif             │
   ├─ Trivy fs         SCA (deps)  → trivy-fs.sarif            │
   ├─ Gitleaks         secrets     → gitleaks.sarif            ▼
   ├─ Trivy image      container   → trivy-image.sarif   conftest (OPA/Rego)
   ├─ Checkov (+tfsec) IaC         → checkov.sarif       policy/*.rego
   └─ Syft             SBOM        → sbom.cyclonedx.json  data/exceptions.yaml
                                       (artifact, not a gate)      │
                                                                   │ severity ≥ HIGH
                                                                   │ AND no valid,
                                                                   │ unexpired exception
                                                                   ▼   ⇒ deny
                                                       exit ≠ 0  ⇒  merge blocked
```

Every gate except the SBOM converges on **SARIF**, so `conftest` evaluates one uniform model
(`runs[].results[]`) regardless of which scanner produced a finding. The SBOM is a parallel
artifact (supply-chain evidence), optionally re-scanned by Grype as a stretch gate.

### 4.2 Repository structure

Own git repo, GitHub `devsecops-pipeline`, default branch `main`. Layout follows the
established sibling conventions (small testable core + `tests/` + maintained `docs/` + CI that
proves the claims live).

```
devsecops-pipeline/
├── README.md  CLAUDE.md  CHANGELOG.md  plan.md  DISCLAIMER.md  LICENSE
├── app/                      # fresh minimal Flask service (secure on main)
│   ├── __init__.py  db.py  requirements.txt  Dockerfile
│   └── README.md             # what the service does; why the base image is pinned slim
├── infra/                    # GCP Terraform — SCAN-ONLY, never applied
│   ├── main.tf  variables.tf
│   └── README.md             # clean baseline; the failing branch plants misconfigs here
├── policy/                   # OPA/Rego policy-as-code (the gate)
│   ├── severity.rego         # deny results with severity ≥ threshold unless excepted
│   ├── exceptions.rego       # exception lookup: match by rule-id/fingerprint + expiry check
│   ├── data/exceptions.yaml  # the exception allowlist (rule-id, reason, owner, expires)
│   └── severity_test.rego  exceptions_test.rego   # opa test unit tests
├── fixtures/                 # committed scanner SARIF for offline gate tests
│   ├── clean/                #   → conftest passes
│   └── failing/              #   → conftest denies (one per gate)
├── scripts/                  # tiny glue: normalise any non-SARIF tool output to SARIF
├── tests/                    # pytest: app smoke + (optional) normaliser tests
├── .pre-commit-config.yaml   # gitleaks + semgrep local hooks (shift-left)
├── .github/workflows/
│   └── security.yml          # the pipeline: scanners → conftest gate + SBOM artifact
└── docs/
    ├── POLICY.md             # severity thresholds + exception request/approval workflow
    ├── DECISIONS.md          # ADRs
    ├── RUNBOOK.md            # how to run gates locally on Linux
    └── superpowers/specs/2026-06-30-devsecops-pipeline-design.md   # this file
```

### 4.3 Safety & cost invariants

- **No cloud spend by default.** The `infra/` Terraform is *only ever scanned statically*
  (Checkov / tfsec / Trivy config). `terraform apply` is never run in v1; there is no GCP project,
  no service account, and no billable resource. This is the primary cost guard.
- **Cost-safety if a stretch ever provisions GCP.** Should an optional future stretch add a live
  deploy demo, it must: set a billing budget + alert first, tear the resources down immediately
  after capturing evidence, and **delete the GCP project at session end** — mirroring project
  01's GCP-demo discipline. Document every created/destroyed resource in-repo.
- **The vulnerable artifacts are never deployed.** The `demo/failing-gates` branch's planted
  vulns (SQLi route, vulnerable dep, fake secret, outdated base image, misconfigured Terraform)
  exist to make gates fire in CI; the app is run only ephemerally in CI if needed and torn down
  with the job.
- **Secrets discipline.** The planted "secret" is an obvious fake (AWS-key-shaped placeholder,
  never a real credential). Gitleaks must flag it; no real secret ever enters the repo. `.env*`
  is git-ignored.
- **Linux lab.** All tools (Trivy, conftest, opa, syft, gitleaks, checkov, semgrep, docker) run
  natively on Linux; standing commands in `CLAUDE.md` are Linux-first.

## 5. Sample app & planted findings

`app/` is a small, intentionally secure containerised Flask service (a couple of routes + a tiny
SQLite layer + a `Dockerfile`). On `main` it passes every gate. The evidence comes from a tracked
`demo/failing-gates` branch that re-introduces **exactly one finding per gate**, so each gate has a
concrete, reproducible reason to fire — and the before/after diff is the learning artifact.

| Gate | Planted finding on `demo/failing-gates` | Detected by | Maps to |
|------|------------------------------------------|-------------|---------|
| SAST | SQL injection via f-string query + reflected XSS (unescaped render) | Semgrep | CWE-89 / CWE-79 |
| SCA | A pinned vulnerable dependency (e.g. `flask==0.12.2`) in `requirements.txt` | Trivy fs | known CVE |
| Secrets | A fake AWS-key-shaped string committed to source | Gitleaks | CWE-798 |
| Container | `FROM python:3.9` (EOL, CVE-laden) replacing the pinned `python:3.12-slim` base | Trivy image | CWE-1104 |
| IaC | Public GCS bucket (no UBLA) + a `0.0.0.0/0` firewall ingress in `infra/` | Checkov / tfsec | CIS GCP |

The secure baseline on `main`: parameterized queries, Jinja autoescape on, secret from env,
patched dependency pins, a pinned minimal slim base image, and `infra/` with uniform bucket-level
access + a scoped firewall. The `git diff` between `main` and `demo/failing-gates` is the
"one documented vulnerability and its verified remediation" required by the README — five times
over, one per gate.

## 6. The security gates & CI

One workflow (`.github/workflows/security.yml`). Each gate runs the real scanner, writes SARIF,
and the SARIF flows into the single `conftest` policy gate (§7). The pipeline both *demonstrates*
detection (it flags the failing branch) and *proves cleanliness* (it is green on `main`).

| Stage | Tool | Runs against | Emits | Pass condition |
|-------|------|--------------|-------|----------------|
| Lint/test | ruff + pytest | repo + `app/` | — | green |
| Policy unit tests | `opa test policy/` | Rego policy | — | all Rego tests pass |
| SAST | Semgrep | `app/` source | `semgrep.sarif` | no HIGH+ unexcepted |
| SCA | Trivy fs | `requirements.txt` / lockfile | `trivy-fs.sarif` | no HIGH+ unexcepted |
| Secrets | Gitleaks | full repo + history | `gitleaks.sarif` | no leak unexcepted |
| Container | Trivy image | built image | `trivy-image.sarif` | no HIGH+ unexcepted |
| IaC | Checkov (+ tfsec) | `infra/` Terraform | `checkov.sarif` | no HIGH+ unexcepted |
| SBOM | Syft | built image / `app/` | `sbom.cyclonedx.json` | artifact uploaded |
| **Gate** | **conftest** | all `*.sarif` + `policy/` | verdict | **deny ⇒ exit≠0 ⇒ merge blocked** |

**The gate is the README's "Definition of done" as code.** A required status check on the
`conftest` job means a PR cannot merge while any HIGH+ finding lacks a valid exception. Committed
SARIF in `fixtures/` lets the policy be tested offline with no scanners installed; the live stages
regenerate that truth in CI and prove real detection.

## 7. Policy-as-code: OPA/Rego + the exception process

The spine. `conftest` evaluates the Rego under `policy/` against the combined SARIF.

**Decision rule (`severity.rego`).** `deny` any SARIF result whose severity is ≥ the configured
threshold (default **HIGH**) **unless** it is covered by a valid exception. Severity is read from
the SARIF result (`level` / rule properties / `security-severity`), normalised to a common scale.

**Exceptions (`exceptions.rego` + `data/exceptions.yaml`).** An exception entry is keyed by rule
id (and optionally a finding fingerprint/path) and carries a `reason`, an `owner`, and an
`expires:` date. An exception suppresses a finding **only if** it matches **and** `expires` is in
the future. Expired or missing → the finding is denied. Example:

```yaml
# policy/data/exceptions.yaml
exceptions:
  - rule: "python.flask.security.xss.audit"   # SARIF ruleId
    reason: "False positive — value is constant, not user input"
    owner: "milad"
    expires: "2026-09-30"
```

**Why this satisfies the README.** "A documented severity threshold + exception process" is not a
paragraph — it is executable Rego with unit tests and an auditable, dated allowlist. `docs/POLICY.md`
is the human-readable mirror: the threshold, how to request an exception, who approves, and that
exceptions expire and must be renewed.

**Rego unit tests (`opa test policy/`).** The deterministic, offline-tested core:
- a HIGH finding with no exception → denied;
- a LOW/MEDIUM finding → allowed (below threshold);
- a HIGH finding with a valid, unexpired exception → suppressed;
- a HIGH finding with an **expired** exception → still denied;
- threshold boundary (exactly-HIGH denied, just-below allowed).

## 8. SBOM

Every build generates a Software Bill of Materials with **Syft** in **CycloneDX** JSON, uploaded
as a GitHub Actions artifact (`sbom.cyclonedx.json`). It is supply-chain evidence: a complete,
versioned inventory of the image's packages. As a stretch, **Grype** re-scans the SBOM and feeds
its SARIF into the same `conftest` gate, turning the SBOM into an additional enforcing surface.
The SBOM is intentionally *not* a blocking gate in v1 — it is an artifact, keeping v1's gate count
clean at five.

## 9. Evidence (the headline deliverable)

Three artifacts, all screenshot-captured into `docs/` (or the README), demonstrate the pipeline:

1. **Green `main`.** Clean app + clean Terraform → every gate passes, `conftest` allows, pipeline
   green.
2. **Blocked `demo/failing-gates` PR.** One planted finding per gate → each scanner flags it →
   `conftest` denies → the required status check fails → **merge blocked**. The PR checks page is
   the money shot.
3. **Exception demo.** Add a dated entry to `exceptions.yaml` for one of the failing findings →
   that finding is suppressed and its gate clears, while the other four still block. Proves the
   exception process actually works and is scoped (it clears one finding, not the whole gate).

Each is reproducible from the repo with no external dependencies beyond the public scanners.

## 10. Testing & CI-green guarantee

Layered so the policy decision is provable offline and the scanners are proven live:

- **`opa test policy/`** — Rego unit tests for the policy logic (§7). The deterministic spine.
- **`conftest` over committed fixtures** — `fixtures/clean/*.sarif` → passes; `fixtures/failing/*.sarif`
  → denies. Runs with no scanners installed, no network, no Docker. This is the offline analogue of
  project 04's `verify` gate.
- **`pytest`** — `app/` smoke test (the service boots, routes respond) + any `scripts/` SARIF
  normaliser unit tests.
- **`ruff`** — lint the Python.
- **Live scanners in CI** — Semgrep / Trivy / Gitleaks / Checkov / Syft run against the real app
  and Terraform to regenerate truth and prove real detection (not just fixture replay).

CI fails if a planted finding stops being detected, if `main` regresses to flagged, or if the
policy logic breaks — so the security claims cannot silently rot.

## 11. Build milestones (bottom-up; each milestone commits + ships green)

| M | Milestone | Needs live tooling? |
|---|-----------|---------------------|
| M0 | Repo scaffold: git + GitHub remote, `CLAUDE.md`/docs skeleton, `DISCLAIMER.md`, `.gitignore`, CI shell | No (Linux box) |
| M1 | `app/` — minimal secure Flask service + `Dockerfile` + smoke test; basic CI build green | Docker |
| M2 | Policy spine — `policy/*.rego` + `data/exceptions.yaml` + `opa test` + `conftest` over committed `fixtures/clean` & `fixtures/failing`. Gate works **before** any live scanner | opa/conftest |
| M3 | Gates wired — Semgrep, Trivy fs, Gitleaks, Trivy image, Checkov → SARIF → conftest; plant `demo/failing-gates`; prove each gate fires | scanners |
| M4 | SBOM + IaC — Syft CycloneDX artifact; GCP Terraform (clean baseline) + Checkov; failing-branch IaC misconfig | syft/checkov |
| M5 | Policy docs + exception workflow (`docs/POLICY.md`) + evidence: green-main / blocked-PR / exception-suppresses-one screenshots | — |
| M6 *(stretch)* | DAST (ZAP) gate; Grype-the-SBOM gate; SARIF upload to GitHub code-scanning; cosign image signing; pre-commit polish | — |

M2 deliberately precedes the live scanners: the policy gate is validated against committed SARIF
fixtures first, so the project has a working, tested decision point before any scanner is wired —
mirroring the sibling pattern of an offline-testable core that CI later proves live.

## 12. Conventions, docs discipline & git workflow

- **Own repo, own GitHub remote** (`devsecops-pipeline`), default branch `main`; work on
  feature branches, never push to `main` directly.
- **Commit + push every task** — small, single-purpose, conventional messages
  (`feat`/`fix`/`refactor`/`chore`/`docs`/`test`). No `--no-verify`; no `Co-Authored-By` trailer;
  no `--author`.
- **Verification gate before every commit:** `ruff check .`, `pytest -q`, and `opa test policy/`
  green.
- **Maintained-docs discipline:** docs updated **in the same commit** as the code they describe —
  `README.md`, `CHANGELOG.md`, `plan.md`, `docs/POLICY.md`, `docs/DECISIONS.md` (ADRs),
  `docs/RUNBOOK.md`, and the `app/` / `infra/` READMEs. A task is not done until its doc is current.
- **Linux-first standing commands** in `CLAUDE.md` (the lab is Linux).
- `.gitignore` includes the global baseline (`node_modules/`, `.env*`, `dist/`, `build/`,
  `.DS_Store`, `.venv/`, Terraform state `*.tfstate*`, `.terraform/`); `CLAUDE.md` and `docs/`
  **are committed**.
- `DISCLAIMER.md` states authorized/local-only, scan-only, no-cloud-spend use.

## 13. Definition of done

- [ ] Public repo with a green pipeline on `main` **and** a `demo/failing-gates` branch that is
      blocked from merging, both screenshotted.
- [ ] ≥4 distinct security gates wired and enforcing — delivered as **5** (SAST, SCA, secrets,
      container, IaC), each blocking on HIGH+ via the policy gate.
- [ ] An SBOM artifact (`sbom.cyclonedx.json`) produced per build.
- [ ] Policy-as-code: `policy/*.rego` evaluated by `conftest`, with `opa test` unit tests and a
      dated, auditable `exceptions.yaml`; `docs/POLICY.md` explains the threshold + exception
      process; the exception demo clears exactly one finding.
- [ ] `README.md` explaining each gate, its tool, and why it matters in the SDLC, plus a short
      "shift-left" rationale section.
- [ ] Offline-testable core: `opa test` + `conftest` over committed SARIF fixtures green with no
      scanners installed.
- [ ] Clear ethical/scope + cost-safety statement (`DISCLAIMER.md`); no `terraform apply`, no
      cloud spend.

**In one line:** built a DevSecOps GitHub Actions pipeline with SAST, SCA, secrets, container, and
IaC scanning gates plus SBOM generation, unified by an OPA/Rego policy-as-code gate (with a
tested, dated exception process) that blocks merges on high-severity findings — demonstrated by a
green clean branch and a blocked planted-vuln branch.

## 14. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Not all tools emit SARIF natively (e.g. pip-audit) | Lead with SARIF-native tools (Trivy, Semgrep, Gitleaks, Checkov); a tiny `scripts/` normaliser converts any non-SARIF output; unit-tested |
| Rego/OPA is a new language for the owner | Policy is small and fully specified; `opa test` gives tight feedback; `docs/POLICY.md` mirrors it in prose |
| CI flakiness from live scanners / image builds | Authoritative signal is the fixture-driven `conftest` + `opa test` (offline, deterministic); live scanners are proof, not the gate of record |
| Accidental cloud spend | Terraform is scan-only, never applied; no GCP project in v1; budget+teardown discipline if any stretch ever provisions (see §4.3) |
| Scope overlap with project 04 | Spec limits SAST to the shared surface; this project's value is the gate/policy/supply-chain dimension — no pentest, no manual report |
| Exposing the vulnerable failing branch | Planted vulns exist only to make gates fire in CI; app never deployed; ephemeral CI containers torn down with the job |

## 15. Future / stretch (explicitly out of v1 scope)

- DAST: OWASP ZAP baseline against the running container as a 6th gate.
- Grype re-scans the SBOM and feeds SARIF into the same policy gate.
- SARIF upload to GitHub code-scanning so findings surface in the Security tab.
- Supply-chain signing: cosign sign the image + provenance/attestation.
- A live GCP deploy demo (with strict budget + teardown per §4.3) to show runtime + IaC parity.
- Pre-commit hardening: full gitleaks + semgrep local hooks documented in the README.

## 16. Open questions

None — Q1–Q4 and sub-decisions (a)–(d) are resolved (see §3).
