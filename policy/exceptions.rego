package main

import rego.v1

# is_excepted returns true if `result` (a single SARIF result object) is
# covered by a valid, unexpired exception in data.exceptions.
is_excepted(result) if {
	some exc in data.exceptions
	exc.rule == result.ruleId
	not expired(exc)
	path_matches(exc, result)
}

# expired is true whenever an exception must NOT suppress a finding: missing
# expires, malformed expires, or the expires date has passed. Fail closed —
# any doubt about validity means the finding stays denied.
expired(exc) if {
	not exc.expires
}

expired(exc) if {
	exc.expires
	not valid_date_format(exc.expires)
}

expired(exc) if {
	exc.expires
	valid_date_format(exc.expires)
	expiry_ns := time.parse_rfc3339_ns(sprintf("%sT23:59:59Z", [exc.expires]))
	time.now_ns() > expiry_ns
}

# Regex-shaped but calendar-invalid dates (e.g. "2025-02-30", "2025-13-01")
# make time.parse_rfc3339_ns return undefined rather than erroring, which
# would otherwise leave expired(exc) undefined too — and "not expired(exc)"
# on an undefined term succeeds, silently making the exception permanent.
# Treat that case as expired to keep the fail-closed guarantee.
expired(exc) if {
	exc.expires
	valid_date_format(exc.expires)
	not time.parse_rfc3339_ns(sprintf("%sT23:59:59Z", [exc.expires]))
}

# valid_date_format guards time.parse_rfc3339_ns against non-YYYY-MM-DD
# strings, which would otherwise raise a hard Rego evaluation error instead
# of a safely-undefined result.
valid_date_format(s) if {
	regex.match(`^[0-9]{4}-[0-9]{2}-[0-9]{2}$`, s)
}

# path_matches: an exception with no `path` field applies repo-wide to any
# result with a matching rule id. An exception WITH a `path` field only
# applies to results whose location URI ends with that path.
path_matches(exc, _) if {
	not exc.path
}

path_matches(exc, result) if {
	exc.path
	some location in result.locations
	uri := location.physicalLocation.artifactLocation.uri
	endswith(uri, exc.path)
}
