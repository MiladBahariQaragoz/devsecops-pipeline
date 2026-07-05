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
