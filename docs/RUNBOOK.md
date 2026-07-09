# Runbook — running security gates locally (Linux)

> **Status:** skeleton — filled in M3–M5 as each gate is wired.

## Prerequisites

> **FUSE mount note:** This repo lives on a Google Drive FUSE mount that cannot create
> symlinks. Use the shared off-Drive virtualenv instead of creating one inside the repo.
> See `docs/DECISIONS.md` ADR-005 for the rationale.

```bash
# Bootstrap the shared off-Drive virtualenv (once, e.g. after a machine rebuild).
# It must live OFF the Google Drive mount because venv creates a lib64 -> lib symlink
# that the FUSE driver rejects with EIO.
python3 -m venv /home/sudo/.venvs/devsecops-pipeline

# Install / update deps after changing app/requirements.txt:
/home/sudo/.venvs/devsecops-pipeline/bin/python -m pip install -r app/requirements.txt
/home/sudo/.venvs/devsecops-pipeline/bin/python -m pip install ruff pytest
```

## Lint and test (available from M1)

```bash
/home/sudo/.venvs/devsecops-pipeline/bin/ruff check .
/home/sudo/.venvs/devsecops-pipeline/bin/pytest -q
```

## OPA/conftest gate (M2+)

`opa` and `conftest` install as pinned single binaries (CI installs the same versions,
checksum-verified — see ADR-009). Locally, keep them off the Drive mount:

```bash
BIN=/home/sudo/.venvs/devsecops-pipeline/bin
# opa v1.18.2
curl -sSL -o "$BIN/opa" https://github.com/open-policy-agent/opa/releases/download/v1.18.2/opa_linux_amd64_static
chmod +x "$BIN/opa"
# conftest v0.68.2
curl -sSL -o /tmp/conftest.tgz https://github.com/open-policy-agent/conftest/releases/download/v0.68.2/conftest_0.68.2_Linux_x86_64.tar.gz
tar -xzf /tmp/conftest.tgz -C "$BIN" conftest && chmod +x "$BIN/conftest"

# Policy unit tests + gate over the committed offline fixtures:
"$BIN/opa" test policy/
"$BIN/conftest" test --policy policy --data data --parser json fixtures/clean/*.sarif    # must PASS
"$BIN/conftest" test --policy policy --data data --parser json fixtures/failing/*.sarif   # must DENY (exit 1)
```

## Live scanners (M3+)

Each gate runs its pinned official scanner image and writes SARIF; a single `conftest` run
over all the SARIF is the enforcement point (deny on HIGH+ unexcepted). CI does exactly this
in the `security-gates` job — CI is the authoritative runtime.

> **FUSE caveat:** Docker cannot bind-mount a path under the Google Drive mount (the FUSE
> driver rejects the mount-source `mkdir`). To run the scanners locally, first copy the tree
> to an off-Drive scratch dir and run there. Run scanners with `--user "$(id -u):$(id -g)"`
> so output files are yours (Trivy *image* needs the docker socket and stays root).

```bash
W=$(mktemp -d)                       # off-Drive scratch
cp -r app policy data "$W"/ && mkdir -p "$W/sarif"
U="$(id -u):$(id -g)"

# SAST — Semgrep
docker run --rm --user "$U" -v "$W:/src" -w /src semgrep/semgrep:1.168.0 \
  semgrep --config p/python --sarif --output sarif/semgrep.sarif app/
# SCA — Trivy filesystem
docker run --rm --user "$U" -e TRIVY_CACHE_DIR=/tmp/tc -v "$W:/src" aquasec/trivy:0.72.0 fs \
  --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 0 \
  --format sarif --output /src/sarif/trivy-fs.sarif /src/app/requirements.txt
# Secrets — Gitleaks (drop --no-git to also scan history)
docker run --rm --user "$U" -v "$W:/repo" zricethezav/gitleaks:v8.30.1 detect \
  --source=/repo --no-git --report-format sarif --report-path /repo/sarif/gitleaks.sarif \
  --exit-code 0 --no-banner
# Container — Trivy image (build first; runs as root for docker-socket access)
docker build -t devsecops-app:ci app/
docker run --rm -e TRIVY_CACHE_DIR=/tmp/tc -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$W:/src" aquasec/trivy:0.72.0 image \
  --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 0 \
  --format sarif --output /src/sarif/trivy-image.sarif devsecops-app:ci

# Policy gate over the live SARIF (0 failures on main; denies on demo/failing-gates)
/home/sudo/.venvs/devsecops-pipeline/bin/conftest test --policy policy --data data \
  --parser json "$W"/sarif/*.sarif
```

## SBOM (M4+)

*(M4: document Syft invocation + CycloneDX output.)*
