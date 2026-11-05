# RealWorld on AWS: continuous delivery platform

Take-home task: a scalable, secure continuous delivery architecture for the
RealWorld (Conduit) full-stack app (Angular frontend, Django Ninja backend)
on AWS EKS, provisioned with Terraform and deployed with GitOps (ArgoCD).

> Work in progress. Sections marked TODO are filled in as the build proceeds.

## Repository layout

```
backend/                 Django Ninja API (imported, see below) + Dockerfile
frontend/                Angular app (imported) + Dockerfile (nginx, non-root)
infra/
  global/                once per account: state bucket, GitHub OIDC provider, budget, guard rails
  modules/               reusable building blocks
    network/             VPC, public / private / database subnets x 3 AZ, NAT, endpoints, flow logs
    eks/                 EKS, managed node group, addons, access entries, IRSA OIDC
    irsa-role/           IAM role for one Kubernetes service account
    data/                RDS PostgreSQL (Multi-AZ), its security group and parameters
    edge/                CloudFront + WAF, ALB + target groups, optional domain/TLS
    backup/              AWS Backup plan, vault (lock), cross-region copy
    security/            CloudTrail, GuardDuty, IAM Access Analyzer
    ci/                  ECR repositories, GitHub Actions roles (OIDC)
    observability/       Loki bucket, alerts SNS topic
  envs/
    dev/aws/             composes the modules for one environment
    dev/argocd/          ArgoCD bootstrap: installs ArgoCD + the root Application, nothing else
gitops/
  bootstrap/             app-of-apps chart: one Application per component
  platform/              what ArgoCD installs besides the app (values + manifests)
  charts/realworld/      Helm chart for the app
  envs/dev/values.yaml   per-environment app values; CI bumps image tags here
loadtest/                k6 performance regression test                   TODO
.github/workflows/       CI (tests, scans, build, deploy), CodeQL, Terraform checks/plan
docs/                    architecture diagram                             TODO
```

## Application source

| Dir | Upstream | Commit |
|---|---|---|
| backend/ | github.com/c4ffein/realworld-django-ninja (MIT), **this repo is its fork** | 87dd078 |
| frontend/ | github.com/realworld-apps/angular-realworld-example-app (MIT) | ea0dd03 |

This repository is a fork of the backend implementation; its files were
moved into `backend/` with `git mv`, so their history is kept and the diff
against upstream shows exactly what was changed. The frontend is imported as
plain code (no submodules), so the whole delivery lives in one repo.

Changes made for running on EKS:

- backend: `SECRET_KEY` from `DJANGO_SECRET_KEY` (fails to start without it
  unless `DEBUG`), `DATABASE_URL` query options passed to psycopg
  (`sslmode=require`), persistent DB connections, JSON logs to stdout,
  `/healthz` liveness endpoint without a DB call, gunicorn instead of
  `runserver`, multi-stage image running as uid 10001.
  Django 5.2.1 -> 5.2.17 and sqlparse 0.4.4 -> 0.6.0: the image scan found
  fixable HIGH/CRITICAL CVEs (incl. CVE-2025-64459, SQL injection).
- frontend: API calls go to same-origin `/api` instead of a public demo API;
  only the theme CSS and SVGs from the RealWorld repo are vendored
  (`frontend/realworld/assets`); nginx-unprivileged image (uid 101, port 8080).
  Unit tests did not run upstream (zone.js missing, TestBed initialised
  twice); fixed, 180 tests pass.

Both images run with a read-only root filesystem (only `/tmp` writable).

## Tiers

| Tier | What | Where |
|---|---|---|
| Edge | CloudFront, WAF, ALB | public subnets; ALB only accepts CloudFront + secret header |
| Application | frontend + backend pods on EKS | private subnets, egress via NAT |
| Data | RDS PostgreSQL | database subnets, no internet route, SG only from app tier |

## Build order

```bash
# 0. Credentials for the take-home account only (never the default profile)
export AWS_PROFILE=incode

# 1. Account-level resources (local state, creates the state bucket)
cd infra/global && cp terraform.tfvars.example terraform.tfvars   # edit
terraform init && terraform apply

# 2. AWS infrastructure for dev
cd ../envs && cp backend.hcl.example backend.hcl                  # edit
cd dev/aws && cp terraform.tfvars.example terraform.tfvars        # edit
terraform init -backend-config=../../backend.hcl && terraform apply

# 3. ArgoCD bootstrap (after this, git is the source of truth for the cluster)
cd ../argocd && cp terraform.tfvars.example terraform.tfvars      # edit
terraform init -backend-config=../../backend.hcl && terraform apply
```

Every provider pins `allowed_account_ids`, so Terraform refuses to run
against any other AWS account.

## ArgoCD bootstrap

Terraform installs exactly two things into the cluster: the ArgoCD Helm chart
and one root Application (via the `argocd-apps` chart). The root app points at
`gitops/bootstrap`, which renders an Application per component in sync waves:

| Wave | Applications |
|---|---|
| -30 | platform-base (namespaces with Pod Security labels, gp3 StorageClass) |
| -20 | aws-load-balancer-controller, external-secrets, metrics-server, cluster-autoscaler |
| -10 | eso-config (ClusterSecretStore), kube-prometheus-stack, loki |
| 0 | alloy |
| 10 | realworld |

Values that only exist after `terraform apply` (IRSA role ARNs, target group
ARNs, bucket names, secret names) are passed once, as `helm.valuesObject` of
the root app. That is the single hand-off point between Terraform and GitOps.

## CI/CD

```
PR / push ──► backend: ruff + 92 unit tests on PostgreSQL
          ├─► frontend: prettier + 180 unit tests
          ├─► gitleaks (whole git history)
          ├─► trivy config (Terraform, Dockerfiles, Helm; accepted risks in .trivyignore.yaml)
          └─► CodeQL (Python, TypeScript)
                │ all green
                ▼
          build images ──► trivy image (fail on fixable HIGH/CRITICAL)
                       └─► official RealWorld API spec (Hurl, 157 requests)
                           against the built backend image + PostgreSQL
                │ main only
                ▼
          push to ECR (OIDC role, tag = git SHA, immutable)
                ▼
          commit new tag to gitops/envs/dev/values.yaml ──► ArgoCD syncs:
          ExternalSecrets ─► migration Job ─► rolling update (maxUnavailable 0)
```

- CI never talks to the cluster and stores no AWS keys: GitHub OIDC for ECR,
  ArgoCD pulls from git (pull-based CD).
- GitHub-hosted runners are enough: nothing in CI needs the private network.
  Self-hosted runners in the VPC would be needed only to plan/apply the
  ArgoCD stack (private EKS API) from CI.
- Infra: `terraform fmt`/`validate` on every change, `plan` on PRs with a
  read-only role; `apply` is manual.
- Third-party actions are pinned to commit SHAs; Dependabot updates them
  together with pip, bun, Docker base images and Terraform providers.

## Design decisions, known gaps

TODO
