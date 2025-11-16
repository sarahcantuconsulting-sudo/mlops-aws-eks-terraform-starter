# AWS MLOps Starter: Model → EKS (Terraform + Helm)

**Problem**  
Teams often get stuck turning notebooks into reliable production systems. The usual blockers: fragile CI/CD, missing observability, and no rollback plan.

**Approach**  
A minimal, reviewable scaffold showing the full path from model → container → AWS EKS using Terraform + Helm.  
Includes placeholders for CI build/push/deploy, CloudWatch logging hooks, and cost tagging. Everything is kept simple enough to audit and extend.

**Outcomes**  
- Repeatable, versioned deployments  
- Lower MTTR with clear rollback (`helm rollback <release>`)  
- Cost tagging and observability ready  
- Runbook and structure from day one  

---

### Roadmap → From Starter to Production

This scaffold is intentionally minimal.  
The [Issues](./issues) tab tracks the next steps toward a production-grade setup:

✅ Basic CI/CD, Helm chart, and FastAPI toy app  
✅ Terraform EKS/VPC modules with IRSA  
✅ GitHub Actions deploy to EKS (OIDC + IRSA)  
✅ AWS Load Balancer Controller (ALB) with Ingress  
✅ Comprehensive runbook with troubleshooting  
✅ Makefile automation for common tasks  
⬜ CloudWatch log shipping (Fluent Bit)  
⬜ Security hardening & resource limits  
⬜ HPA (Horizontal Pod Autoscaling)  
⬜ Real ML model inference endpoint

**Version History:**
- v0.0.3 - Demo Terraform modules (VPC, EKS, ECR)
- v0.0.4 - Service + optional Ingress (ALB)
- v0.0.5 - Deploy on tag (OIDC → ECR → Helm)
- v0.0.6 - EKS cluster + VPC foundation operational
- v0.0.7 - Refined deploy docs + IP restriction toggle
- v0.0.8 - AWS Load Balancer Controller via Helm + IRSA (Helm-managed ServiceAccount)
  

---

### Quick Start

**Prerequisites:**
- AWS CLI configured with appropriate profiles (`admin` for infra, `builder` for deployments)
- Terraform >= 1.5.0
- kubectl
- Helm v3.x
- Docker (for local builds)

**1. Deploy Infrastructure**
```bash
cd terraform
AWS_PROFILE=admin terraform init
AWS_PROFILE=admin terraform apply
```

**2. Install AWS Load Balancer Controller**
```bash
make install-alb-controller AWS_PROFILE=builder
```

**3. Deploy ML Service**
```bash
make deploy-ml-service AWS_PROFILE=builder
```

**4. Verify Deployment**
```bash
# Check ingress for ALB DNS
kubectl get ingress ml-service

# Test the service (wait 2-3 minutes for ALB provisioning)
curl http://<ALB-DNS>/health
```

See [`docs/runbook.md`](./docs/runbook.md) for detailed deployment steps and troubleshooting.

---

### What You Get
- Terraform scaffold for core infrastructure  
- Example Helm chart for a single ML service  
- CI skeleton for build/push/deploy  
- Hooks for CloudWatch logging and cost tagging  
- Example runbook & case study docs

### What This Is *Not*
- A full production platform or managed service  
- A live deployment with real credentials  
- A substitute for your organization’s security/compliance setup  
- Optimized performance or cost-tuned cluster configuration

---

### Deployment Flow

```
Model → Docker → ECR → Helm → EKS Service → ALB (Internet-facing)
             ↓
        GitHub Actions
        (OIDC auth)
```

**Infrastructure Setup:**
1. Terraform provisions VPC, EKS, ECR, IAM roles (IRSA for ALB controller)
2. AWS Load Balancer Controller installed via Helm (using `make install-alb-controller`)
3. Ingress enabled by default in `helm/ml-service/values.yaml`

**Application Deployment:**
- **Manual:** `make deploy-ml-service`
- **Automated:** Push a git tag (e.g., `v0.0.8`) to trigger GitHub Actions
  - Builds Docker image
  - Pushes to ECR
  - Deploys via Helm

**Access Options:**
- **ALB (default):** `curl http://<ALB-DNS>/health` (get DNS from `kubectl get ingress ml-service`)
- **Local port-forward:** `kubectl port-forward svc/ml-service 8080:80` then `curl :8080/health`

**Rollback:** `helm rollback ml-svc` (see [runbook](./docs/runbook.md) for details)

---

See [`/docs/case-study.md`](./docs/case-study.md) and [`/docs/runbook.md`](./docs/runbook.md) for details.

---

## CI/CD: Deploy on Tag

This repository includes a GitHub Actions workflow for automated builds and deploys.

**What happens when you push a tag (e.g., `v0.0.8`):**
1. GitHub Actions assumes your AWS role via OIDC (no long-lived keys)
2. Builds and tags the Docker image with the git commit SHA
3. Pushes the image to your ECR repository
4. Updates kubeconfig and deploys to EKS via Helm
5. Verifies deployment health

**Triggering a deployment:**
```bash
git tag -a v0.0.8 -m "v0.0.8: describe changes"
git push --tags
```

**Required GitHub Secrets:**
- `AWS_ROLE_TO_ASSUME` - ARN of the IAM role for OIDC auth
- `AWS_ACCOUNT_ID`, `AWS_REGION`, `ECR_REPO`, `CLUSTER_NAME` - as repository variables

See `.github/workflows/deploy-on-tag.yml` and [`docs/runbook.md`](./docs/runbook.md) for full details.

---

## Available Make Commands

```bash
# Install AWS Load Balancer Controller (requires Terraform applied)
make install-alb-controller AWS_PROFILE=builder

# Deploy ML service with Helm
make deploy-ml-service AWS_PROFILE=builder

# Check ingress status
make verify-alb
```

All commands support overriding defaults:
```bash
make install-alb-controller CLUSTER_NAME=my-cluster AWS_REGION=us-west-2 AWS_PROFILE=admin
```
