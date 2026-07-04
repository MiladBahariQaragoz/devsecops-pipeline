# Pinned to python:3.12-slim — LTS, actively patched.
# The demo/failing-gates branch swaps to python:3.9 (EOL) to make Trivy image fire.
# Keep this on python:3.12-slim on main.
FROM python:3.12-slim

# Create a non-root user and group.
# Running as root is flagged by Trivy and CIS benchmarks.
RUN groupadd --system appgroup && useradd --system --gid appgroup appuser

WORKDIR /app

# Copy and install deps as root (pip needs write access), then drop privileges.
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy application source into a proper package subdirectory.
# Flat-copying __init__.py into /app/ would make it a top-level file with no parent
# package, so `from .db import ...` (a relative import) would fail at startup with
# ImportError. Placing the files under /app/app/ makes `app` a proper Python package,
# and Flask loads it via `FLASK_APP=app` (the directory name).
COPY __init__.py db.py ./app/

# Give the non-root user write access to /app so it can create items.db at runtime.
# Without this chown, /app is root:root 755 and appuser cannot write the SQLite file.
RUN chown -R appuser:appgroup /app

# Drop to non-root for the runtime process.
USER appuser

# Flask dev server on 5000. Production would use gunicorn.
ENV FLASK_APP=app
EXPOSE 5000

# Liveness check against the /health endpoint.
# Container orchestrators (Compose, Kubernetes) use this to detect unhealthy containers.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

CMD ["python", "-m", "flask", "run", "--host=0.0.0.0"]
