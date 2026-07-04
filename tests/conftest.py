"""pytest configuration: session-level environment setup.

This file is always loaded by pytest before any test module is collected,
so env vars set here are available to all test files regardless of import order.
"""

import os

# FLASK_SECRET_KEY must be set before `create_app` is imported.
# Placing it here (not in test_app.py) guarantees it is set first,
# even if future test modules import `create_app` before test_app.py is collected.
os.environ.setdefault("FLASK_SECRET_KEY", "test-secret-key-not-for-production")
