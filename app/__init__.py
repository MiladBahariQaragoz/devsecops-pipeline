"""Minimal secure Flask service.

Security properties (maintained on main):
- SECRET_KEY read from environment — never hardcoded.
- Jinja2 autoescape is ON by default for .html templates (Flask default).
- JSON responses via jsonify are not subject to XSS.
- SQLite queries in db.py use parameterized placeholders.
"""

import os

from flask import Flask, jsonify, request

from .db import add_item, get_items, init_db


def create_app(test_config: dict | None = None) -> Flask:
    app = Flask(__name__)

    # Apply test overrides (DATABASE, TESTING, etc.) before init_db() is called.
    if test_config is not None:
        app.config.update(test_config)

    # Secret key MUST come from the environment — never hardcode.
    secret = os.environ.get("FLASK_SECRET_KEY")
    if not secret:
        raise RuntimeError(
            "FLASK_SECRET_KEY environment variable is not set. "
            "Set it before starting the app."
        )
    app.config["SECRET_KEY"] = secret

    # Jinja2 autoescape is ON by default in Flask for .html/.htm/.xml/.xhtml extensions.
    # Call the autoescape policy function to confirm it returns True for HTML templates.
    # (jinja_env.autoescape is Flask's select_jinja_autoescape callable; testing its
    # truthiness would always pass — calling it actually verifies the policy behaviour.)
    assert app.jinja_env.autoescape("template.html")  # noqa: S101 — verifies autoescape policy

    with app.app_context():
        init_db()

    @app.get("/health")
    def health():
        """Liveness probe. Returns 200 with a JSON body."""
        return jsonify({"status": "ok"})

    @app.get("/items")
    def list_items():
        """Return all items as JSON."""
        return jsonify({"items": get_items()})

    @app.post("/items")
    def create_item():
        """Add an item. Expects JSON body: {"name": "..."}."""
        data = request.get_json(silent=True) or {}
        raw_name = data.get("name")
        # Only a non-empty string is a valid name. A JSON null/number/bool must
        # not be coerced into a truthy string (e.g. str(None) == "None").
        name = raw_name.strip() if isinstance(raw_name, str) else ""
        if not name:
            return jsonify({"error": "name is required"}), 400
        item_id = add_item(name)
        return jsonify({"id": item_id, "name": name}), 201

    return app
