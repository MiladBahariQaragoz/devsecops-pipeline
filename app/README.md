# app — minimal secure Flask service

A tiny Flask service used as the scanning target for the DevSecOps pipeline gates.

## Routes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Liveness probe — returns `{"status": "ok"}` |
| GET | `/items` | List all items (from SQLite) |
| POST | `/items` | Add an item: body `{"name": "..."}` |

## Security baseline (main branch)

| Property | Detail |
|----------|--------|
| SQL injection | Parameterized queries (`?` placeholders) in `db.py` — never f-strings |
| XSS | Jinja2 autoescape ON (Flask default); JSON responses via `jsonify` |
| Secret handling | `FLASK_SECRET_KEY` read from environment — never hardcoded |
| Base image | `python:3.12-slim` — LTS, actively patched, minimal attack surface |
| Container user | Runs as non-root (`appuser`) — not `root` |
| Dependencies | Pinned to patched versions; Trivy fs scans `requirements.txt` |

The `demo/failing-gates` branch re-introduces exactly one finding per gate so each scanner has
a reproducible reason to fire. The diff between `main` and `demo/failing-gates` is the learning
artifact.

## Running locally

```bash
# From repo root:
FLASK_SECRET_KEY=dev .venv/bin/python -m flask --app app run
```

## Building the image

```bash
docker build -t devsecops-app:local app/
docker run -e FLASK_SECRET_KEY=dev -p 5000:5000 devsecops-app:local
```

Do not run the failing-branch image outside of ephemeral CI — it contains deliberately
planted vulnerabilities.
