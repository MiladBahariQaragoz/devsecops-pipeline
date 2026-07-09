package main

import rego.v1

default severity_threshold := "HIGH"

severity_rank := {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}

# result_severity resolves a normalized severity for a SARIF result, in
# priority order:
#   1. result.properties["security-severity"]   (numeric CVSS-style score)
#   2. the matching rule's properties["security-severity"] (rule-level score)
#   3. SARIF result `level` (error/warning/note/none)
#   4. the matching rule's defaultConfiguration.level (SARIF: a result inherits its
#      rule's configured level when result.level is omitted — Semgrep and others emit
#      the level once on the rule, not on every result)
#   5. HIGH, for Gitleaks findings (secrets carry no severity in SARIF but a committed
#      secret is categorically high-severity)
#   6. MEDIUM, if nothing above is present
result_severity(run, result) := sev if {
	sev := security_severity_field(result.properties)
} else := sev if {
	some rule in run.tool.driver.rules
	rule.id == result.ruleId
	sev := security_severity_field(rule.properties)
} else := sev if {
	sev := level_to_severity(result.level)
} else := sev if {
	some rule in run.tool.driver.rules
	rule.id == result.ruleId
	sev := level_to_severity(rule.defaultConfiguration.level)
} else := "HIGH" if {
	lower(object.get(run, ["tool", "driver", "name"], "")) == "gitleaks"
} else := "MEDIUM"

# security_severity_field resolves the normalized severity from a
# "security-severity" property value on either a result or a rule object,
# distinguishing three states:
#   - key absent (properties has no security-severity, or properties itself
#     is missing entirely): undefined, so callers fall through to the next
#     priority tier (rule-level, then `level`, then MEDIUM).
#   - key present but not a parseable number (e.g. corrupted-in-transit
#     garbage like "9.8-CORRUPTED"): CRITICAL. Fail closed — a malformed
#     authoritative score must not silently fall through to a coarser,
#     lower-priority signal (SARIF `level` is often set independently of the
#     true CVSS score by real scanners), same philosophy as exceptions.rego's
#     `expired()` handling of calendar-invalid dates.
#   - key present and a parseable number: bucketed via severity_bucket
#     (existing behavior, unchanged).
security_severity_field(properties) := sev if {
	raw := object.get(properties, "security-severity", null)
	raw != null
	sev := severity_bucket(to_number(raw))
} else := "CRITICAL" if {
	raw := object.get(properties, "security-severity", null)
	raw != null
}

# severity_bucket maps a CVSS-style 0.0-10.0 score onto the common scale,
# using the CVSS v3.1 Qualitative Severity Rating Scale cutoffs.
severity_bucket(score) := "CRITICAL" if score >= 9.0

severity_bucket(score) := "HIGH" if {
	score >= 7.0
	score < 9.0
}

severity_bucket(score) := "MEDIUM" if {
	score >= 4.0
	score < 7.0
}

severity_bucket(score) := "LOW" if score < 4.0

level_to_severity(level) := "HIGH" if level == "error"
level_to_severity(level) := "MEDIUM" if level == "warning"
level_to_severity(level) := "LOW" if level == "note"
level_to_severity(level) := "LOW" if level == "none"

# deny denies any SARIF result whose normalized severity is at or above
# severity_threshold and which has no valid, unexpired exception.
deny contains msg if {
	some run in input.runs
	some result in run.results
	sev := result_severity(run, result)
	severity_rank[sev] >= severity_rank[severity_threshold]
	not is_excepted(result)

	# tool_name/rule_id are cosmetic, message-only identifiers. They must
	# never gate the denial itself: if a run/result is missing these fields,
	# the finding still needs to be denied on its merits (severity +
	# exception status, already established above). Using object.get with
	# safe defaults here — instead of an unguarded run.tool.driver.name /
	# result.ruleId reference — prevents an unrelated formatting field from
	# making the entire rule body (and thus a real denial) silently vanish.
	tool_name := object.get(run, ["tool", "driver", "name"], "unknown-tool")
	rule_id := object.get(result, "ruleId", "unknown-rule")
	msg := sprintf(
		"%s: %s (severity=%s) has no valid, unexpired exception",
		[tool_name, rule_id, sev],
	)
}
