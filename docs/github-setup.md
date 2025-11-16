# GitHub Actions Setup

This guide walks you through configuring GitHub Actions for automated deployments using AWS OIDC (no long-lived credentials).

## Prerequisites

- Terraform infrastructure deployed (`make tf-apply`)
- GitHub repository with admin access
- AWS IAM permissions to create OIDC providers and roles

---

## 1. Configure GitHub Repository in Terraform

**Before applying Terraform**, set your GitHub repository name in `terraform/variables.tf`:

### Option A: Using terraform.tfvars (Recommended)

```bash
cd terraform

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
github_repo = "sarahcantuconsulting-sudo/mlops-aws-eks-terraform-starter"
EOF
```

### Option B: Set via environment variable

```bash
export TF_VAR_github_repo="sarahcantuconsulting-sudo/mlops-aws-eks-terraform-starter"
```

### Option C: Update default in variables.tf

Edit `terraform/variables.tf` and change the default value:
```terraform
variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = "sarahcantuconsulting-sudo/mlops-aws-eks-terraform-starter"
}
```

**Important**: Use format `owner/repo` (not the full GitHub URL)

---

## 2. Create OIDC IAM Role with Terraform

The `terraform/oidc.tf` file creates the necessary AWS resources for GitHub Actions to authenticate via OIDC.

### Apply the OIDC Configuration

```bash
cd terraform
AWS_PROFILE=admin terraform apply
```

This creates:
- GitHub OIDC provider with thumbprint for `token.actions.githubusercontent.com`
- IAM role `mlops-starter-demo-github-oidc-deployer` with trust policy scoped to your repository
- ECR push permissions (GetAuthorizationToken, PutImage, etc.)
- EKS cluster access (DescribeCluster, ListClusters)
- **Kubernetes RBAC**: EKS access entry with `AmazonEKSClusterAdminPolicy` (least privilege for Helm deployments)
  - Allows: Create/update/delete deployments, services, ingresses, configmaps
  - Denies: Node management, cluster configuration changes

### Get the Role ARN

```bash
terraform output github_oidc_role_arn
```

Expected output:
```
arn:aws:iam::YOUR_ACCOUNT_ID:role/mlops-starter-demo-github-oidc-deployer
```

**Save this ARN** - you'll need it for GitHub secrets configuration.

---

## 3. Configure GitHub Repository

Go to your repository: **Settings → Secrets and variables → Actions**

### Variables Tab

Click **"New repository variable"** and add each of these:

| Name               | Value                 | Description                               |
| ------------------ | --------------------- | ----------------------------------------- |
| `AWS_REGION`       | `us-east-1`           | AWS region where resources are deployed   |
| `AWS_ACCOUNT_ID`   | `YOUR_AWS_ACCOUNT_ID` | Your 12-digit AWS account ID              |
| `EKS_CLUSTER_NAME` | `mlops-starter-demo`  | Name of your EKS cluster (from Terraform) |
| `ECR_REPO`         | `ml-service`          | Name of your ECR repository               |

**Finding your values:**
```bash
# Get AWS Account ID
aws sts get-caller-identity --query Account --output text --profile admin

# Get EKS cluster name
cd terraform && terraform output cluster_name

# Get ECR repository name (just the name, not full URL)
cd terraform && terraform output ecr_repository_name
```

### Secrets Tab

Click **"New repository secret"** and add:

| Name                 | Value                                                                       | Description                        |
| -------------------- | --------------------------------------------------------------------------- | ---------------------------------- |
| `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::YOUR_ACCOUNT_ID:role/mlops-starter-demo-github-oidc-deployer` | IAM role ARN from Terraform output |

**Get the exact value:**
```bash
cd terraform
terraform output github_oidc_role_arn
```

---

## 3. Test the Workflow

### Trigger a Deployment

```bash
# Create and push a tag (this triggers the deploy-on-tag workflow)
git tag -a v0.0.8 -m "Testing automated deployment"
git push origin v0.0.8
```

**Note**: Pushing the tag immediately triggers deployment. GitHub Release creation is optional and only for documentation purposes.

### Watch the Workflow Run

1. Go to your GitHub repository
2. Click the **Actions** tab
3. You should see a workflow run named "deploy-on-tag"
4. Click on it to see real-time logs

### Expected Workflow Steps

✅ Checkout code  
✅ Configure AWS credentials (OIDC)  
✅ Verify AWS connection  
✅ Login to ECR  
✅ Build and push Docker image  
✅ Install kubectl & Helm  
✅ Update kubeconfig  
✅ Deploy with Helm  
✅ Verify deployment  

### Create GitHub Release (Optional)

After deployment succeeds, you can document the release:

1. Go to repository → **Releases** → **Draft a new release**
2. Click "Choose a tag" and select `v0.0.8`
3. Add release title: `v0.0.8 - Description of changes`
4. Add release notes:
   ```markdown
   ## Changes
   - Feature X added
   - Bug Y fixed
   - Updated dependency Z
   
   ## Deployment
   Automatically deployed to EKS via GitHub Actions at [timestamp]
   ```
5. Click **Publish release**

**Important**: The GitHub Release is purely documentation. The actual deployment already happened when you pushed the tag.  

---

## 4. Troubleshooting

### "Error: Could not assume role"

**Symptoms:**
```
Error: Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**Fixes:**
- ✅ Verify `github_repo` variable is set correctly in Terraform (must match your actual repo)
- ✅ Check OIDC provider exists: `aws iam list-open-id-connect-providers --profile admin`
- ✅ Verify role trust policy: `aws iam get-role --role-name mlops-starter-demo-github-oidc-deployer --profile admin`
- ✅ Ensure workflow has `permissions: id-token: write` (already set in `.github/workflows/deploy-on-tag.yml`)
- ✅ Verify you pushed to the correct repository (trust policy is repo-specific)

### "Error: Unauthorized to perform: eks:DescribeCluster"

**Symptoms:**
```
Error: error describing cluster (mlops-starter-demo): AccessDenied
```

**Fixes:**
- ✅ Verify IAM role has EKS describe permissions (check `terraform/oidc.tf` - `github_eks_access` policy)
- ✅ Ensure EKS cluster ARN in policy matches actual cluster
- ✅ Check AWS region matches between workflow and Terraform

### "Error: Repository does not exist"

**Symptoms:**
```
An error occurred (RepositoryNotFoundException) when calling the DescribeRepositories operation
```

**Fixes:**
- ✅ Run `terraform apply` to create the ECR repository
- ✅ Verify ECR repo name matches `ECR_REPO` variable: `aws ecr describe-repositories --repository-names ml-service --profile builder`

### "Error: cluster not found"

**Symptoms:**
```
Error from server (NotFound): clusters "mlops-starter-demo" not found
```

**Fixes:**
- ✅ Verify `EKS_CLUSTER_NAME` variable matches actual cluster name
- ✅ Check cluster exists: `aws eks list-clusters --region us-east-1 --profile builder`
- ✅ Ensure cluster is in the correct region (check `AWS_REGION` variable)

### "Error: Deployment failed with timeout"

**Symptoms:**
```
Error: timed out waiting for the condition
```

**Fixes:**
- ✅ Check pod logs: `kubectl logs -l app=ml-service`
- ✅ Verify image was pushed to ECR: `aws ecr describe-images --repository-name ml-service --profile builder`
- ✅ Check node capacity: `kubectl describe nodes` (t3.micro has pod limits)
- ✅ Ensure ALB controller is running: `kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`

### Image pull errors

**Symptoms:**
```
Failed to pull image "ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/ml-service:v0.0.8": rpc error: code = Unknown
```

**Fixes:**
- ✅ Verify EKS node IAM role has ECR pull permissions (Terraform handles this via `AmazonEC2ContainerRegistryReadOnly` policy)
- ✅ Check image exists: `aws ecr describe-images --repository-name ml-service --profile builder`
- ✅ Verify tag is correct in Helm values

---

## 5. Local Testing (Without GitHub Actions)

If you want to test the build/deploy flow locally without GitHub Actions:

```bash
# Build and push image manually
make build-and-push AWS_PROFILE=builder

# Deploy manually
make deploy-ml-service AWS_PROFILE=builder

# Verify
make verify-alb
```

This mimics what GitHub Actions does, useful for debugging before pushing tags.

---

## 6. Workflow Customization

The workflow is in `.github/workflows/deploy-on-tag.yml`. Common customizations:

### Change deployment timeout
```yaml
helm upgrade --install ml-svc ./helm/ml-service \
  --timeout 10m  # Default is 5m
```

### Add smoke tests after deployment
```yaml
- name: Smoke test
  run: |
    ALB_DNS=$(kubectl get ingress ml-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    curl -f http://$ALB_DNS/health || exit 1
```

### Deploy to multiple environments
Create separate workflow files for `deploy-dev.yml` and `deploy-prod.yml` with different variable sets.

---

## Security Notes

- **OIDC is preferred** over long-lived IAM access keys (no secrets to rotate)
- **Role ARN is sensitive** but not a credential itself (still keep it in GitHub secrets)
- **Trust policy is scoped** to your specific GitHub repository
- **Permissions are minimal** (ECR push, EKS describe only)

For production, consider:
- Separate AWS accounts per environment (dev/staging/prod)
- Branch protection rules (require PR reviews before merging to main)
- Manual approval gates for production deployments
- AWS CloudTrail logging of all AssumeRole calls

---

## Next Steps

Once GitHub Actions is working:
1. Set up branch protection rules
2. Add deployment approval workflows for production
3. Configure Slack/email notifications for failed deployments
4. Add automated testing before deployment

See [`docs/runbook.md`](./runbook.md) for operational procedures after deployment.