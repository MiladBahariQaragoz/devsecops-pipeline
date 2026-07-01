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

# Copy application source.
COPY __init__.py db.py ./

# Drop to non-root for the runtime process.
USER appuser

# Flask dev server on 5000. Production would use gunicorn.
ENV FLASK_APP=__init__.py
EXPOSE 5000

CMD ["python", "-m", "flask", "run", "--host=0.0.0.0"]
