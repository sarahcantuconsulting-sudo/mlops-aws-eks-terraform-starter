# Deploy

## Cluster Access Security

**Demo Configuration:** Public endpoint with optional IP restriction  
**Production Recommendation:** Private endpoint + AWS VPN

### Why Not IP Whitelisting in Production?

- **IPs change** - ISP rotation, VPN switches, mobile/travel access
- **Doesn't prevent compromised credentials** - Authentication still required
- **Terraform state drift** - Each apply fetches new IP, causing unnecessary updates
- **Team scaling issues** - Managing multiple developer IPs becomes unwieldy

### Production Alternatives

1. **AWS Client VPN** - Best for remote teams, managed by AWS
2. **Bastion Host + Session Manager** - Cost-effective, SSH tunneling
3. **Site-to-Site VPN / Direct Connect** - Enterprise/on-prem integration
4. **Private endpoint only** - Access via resources within VPC

### Current Setup

By default, the cluster endpoint allows public access from `0.0.0.0/0` but requires valid AWS IAM credentials.  
To restrict to your current IP during development:

```bash
cd terraform
terraform apply -var="enable_ip_restriction=true"
```

**Note:** This fetches your IP at apply time and will cause drift if your IP changes.

## Expose & Verify

### ClusterIP (local test)
```bash
kubectl port-forward svc/ml-service 8080:80
curl http://localhost:8080/health
```

### Ingress (ALB)
```bash
helm upgrade --install ml-svc ./helm/ml-service --set ingress.enabled=true
kubectl get ingress ml-service
```

## Deploy on Tag

```bash
git tag -a v0.0.5 -m "v0.0.5: deploy on tag"
git push --tags
```

After workflow:
```bash
kubectl get deploy ml-svc
kubectl get svc ml-service
```

---

## AWS Load Balancer Controller Setup

### Prerequisites

1. **Terraform applied** - ALB controller IAM role must exist
2. **kubectl configured** - Access to the EKS cluster
3. **Helm installed** - v3.x

### Installation

**Option 1: Using Make (Recommended)**
```bash
make install-alb-controller AWS_PROFILE=builder
```

**Option 2: Manual**
```bash
cd helm/alb-controller
CLUSTER_NAME=mlops-starter-demo AWS_REGION=us-east-1 AWS_PROFILE=builder bash install.sh
```

### What It Does

1. Fetches the IAM role ARN from Terraform output
2. Updates kubeconfig for the cluster
3. Discovers the VPC ID from the cluster
4. Installs AWS Load Balancer Controller via Helm (creates ServiceAccount with IRSA annotation)
5. Waits for deployment to be ready

### Verification

```bash
# Check controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Deploy ML service with ingress
make deploy-ml-service

# Get ALB DNS name
kubectl get ingress ml-service

# Test (wait for ADDRESS to populate, ~2-3 minutes)
curl http://<ALB-DNS>/health
```

### Troubleshooting

**Issue: Cannot retrieve alb_controller_role_arn from Terraform**
```bash
cd terraform
terraform output alb_controller_role_arn
```
Fix: Run `terraform apply` first to create the IAM infrastructure

**Issue: ServiceAccount missing role annotation**
```bash
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
# Should show: eks.amazonaws.com/role-arn annotation
```
Fix: The Helm chart automatically adds the annotation. Verify your install.sh completed successfully.

**Issue: Controller pods not starting**
```bash
kubectl describe pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```
Common causes:
- IAM role trust policy missing OIDC provider
- Subnet tags missing (`kubernetes.io/role/elb=1` for public subnets)
- Security group issues

**Issue: Ingress stuck without ADDRESS**
```bash
kubectl describe ingress ml-service
```
Check Events section for errors. Common causes:
- Subnets not tagged properly
- Security groups blocking ALB → pod traffic
- IAM permissions missing

**Issue: ALB created but health checks failing**
```bash
# Check target group health in AWS console or:
aws elbv2 describe-target-health --target-group-arn <TG-ARN>
```
Common causes:
- Wrong target port (should match container port 8080)
- Security group not allowing ALB → pod traffic
- Health check path misconfigured (should be `/health`)

### Subnet Tagging (Required for ALB)

If ALBs aren't provisioning, ensure your subnets have these tags:

**Public subnets (for internet-facing ALBs):**
```
kubernetes.io/role/elb = 1
```

**Private subnets (for internal ALBs):**
```
kubernetes.io/role/internal-elb = 1
```

The Terraform VPC module should handle this automatically, but verify:
```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<VPC-ID>" --query 'Subnets[*].[SubnetId,Tags]'
```

---

# Rollback

## Application Rollback (Helm)

### List release history
```bash
helm history ml-svc
```

### Rollback to previous version
```bash
helm rollback ml-svc
```

### Rollback to specific revision
```bash
helm rollback ml-svc 3
```

### Verify rollback
```bash
kubectl get pods -l app=ml-service
kubectl describe pod <pod-name>
```

## Infrastructure Rollback (Terraform)

### Preview changes
```bash
cd terraform
AWS_PROFILE=admin terraform plan
```

### Revert specific resource
```bash
# Import existing state if needed
terraform import module.eks.aws_eks_cluster.this[0] mlops-starter-demo

# Apply previous configuration
git checkout <previous-commit> terraform/
terraform apply
```

### Nuclear option (destroy and recreate)
```bash
# WARNING: This destroys all infrastructure
terraform destroy -target=module.eks
terraform apply
```

---

# Logs

## Application Logs

```bash
# Get pod names
kubectl get pods -l app=ml-service

# Tail logs
kubectl logs -f <pod-name>

# Previous container logs (if crashed)
kubectl logs <pod-name> --previous

# All pods at once
kubectl logs -l app=ml-service --all-containers=true -f
```

## ALB Controller Logs

```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller -f
```

## EKS Control Plane Logs

Enabled log types: `api`, `audit`, `authenticator`

```bash
# View in CloudWatch Logs
aws logs tail /aws/eks/mlops-starter-demo/cluster --follow
```

---

# Common Issues

## "Unable to connect to the server: i/o timeout"

**Cause:** Cluster endpoint is private-only or your IP isn't whitelisted

**Fix:**
```bash
# Check endpoint access
aws eks describe-cluster --name mlops-starter-demo \
  --query 'cluster.resourcesVpcConfig.{public:endpointPublicAccess,cidrs:endpointPublicAccessCidrs}'

# If needed, update Terraform to allow your IP
cd terraform
terraform apply -var="enable_ip_restriction=true"
```

## "Error: Kubernetes cluster unreachable"

**Cause:** kubeconfig not updated or wrong context

**Fix:**
```bash
aws eks update-kubeconfig --name mlops-starter-demo --region us-east-1 --alias mlops-starter-demo
kubectl config use-context mlops-starter-demo
kubectl get nodes
```

## "ImagePullBackOff"

**Cause:** ECR image not available or nodes can't pull

**Fix:**
```bash
# Check if image exists
aws ecr describe-images --repository-name mlops-starter-demo-ml-service

# Verify node IAM role has ECR permissions
kubectl describe pod <pod-name>

# Push image if missing
docker build -t <ECR-URI>:latest .
aws ecr get-login-password | docker login --username AWS --password-stdin <ECR-URI>
docker push <ECR-URI>:latest
```

## "Insufficient permissions to create AWS resources"

**Cause:** Using wrong AWS profile or profile lacks IAM permissions

**Fix:**
```bash
# Use admin profile for infrastructure changes
AWS_PROFILE=admin terraform apply

# Use builder profile for deployments
AWS_PROFILE=builder make deploy-ml-service
```

---

# Ownership