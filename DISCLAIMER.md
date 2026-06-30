# Disclaimer

This repository is a **self-paced learning project** for exploring DevSecOps tooling, CI/CD
pipeline design, and security gate automation.

## Scope and authorisation

- All scanning targets (`app/`, `infra/`) are artifacts **created and owned by the repository
  author** for this project. No third-party systems are targeted.
- All tools (Semgrep, Trivy, Gitleaks, Checkov, OPA/conftest, Syft) are run **locally or in
  GitHub Actions CI** against this repository's own code and container images only.
- **No `terraform apply` is ever executed.** The `infra/` Terraform is scanned statically only.
  There is no live GCP project, no service account, and no billable cloud resource in v1.
- The `demo/failing-gates` branch contains deliberately planted, **fake** vulnerabilities
  (including an obviously fake AWS-key-shaped placeholder) to demonstrate gate detection. These
  are never real credentials and the vulnerable app variant is never deployed.

## No cloud spend

By design, this project incurs **zero cloud cost**. GitHub Actions is within the free tier for
a public repository. No cloud provider account is used or required.

## Intended audience

This project is a public portfolio and learning artifact. The pipeline and scanning
configurations are shared for educational purposes. Reproduce only in environments you own and
control.
