package main

import rego.v1

default severity_threshold := "HIGH"

severity_rank := {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}

# result_severity resolves a normalized severity for a SARIF result, in
# priority order:
#   1. result.properties["security-severity"]   (numeric CVSS-style score)
#   2. the matching rule's properties["security-severity"] (rule-level score)
#   3. SARIF `level` (error/warning/note/none)
#   4. MEDIUM, if nothing above is present
result_severity(run, result) := sev if {
	raw := result.properties["security-severity"]
	sev := severity_bucket(to_number(raw))
} else := sev if {
	some rule in run.tool.driver.rules
	rule.id == result.ruleId
	raw := rule.properties["security-severity"]
	sev := severity_bucket(to_number(raw))
} else := sev if {
	sev := level_to_severity(result.level)
} else := "MEDIUM"

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
	msg := sprintf(
		"%s: %s (severity=%s) has no valid, unexpired exception",
		[run.tool.driver.name, result.ruleId, sev],
	)
}
