package main

import rego.v1

test_valid_unexpired_exception_suppresses_finding if {
	exceptions := [{
		"rule": "test.rule.id",
		"reason": "test",
		"owner": "tester",
		"expires": "2099-01-01",
	}]
	result := {"ruleId": "test.rule.id", "locations": []}
	is_excepted(result) with data.exceptions as exceptions
}

test_expired_exception_still_denies if {
	exceptions := [{
		"rule": "test.rule.id",
		"reason": "test",
		"owner": "tester",
		"expires": "2020-01-01",
	}]
	result := {"ruleId": "test.rule.id", "locations": []}
	not is_excepted(result) with data.exceptions as exceptions
}

test_missing_expires_field_denies if {
	exceptions := [{
		"rule": "test.rule.id",
		"reason": "test",
		"owner": "tester",
	}]
	result := {"ruleId": "test.rule.id", "locations": []}
	not is_excepted(result) with data.exceptions as exceptions
}

test_malformed_expires_denies if {
	exceptions := [{
		"rule": "test.rule.id",
		"reason": "test",
		"owner": "tester",
		"expires": "not-a-date",
	}]
	result := {"ruleId": "test.rule.id", "locations": []}
	not is_excepted(result) with data.exceptions as exceptions
}

test_wrong_rule_id_not_excepted if {
	exceptions := [{
		"rule": "some.other.rule",
		"reason": "test",
		"owner": "tester",
		"expires": "2099-01-01",
	}]
	result := {"ruleId": "test.rule.id", "locations": []}
	not is_excepted(result) with data.exceptions as exceptions
}

test_path_scoped_exception_matches_correct_path if {
	exceptions := [{
		"rule": "test.rule.id",
		"reason": "test",
		"owner": "tester",
		"expires": "2099-01-01",
		"path": "app/db.py",
	}]
	result := {
		"ruleId": "test.rule.id",
		"locations": [{"physicalLocation": {"artifactLocation": {"uri": "app/db.py"}}}],
	}
	is_excepted(result) with data.exceptions as exceptions
}

test_path_scoped_exception_does_not_match_other_path if {
	exceptions := [{
		"rule": "test.rule.id",
		"reason": "test",
		"owner": "tester",
		"expires": "2099-01-01",
		"path": "app/db.py",
	}]
	result := {
		"ruleId": "test.rule.id",
		"locations": [{"physicalLocation": {"artifactLocation": {"uri": "app/other.py"}}}],
	}
	not is_excepted(result) with data.exceptions as exceptions
}

test_exception_without_path_applies_repo_wide if {
	exceptions := [{
		"rule": "test.rule.id",
		"reason": "test",
		"owner": "tester",
		"expires": "2099-01-01",
	}]
	result := {
		"ruleId": "test.rule.id",
		"locations": [{"physicalLocation": {"artifactLocation": {"uri": "anywhere/at/all.py"}}}],
	}
	is_excepted(result) with data.exceptions as exceptions
}
