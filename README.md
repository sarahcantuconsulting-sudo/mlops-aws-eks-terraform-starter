# AWS MLOps Starter: Model → EKS (Terraform + Helm)

**Problem:** teams stuck moving from notebooks to prod reliably.  
**Approach:** minimal Terraform scaffold + Helm chart + CI path for build/push/deploy, with CloudWatch logging and rollback plan.  
**Outcomes:** lower MTTR • repeatable deploys • cost tags • basic observability • runbook from day one.

ASCII:
[Model] -> [Docker] -> [ECR] -> [Helm] -> [EKS svc]
                     -> [CloudWatch Logs]
Rollback: `helm rollback <release>`

See `/docs/case-study.md` and `/docs/runbook.md`.
