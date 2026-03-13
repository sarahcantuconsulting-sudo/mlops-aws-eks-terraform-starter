# CLAUDE.md — MLOps AWS EKS Terraform Starter

This file provides guidance for AI assistants working in this repository.

## Project Overview

A production-ready starter template for deploying ML models to AWS EKS. The stack
covers the full lifecycle: infrastructure provisioning (Terraform), containerised model
serving (FastAPI + Docker), Kubernetes deployment (Helm), and CI/CD (GitHub Actions
with OIDC).

**Key tech:** Python 3.11 · FastAPI · scikit-learn · Terraform >= 1.5 · AWS EKS 1.29 ·
Helm v3 · GitHub Actions

---

## Repository Layout

```
├── app/                  # FastAPI application (model serving)
│   ├── main.py           # API routes: GET /health, POST /predict
│   └── config.py         # Env-var config (MODEL_PATH)
├── scripts/
│   ├── train_model.py    # Trains iris RandomForest; run during Docker build
│   └── import-github-oidc.sh  # Imports existing OIDC provider before tf-init
├── terraform/            # All AWS infrastructure
│   ├── main.tf           # VPC, EKS cluster, ECR, node groups
│   ├── variables.tf      # Input variables with defaults
│   ├── oidc.tf           # GitHub OIDC provider + IAM roles
│   ├── alb.tf            # ALB Controller IRSA setup
│   ├── outputs.tf        # Cluster name, ECR URL, role ARNs
│   ├── versions.tf       # Provider version constraints
│   └── policies/         # Raw IAM policy JSON
├── helm/
│   ├── ml-service/       # Helm chart for the FastAPI app
│   └── alb-controller/   # Helm chart wrapper for AWS LB Controller
├── .github/workflows/
│   ├── deploy-on-tag.yml # Build + push ECR + Helm deploy (triggered by git tag)
│   ├── ci.yml            # Terraform fmt/validate + Helm lint + Docker build
│   └── oidc-smoke.yml    # Manual OIDC connectivity verification
├── docs/
│   ├── runbook.md        # Operational procedures and troubleshooting
│   └── github-setup.md   # OIDC + GitHub Actions variable configuration
├── Makefile              # Developer shortcuts (see below)
├── Dockerfile            # Multi-stage: train model → runtime image
├── requirements.txt      # Python deps: fastapi uvicorn scikit-learn joblib numpy pydantic
└── DEPLOY-CHECKLIST.md   # Step-by-step deployment checklist
```

---

## Development Workflows

### Infrastructure (Terraform)

```bash
# 1. Create terraform/terraform.tfvars (gitignored) with your values
# 2. Initialize and deploy
make tf-init    # imports OIDC provider if already in AWS, then `terraform init`
make tf-apply   # terraform apply with timing

# Tear down
make tf-destroy
```

Default Makefile variable: `AWS_PROFILE=builder`. Override: `make tf-init AWS_PROFILE=myprofile`.

**Required `terraform.tfvars` fields:**
```hcl
github_repo = "YOUR_ORG/mlops-aws-eks-terraform-starter"
```

Optional overrides: `region`, `project`, `env`, `cluster_version`, `enable_ip_restriction`.

### Application (Local)

```bash
pip install -r requirements.txt
python scripts/train_model.py   # creates local_models/model.pkl
MODEL_PATH=local_models/model.pkl uvicorn app.main:app --reload
```

Endpoints:
- `GET /health` → `{"status": "ok"}`
- `POST /predict` with body `{"features": [5.1, 3.5, 1.4, 0.2]}` → `{"prediction": 0}`

### Docker Build

```bash
docker build -t ml-service:local .
docker run -p 8000:8000 ml-service:local
```

The Dockerfile runs `scripts/train_model.py` in the builder stage and embeds the
resulting `model.pkl` in the runtime image. No external model artifact store is needed
for this demo.

### Kubernetes Deployment

```bash
# Install AWS Load Balancer Controller (once per cluster)
make install-alb-controller

# Deploy / upgrade the ML service
make deploy-ml-service

# Monitor ALB provisioning
make verify-alb
make watch-alb
```

Helm chart values live in `helm/ml-service/values.yaml`. Image tag is set at deploy
time via the CI/CD pipeline (`--set image.tag=$TAG`).

### CI/CD

Production deployment is triggered by pushing a semver git tag:

```bash
git tag v0.0.9
git push origin v0.0.9
```

The `deploy-on-tag.yml` workflow:
1. Assumes AWS role via OIDC (no stored credentials)
2. Builds and pushes Docker image to ECR tagged with the git tag
3. Runs `helm upgrade --install` against EKS with the new image tag
4. Verifies rollout and pod status

CI checks (`ci.yml`) run on every push and PR: `terraform fmt`, `terraform validate`,
`helm lint`, and a Docker build test.

---

## Key Conventions

### Terraform

- **State:** Local by default (`terraform.tfstate` — gitignored). For real projects,
  configure an S3 + DynamoDB remote backend in `versions.tf`.
- **Secrets:** Never commit `terraform.tfvars` or `*.tfstate*`. These are in `.gitignore`.
- **OIDC provider:** AWS allows only one GitHub OIDC provider per account. The
  `import-github-oidc.sh` script handles idempotent import before `terraform init`.
- **Module style:** Flat structure (no sub-modules) for readability. One `.tf` file per
  concern (`main`, `oidc`, `alb`, `variables`, `outputs`, `versions`).
- **Tagging:** Resources use `Owner = var.project` and `Environment = var.env`.

### Kubernetes / Helm

- **IRSA pattern:** IAM roles are bound to Kubernetes ServiceAccounts via annotations.
  Never use node-level IAM roles for pod permissions.
- **Security context:** All pods run as non-root (UID 1000), with `readOnlyRootFilesystem`
  and `allowPrivilegeEscalation: false`.
- **Resource limits:** Always set `requests` and `limits` for CPU and memory.
- **Health probes:** Both liveness and readiness probes point to `GET /health`.
- **HPA:** Enabled with target 70% CPU, max 3 replicas.

### Python Application

- Configuration via environment variables only (see `app/config.py`).
- Model path injected through `MODEL_PATH` env var; default `/models/model.pkl`.
- Pydantic models for request/response validation.
- Return HTTP 500 if model is not loaded; HTTP 400 for bad prediction input.

### GitHub Actions

- **Authentication:** OIDC only — no `AWS_ACCESS_KEY_ID` secrets.
- **Required repository variables** (not secrets): `AWS_REGION`, `AWS_ACCOUNT_ID`,
  `EKS_CLUSTER_NAME`, `ECR_REPO`.
- **Required repository secret:** `AWS_ROLE_TO_ASSUME` (IAM role ARN from Terraform
  output `github_actions_role_arn`).
- Deployment is always tag-triggered, never branch-triggered, to keep production
  deployments intentional.

### Security Constraints

- Do not add `system:masters` or overly broad IAM policies.
- The GitHub Actions IAM role should only have ECR push/pull and EKS describe
  permissions — expand carefully.
- `enable_ip_restriction = true` in `terraform.tfvars` to whitelist your IP on the EKS
  public endpoint during development.
- ECR image scanning is enabled on push; check scan results before promoting images.

---

## Common Make Targets Reference

| Target | What it does |
|---|---|
| `make tf-init` | Import OIDC provider (idempotent) then `terraform init` |
| `make tf-apply` | `terraform apply` with elapsed time output |
| `make tf-destroy` | `terraform destroy` with elapsed time output |
| `make install-alb-controller` | Helm install of AWS Load Balancer Controller |
| `make deploy-ml-service` | Helm upgrade/install of the ML service |
| `make verify-alb` | Show Ingress/ALB status |
| `make watch-alb` | Live-watch ALB provisioning events |

Override defaults: `CLUSTER_NAME`, `AWS_REGION`, `AWS_PROFILE`.

---

## Infrastructure Topology

```
GitHub Actions (OIDC)
       │
       ▼
  IAM Role (ECR + EKS describe)
       │
  ┌────┴──────────────────────────────┐
  │           AWS (us-east-1)         │
  │  ┌────────────────────────────┐   │
  │  │  VPC 10.0.0.0/16           │   │
  │  │  ┌──────────┐ ┌─────────┐ │   │
  │  │  │ Public   │ │ Private │ │   │
  │  │  │ subnets  │ │ subnets │ │   │
  │  │  └──────────┘ └────┬────┘ │   │
  │  │   ALB (internet)   │      │   │
  │  │                    ▼      │   │
  │  │              EKS Cluster  │   │
  │  │          (t3.small nodes) │   │
  │  │        FastAPI + model.pkl│   │
  │  └────────────────────────────┘   │
  │                                   │
  │  ECR (image registry)             │
  └───────────────────────────────────┘
```

---

## Files to Never Modify Directly

- `terraform/.terraform/` — auto-generated, gitignored
- `terraform/terraform.tfstate*` — state files, gitignored
- `terraform/terraform.tfvars` — local secrets, gitignored
- `local_models/` — generated model artifacts, gitignored
- `__pycache__/`, `*.pyc` — Python bytecode, gitignored

---

## Extending This Starter

Common next steps and where to make changes:

| Goal | Where |
|---|---|
| Add a new API endpoint | `app/main.py` |
| Swap to a real ML model | `scripts/train_model.py` + `Dockerfile` |
| Add environment (staging/prod) | New `terraform.tfvars` + Helm `values-<env>.yaml` |
| Remote Terraform state | `terraform/versions.tf` (add S3 backend block) |
| CloudWatch log shipping | Add Fluent Bit DaemonSet to `helm/` |
| Add secrets management | AWS Secrets Manager + External Secrets Operator |
| Private EKS endpoint only | Set `enable_ip_restriction = true`, add VPN/bastion |
