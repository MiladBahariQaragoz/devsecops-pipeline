# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- M0 scaffold: CLAUDE.md, DISCLAIMER.md, LICENSE, CHANGELOG.md, README.md, plan.md,
  .gitignore, docs skeleton (POLICY.md, DECISIONS.md, RUNBOOK.md),
  .github/workflows/security.yml shell, pyproject.toml ruff config.
- M1: minimal secure Flask service (app/), Dockerfile (python:3.12-slim, non-root),
  pytest smoke test, CI lint+test job green on main.
