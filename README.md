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


Rollback: `helm rollback <release>`

---

See [`/docs/case-study.md`](./docs/case-study.md) and [`/docs/runbook.md`](./docs/runbook.md) for details.
