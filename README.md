# 05 — DevSecOps CI/CD Pipeline with Security Gates

**Difficulty:** ⭐⭐⭐ · **Est. effort:** 3–4 weeks · **Repo name:** `devsecops-pipeline`

## Why this project
A self-paced learning project, built for fun. I already enjoy working with Docker, GCP, Git,
and CI/CD, so this is a natural place to go deeper on the security side — learning how to
"shift left" and add the "Sec" to DevOps by building a pipeline that ships secure software,
not just one that runs tests.

## What I'm learning
- **DevSecOps** & secure SDLC
- **Infrastructure as Code (IaC)** security (Terraform + scanning)
- Container, dependency & secrets scanning (**SCA/SAST/IaC scanning**)
- **Security automation** in CI/CD

## Scope / what you build
A GitHub Actions (or GitLab CI) pipeline for a sample app that **fails the build on security
findings**, with every gate explained.

1. **Sample app:** a small containerised Python/Flask service (reuse project 04's app) +
   **Terraform** for some cloud resource.
2. **Pipeline gates** (each blocks merge on high severity):
   - **SAST:** Semgrep / CodeQL on the source.
   - **SCA:** `pip-audit` / Trivy / Grype for vulnerable dependencies.
   - **Secrets:** Gitleaks / TruffleHog pre-commit + CI.
   - **Container scan:** Trivy/Grype on the built image; enforce a hardened base image.
   - **IaC scan:** Checkov / tfsec / Trivy on the Terraform.
   - **DAST (optional):** OWASP ZAP baseline scan against the running container.
3. **SBOM:** generate a Software Bill of Materials (Syft / CycloneDX) as a build artifact.
4. **Policy as code:** a documented severity threshold + exception process.
5. **Evidence:** show a PR that fails the gate (planted vuln) and a clean PR that passes.

## Definition of done
- [ ] Public repo with a green pipeline + a deliberately failing branch (screenshots).
- [ ] ≥4 distinct security gates wired and enforcing.
- [ ] An SBOM artifact produced per build.
- [ ] README explaining each gate, the tool, and why it matters in the SDLC.
- [ ] A short "shift-left" rationale section.

## Build order
1. Containerise the app; get a basic CI build green.
2. Add gates one at a time; plant a vuln to prove each one fires.
3. Add SBOM + IaC scanning + secrets scanning.
4. Document the policy and exception workflow.

## Learning resources
- OWASP DevSecOps Guideline, Trivy / Grype / Syft (Aqua, Anchore) docs.
- Semgrep, CodeQL, Checkov, Gitleaks docs; GitHub Actions security hardening guide.
- "DevSecOps" TryHackMe / freeCodeCamp content.

## In a nutshell
A DevSecOps CI/CD pipeline (GitHub Actions) with SAST, SCA, secrets, container, and IaC
scanning gates plus SBOM generation; the pipeline blocks merges on high-severity findings and
demonstrates shift-left security on a containerised service.
