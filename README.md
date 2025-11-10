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
⬜ Terraform EKS/VPC modules  
⬜ GitHub Actions deploy to EKS (OIDC + IRSA)  
⬜ CloudWatch log shipping (Fluent Bit)  
⬜ Security hardening & cost tagging  
⬜ HPA and Ingress/ALB example  

 - This repo is the Starter. A fuller Blueprint may be split into a separate repo after v0.1.0.
 - v0.0.3 adds demo Terraform modules (VPC, EKS, ECR) to illustrate structure. Not intended for production apply.
  

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
Model → Docker → ECR → Helm → EKS Service
                    ↳ CloudWatch Logs
```

**Expose the service**
- ClusterIP (default): `kubectl port-forward svc/ml-service 8080:80` → `curl :8080/health`
- Ingress/ALB (optional): set `ingress.enabled=true` and ensure AWS Load Balancer Controller is installed.

Rollback: `helm rollback <release>`

---

See [`/docs/case-study.md`](./docs/case-study.md) and [`/docs/runbook.md`](./docs/runbook.md) for details.
