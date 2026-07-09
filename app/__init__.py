"""Minimal secure Flask service.

Security properties (maintained on main):
- SECRET_KEY read from environment — never hardcoded.
- Jinja2 autoescape is ON by default for .html templates (Flask default).
- JSON responses via jsonify are not subject to XSS.
- SQLite queries in db.py use parameterized placeholders.
"""

import os

from flask import Flask, jsonify, render_template_string, request

from .db import add_item, get_connection, get_items, init_db


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
    # Use an explicit RuntimeError rather than assert: assert statements are stripped
    # when Python runs with -O / PYTHONOPTIMIZE, silently removing the security check.
    if not app.jinja_env.autoescape("template.html"):
        raise RuntimeError(
            "Jinja2 autoescape is disabled for HTML templates. "
            "This is a security invariant violation — do not disable autoescape."
        )

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

    @app.get("/search")
    def search():
        """DEMO/FAILING-GATES: SQL injection via f-string (CWE-89) + reflected XSS
        (CWE-79) so the Semgrep SAST gate fires at ERROR
        (python.flask.security.injection.tainted-sql-string).

        The user-controlled ``q`` is interpolated straight into the SQL string and
        rendered as an unescaped template — intentional planted vulnerabilities on this
        branch only. On main, queries are parameterized and HTML is autoescaped.
        """
        q = request.args.get("q", "")
        with get_connection() as conn:
            rows = conn.execute(
                f"SELECT id, name FROM items WHERE name = '{q}'"  # noqa: S608 — planted SQLi for SAST demo
            ).fetchall()
        found = str([dict(r) for r in rows])
        body = "<h1>Results for " + q + "</h1><p>" + found + "</p>"
        return render_template_string(body)

    return app
