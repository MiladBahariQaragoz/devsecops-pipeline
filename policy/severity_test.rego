package main

import rego.v1

test_high_finding_no_exception_is_denied if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{"ruleId": "r1", "level": "error", "locations": []}],
	}]}
	count(deny) > 0 with input as input_doc with data.exceptions as []
}

test_low_finding_is_allowed if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{"ruleId": "r1", "level": "note", "locations": []}],
	}]}
	count(deny) == 0 with input as input_doc with data.exceptions as []
}

test_medium_finding_is_allowed if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{"ruleId": "r1", "level": "warning", "locations": []}],
	}]}
	count(deny) == 0 with input as input_doc with data.exceptions as []
}

test_critical_via_result_security_severity_is_denied if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{
			"ruleId": "r1",
			"locations": [],
			"properties": {"security-severity": "9.5"},
		}],
	}]}
	count(deny) > 0 with input as input_doc with data.exceptions as []
}

test_boundary_exactly_high_is_denied if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{
			"ruleId": "r1",
			"locations": [],
			"properties": {"security-severity": "7.0"},
		}],
	}]}
	count(deny) > 0 with input as input_doc with data.exceptions as []
}

test_boundary_just_below_high_is_allowed if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{
			"ruleId": "r1",
			"locations": [],
			"properties": {"security-severity": "6.9"},
		}],
	}]}
	count(deny) == 0 with input as input_doc with data.exceptions as []
}

test_rule_level_security_severity_fallback if {
	input_doc := {"runs": [{
		"tool": {"driver": {
			"name": "TestTool",
			"rules": [{"id": "r1", "properties": {"security-severity": "8.5"}}],
		}},
		"results": [{"ruleId": "r1", "locations": []}],
	}]}
	count(deny) > 0 with input as input_doc with data.exceptions as []
}

test_missing_level_and_severity_defaults_to_medium_allowed if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{"ruleId": "r1", "locations": []}],
	}]}
	count(deny) == 0 with input as input_doc with data.exceptions as []
}

test_deny_end_to_end_valid_exception_suppresses if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{"ruleId": "r1", "level": "error", "locations": []}],
	}]}
	exceptions := [{
		"rule": "r1",
		"reason": "test",
		"owner": "tester",
		"expires": "2099-01-01",
	}]
	count(deny) == 0 with input as input_doc with data.exceptions as exceptions
}

test_deny_end_to_end_expired_exception_still_denies if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{"ruleId": "r1", "level": "error", "locations": []}],
	}]}
	exceptions := [{
		"rule": "r1",
		"reason": "test",
		"owner": "tester",
		"expires": "2020-01-01",
	}]
	count(deny) > 0 with input as input_doc with data.exceptions as exceptions
}

# Regression (Bug 1): a run whose tool.driver.name is missing must still be
# denied. Before the fix, the unguarded run.tool.driver.name reference in
# msg's sprintf made the whole deny rule body undefined for this finding,
# silently dropping a real denial with zero diagnostic output.
test_missing_tool_driver_name_still_denies if {
	input_doc := {"runs": [{
		"tool": {"driver": {"rules": []}},
		"results": [{"ruleId": "r1", "level": "error", "locations": []}],
	}]}
	count(deny) > 0 with input as input_doc with data.exceptions as []
}

# Regression (Bug 2): a present-but-non-numeric security-severity value must
# fail closed to CRITICAL rather than silently falling through to a coarser,
# lower-priority `level` signal. Before the fix, this input (corrupted
# top-priority score + a "warning" level) evaluated to MEDIUM and was
# allowed through.
test_garbage_security_severity_fails_closed if {
	input_doc := {"runs": [{
		"tool": {"driver": {"name": "TestTool", "rules": []}},
		"results": [{
			"ruleId": "r1",
			"level": "warning",
			"locations": [],
			"properties": {"security-severity": "9.8-CORRUPTED"},
		}],
	}]}
	count(deny) > 0 with input as input_doc with data.exceptions as []
}
