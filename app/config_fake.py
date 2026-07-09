"""DEMO/FAILING-GATES ONLY — planted fake credentials to make the Gitleaks gate fire.

These are NOT real credentials — an obviously fake, AWS-key-shaped placeholder committed
on this branch only so the secrets gate has something to detect. No real secret ever
enters the repo; on main, secrets come from the environment (see app/__init__.py).
"""

# Fake AWS credentials — AWS-key-SHAPED but not a live key. Deliberately not one of
# AWS's published "EXAMPLE" doc keys (gitleaks allowlists those), so the gate fires.
AWS_ACCESS_KEY_ID = "AKIAQYLPMN5HJ3QXV7GT"  # noqa: S105 — planted fake for Gitleaks demo
AWS_SECRET_ACCESS_KEY = "5rBkT9wZ2xQ8vN1cLpH7yUeD4aFgJ6sMoR0iXbP"  # noqa: S105 — planted fake
