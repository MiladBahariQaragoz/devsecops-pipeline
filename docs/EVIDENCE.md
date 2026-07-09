# Evidence — the gates work

This page collects the proof that the pipeline does what it claims: green on a clean
`main`, merge-blocked on a planted-vuln branch, and able to suppress exactly one finding
through the dated exception process. Every item links to a real CI run and/or a command
you can re-run yourself — the CI run URLs are the canonical, reproducible evidence.

> The pipeline has four enforcing gates (SAST, SCA, secrets, container) unified by the
> OPA/Rego policy gate, plus a per-build SBOM. See [`POLICY.md`](POLICY.md) for the policy
> and [`../plan.md`](../plan.md) for scope.

## 1. Green on `main`

A clean `main` passes all four CI jobs — the app is secure, its dependencies and image
carry no unexcepted HIGH+ CVE, and no secret is committed.

- **Run:** <https://github.com/MiladBahariQaragoz/devsecops-pipeline/actions/runs/29040110177>
  (commit `16b7a62`)
- **Jobs:** `Lint and test` ✅ · `OPA policy unit tests` ✅ · `conftest gate (offline fixtures)` ✅ · `Security gates (live scanners → conftest)` ✅
- **Artifacts:** `sarif` (all four scanners' output) and `sbom` (CycloneDX, ~2.7k components).

The live `security-gates` job runs the four real scanners, each emits SARIF, and the single
`conftest` step finds nothing to deny — so the job is green and the merge is allowed.

## 2. Merge-blocked on `demo/failing-gates`

The [`demo/failing-gates`](https://github.com/MiladBahariQaragoz/devsecops-pipeline/pull/13)
branch (PR #13, kept open, **never merged**) plants one issue per gate to prove each one
fires and blocks the merge:

| Gate | Planted issue | Detected as |
|------|---------------|-------------|
| SAST (Semgrep) | f-string SQL query + `render_template_string` XSS in a `/search` route | `tainted-sql-string` (HIGH) |
| SCA (Trivy fs) | `requests==2.19.1` pinned in `requirements.txt` | `CVE-2018-18074` (HIGH) |
| Secrets (Gitleaks) | fake AWS key pair in `app/config_fake.py` | `aws-access-token`, `generic-api-key` (HIGH) |
| Container (Trivy image) | `FROM python:3.9` (EOL base) | many HIGH/CRITICAL CVEs |

- **Run:** <https://github.com/MiladBahariQaragoz/devsecops-pipeline/actions/runs/29038190696>
- The three offline jobs stay **green**; only `Security gates (live scanners → conftest)`
  **fails**, and it fails specifically at the *Policy gate — conftest over live SARIF* step,
  not at any scanner (each scanner runs non-failing). Excerpt:

  ```
  FAIL - sarif/gitleaks.sarif   - main - gitleaks: aws-access-token (severity=HIGH) has no valid, unexpired exception
  FAIL - sarif/semgrep.sarif    - main - Semgrep OSS: ...tainted-sql-string (severity=HIGH) has no valid, unexpired exception
  FAIL - sarif/trivy-fs.sarif   - main - Trivy: CVE-2018-18074 (severity=HIGH) has no valid, unexpired exception
  FAIL - sarif/trivy-image.sarif- main - Trivy: CVE-2025-14087 (severity=CRITICAL) has no valid, unexpired exception
  ...
  ```

  All four gates fire from a single enforcement point — exactly the design in ADR-011.

## 3. An exception suppresses exactly one finding

The dated exception process suppresses **one specific finding** without disabling the gate.
This is reproducible offline against the committed failing fixtures — no scanners needed:

```bash
BIN=/home/sudo/.venvs/devsecops-pipeline/bin   # or your conftest on PATH

# BEFORE — no exceptions: every planted fixture finding denies.
$BIN/conftest test --policy policy --data data --parser json fixtures/failing/*.sarif
# → 7 tests, 0 passed, 7 failures   (includes ...xss.audit HIGH)

# Add ONE scoped exception for the XSS finding, then re-run.
cat > data/exceptions.yaml <<'YAML'
exceptions:
  - rule: "python.flask.security.xss.audit"
    reason: "False positive — value is constant, not user input"
    owner: "milad"
    expires: "2026-09-30"
YAML
$BIN/conftest test --policy policy --data data --parser json fixtures/failing/*.sarif
# → 6 tests, 0 passed, 6 failures   (the XSS denial is gone; the other 6 still deny)
```

The count drops from **7 → 6** and only the excepted `xss.audit` finding disappears — every
other gate still blocks. An `expires` date in the past (or a missing/malformed one) is
treated as expired and the finding denies again, so exceptions cannot silently live forever
(see [`POLICY.md`](POLICY.md) → *Renewal and expiry*).

## Branch protection (one-time repo setting)

CI blocking a PR check is what stops a merge in practice. To make it enforced rather than
advisory, mark **`Security gates (live scanners → conftest)`** (and the two offline policy
jobs) as **required status checks** on `main` in the repository's branch-protection
settings. This is a GitHub UI setting, not code — do it once on the repo.

## Screenshots (optional)

The CI run URLs above are the canonical evidence and stay reproducible. For a portfolio
README you may also attach PNGs of the green `main` run, the red `demo/failing-gates` PR
check, and the before/after exception diff; drop them in `docs/img/` and link them here.
