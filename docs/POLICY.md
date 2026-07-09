# Security Policy

This document describes the severity threshold used by the OPA/Rego policy gate
(`conftest`, evaluating `policy/*.rego`) and the process for requesting,
approving, and expiring finding exceptions. The policy itself is executable —
this page is its human-readable mirror. If this document and the Rego ever
disagree, the Rego is the bug; fix the code to match this policy statement.

## Severity threshold

The gate denies any SARIF result whose normalized severity is **HIGH or
above** (`policy/severity.rego`, `severity_threshold`). CRITICAL and HIGH
findings block the merge; MEDIUM and LOW findings are reported but do not
block.

| Severity | Blocks merge? |
|----------|---------------|
| CRITICAL | Yes |
| HIGH     | Yes (default threshold) |
| MEDIUM   | No |
| LOW      | No |

### How severity is resolved from a SARIF result

SARIF has no single universal severity field — different scanners use
different conventions. The policy resolves severity in this priority order,
stopping at the first source that is present:

1. **`result.properties["security-severity"]`** — a numeric CVSS-style score
   (0.0–10.0) set directly on the finding.
2. **The matching rule's `properties["security-severity"]`** — the same kind
   of score, declared once on the rule (`tool.driver.rules[]`) instead of
   repeated on every result. This is the convention Trivy uses.
3. **SARIF `level`** — `error` → HIGH, `warning` → MEDIUM, `note`/`none` → LOW.
   Gitleaks and many Checkov checks set only `level`, with no CVSS score.
4. **MEDIUM**, if none of the above is present — fail toward visibility, not
   toward a silent pass.

Numeric scores are bucketed using the CVSS v3.1 Qualitative Severity Rating
Scale:

| Score range | Bucket |
|-------------|--------|
| 9.0 – 10.0  | CRITICAL |
| 7.0 – 8.9   | HIGH |
| 4.0 – 6.9   | MEDIUM |
| 0.0 – 3.9   | LOW |

## Exception process

An exception suppresses **one specific finding** — it never disables a whole
gate. Exceptions live in `data/exceptions.yaml`, are reviewed like any other
code change (via pull request), and expire automatically.

### Schema

```yaml
exceptions:
  - rule: "python.flask.security.xss.audit"   # required — the SARIF ruleId
    reason: "False positive — value is constant, not user input"  # required
    owner: "milad"                             # required — who requested it
    expires: "2026-09-30"                      # required — "YYYY-MM-DD"
    # path: "app/templates/item.html"          # optional — scope to one location
```

- **`rule`** must exactly match the SARIF `ruleId` of the finding being
  excepted.
- **`path`** (optional) scopes the exception to results whose location URI
  ends with the given path. Omit it to except the rule id everywhere in the
  repo — use that sparingly; a scoped exception is safer than a blanket one.
- **`expires`** is mandatory. A missing or malformed `expires` value is
  treated as an *expired* exception — the finding stays denied. This is a
  fail-closed design: a typo in the date must never accidentally grant a
  permanent pass.

### Requesting an exception

1. Open a pull request that adds an entry to `data/exceptions.yaml`, in the
   same PR as (or a prompt follow-up to) the change that triggered the
   finding.
2. State the `reason` honestly — a "false positive" claim should say *why*
   (e.g. "value is a constant, not user input"), not just assert it.
3. Set a real `expires` date — 90 days out is a reasonable default for this
   solo project; shorter for anything uncertain.
4. Get the PR reviewed and merged. For this solo learning project, the PR
   review *is* the approval step; in a team setting, a designated approver
   (e.g. a security lead) would review exception PRs specifically.

### Renewal and expiry

When an exception's `expires` date passes, `policy/exceptions.rego` stops
suppressing the finding and the gate denies it again on the next run. To
renew, open a new PR bumping `expires` — this forces a fresh look at whether
the exception is still justified, rather than exceptions silently living
forever.

## Scope

The `opa-policy-tests` and `conftest-fixtures` CI jobs
(`.github/workflows/security.yml`) run on every push and pull request, and are
green as of M2. Making the live per-gate `conftest` job (wired in M3) a
**required status check** on `main`'s branch protection is a one-time GitHub
repository setting — tracked as M5 evidence work, not part of this plan.
