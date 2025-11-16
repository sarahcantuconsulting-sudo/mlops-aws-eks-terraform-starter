# Deployment Checklist

Use this checklist when deploying this infrastructure for a new client or environment.

## Pre-Deployment (Local Setup)

- [ ] Clone repository
- [ ] Configure AWS CLI profiles:
  ```bash
  aws configure --profile admin  # For Terraform infrastructure
  aws configure --profile builder  # For deployments
  ```
- [ ] Set GitHub repository in Terraform:
  ```bash
  cd terraform
  cat > terraform.tfvars <<EOF
  github_repo = "YOUR_ORG/YOUR_REPO"
  EOF
  ```
- [ ] Verify Terraform configuration:
  ```bash
  AWS_PROFILE=admin terraform init
  AWS_PROFILE=admin terraform validate
  AWS_PROFILE=admin terraform plan
  ```

## Infrastructure Deployment

- [ ] Deploy infrastructure:
  ```bash
  make tf-apply AWS_PROFILE=admin
  ```
- [ ] Save Terraform outputs:
  ```bash
  cd terraform
  terraform output github_oidc_role_arn  # Save for GitHub secrets
  terraform output cluster_name
  terraform output ecr_repository_name
  ```
- [ ] Install AWS Load Balancer Controller:
  ```bash
  make install-alb-controller AWS_PROFILE=builder
  ```
- [ ] Verify ALB controller is running:
  ```bash
  kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
  ```

## GitHub Actions Setup

- [ ] Configure GitHub repository variables (Settings → Secrets and variables → Actions → Variables):
  - `AWS_REGION`: `us-east-1`
  - `AWS_ACCOUNT_ID`: Get from `aws sts get-caller-identity --query Account --output text`
  - `EKS_CLUSTER_NAME`: Get from `terraform output cluster_name`
  - `ECR_REPO`: Get from `terraform output ecr_repository_name`

- [ ] Configure GitHub secrets (Settings → Secrets and variables → Actions → Secrets):
  - `AWS_ROLE_TO_ASSUME`: Get from `terraform output github_oidc_role_arn`

## First Deployment Test (Optional - Local Build)

This section is optional. You can skip to "GitHub Actions Test" to deploy via automation.
Use this only if you want to test infrastructure before setting up GitHub Actions.

- [ ] Build and push initial image manually:
  ```bash
  # Get ECR repository URL
  ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_url)
  
  # Login to ECR
  aws ecr get-login-password --region us-east-1 --profile builder | \
    docker login --username AWS --password-stdin ${ECR_REPO%%/*}
  
  # Build and push
  docker build -t $ECR_REPO:v0.0.8 .
  docker push $ECR_REPO:v0.0.8
  ```
- [ ] Deploy ML service:
  ```bash
  make deploy-ml-service AWS_PROFILE=builder
  ```
- [ ] Verify deployment:
  ```bash
  kubectl get pods -l app=ml-service
  kubectl get ingress ml-service
  ```
- [ ] Wait for ALB provisioning (2-3 minutes):
  ```bash
  make watch-alb
  ```
- [ ] Test endpoint:
  ```bash
  ALB_DNS=$(kubectl get ingress ml-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  curl http://$ALB_DNS/health
  ```

## GitHub Actions Test

- [ ] Create and push a version tag:
  ```bash
  git tag -a v0.0.8 -m "Testing automated deployment"
  git push origin v0.0.8
  ```
  **Note**: Only create tags for application releases (code/config changes). 
  Documentation updates can be pushed to branches without tags - they won't trigger deployment.
  
- [ ] Monitor GitHub Actions:
  - Go to repository → Actions tab
  - Watch the `deploy-on-tag` workflow
  - Verify all steps complete successfully
- [ ] Verify updated deployment:
  ```bash
  kubectl get pods -l app=ml-service
  kubectl describe pod <pod-name> | grep Image:  # Should show new tag
  ```
- [ ] Create GitHub Release (Optional):
  - Go to repository → Releases → Draft a new release
  - Select the tag you just pushed (e.g., `v0.0.8`)
  - Add release notes describing changes
  - Click "Publish release"
  - Note: Pushing the tag triggers deployment immediately; GitHub Release is just documentation

## Security Verification

- [ ] Verify OIDC trust policy is repository-scoped:
  ```bash
  aws iam get-role --role-name mlops-starter-demo-github-oidc-deployer --profile admin | grep -A5 Condition
  ```
- [ ] Verify EKS access policy (should be ClusterAdmin, not system:masters):
  ```bash
  aws eks list-access-entries --cluster-name mlops-starter-demo --profile admin
  aws eks describe-access-entry --cluster-name mlops-starter-demo --principal-arn <role-arn> --profile admin
  ```
- [ ] Verify no AWS credentials in GitHub:
  - Repository → Settings → Secrets and variables → Actions
  - Should only see `AWS_ROLE_TO_ASSUME` in secrets (no access keys)

## Cleanup (When Done Testing)

- [ ] Delete Kubernetes resources first:
  ```bash
  helm uninstall ml-svc
  kubectl delete ingress --all
  ```
- [ ] Wait for ALB to detach (60 seconds):
  ```bash
  sleep 60
  ```
- [ ] Destroy infrastructure:
  ```bash
  make tf-destroy AWS_PROFILE=admin
  ```
- [ ] Verify all resources deleted:
  ```bash
  aws eks list-clusters --region us-east-1 --profile admin
  aws ec2 describe-vpcs --filters "Name=tag:project,Values=mlops-starter" --profile admin
  ```

## Production Hardening (Before Client Delivery)

- [ ] Switch to private cluster endpoint (see `docs/runbook.md`)
- [ ] Configure VPN or bastion host for cluster access
- [ ] Scope GitHub Actions to specific namespace:
  ```terraform
  access_scope {
    type       = "namespace"
    namespaces = ["production"]
  }
  ```
- [ ] Add resource limits to Helm chart (CPU, memory)
- [ ] Enable CloudWatch Container Insights
- [ ] Configure log aggregation (Fluent Bit → CloudWatch)
- [ ] Set up monitoring alerts (CloudWatch Alarms)
- [ ] Document rollback procedures for client team
- [ ] Add branch protection rules (require PR reviews)
- [ ] Configure deployment approval gates for production

## Troubleshooting Resources

- **Operational issues**: See `docs/runbook.md`
- **GitHub Actions setup**: See `docs/github-setup.md`
- **Pod scheduling issues**: Check node capacity with `kubectl describe nodes`
- **ALB not provisioning**: Verify subnet tags and ALB controller logs
- **Image pull errors**: Verify ECR permissions and image exists
