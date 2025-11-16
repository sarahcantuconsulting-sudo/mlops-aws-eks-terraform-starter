#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-mlops-starter-demo}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-builder}"

echo "[alb-controller] Installing AWS Load Balancer Controller"
echo "[alb-controller] Cluster: ${CLUSTER_NAME} | Region: ${AWS_REGION}"

# Get IAM role ARN from Terraform output
echo "[alb-controller] Fetching IAM role ARN from Terraform..."
ALB_CONTROLLER_ROLE_ARN=$(cd terraform && terraform output -raw alb_controller_role_arn)

if [ -z "${ALB_CONTROLLER_ROLE_ARN}" ]; then
  echo "ERROR: Could not retrieve alb_controller_role_arn from Terraform output"
  echo "Run 'terraform apply' first to create the IAM role"
  exit 1
fi

echo "[alb-controller] Role ARN: ${ALB_CONTROLLER_ROLE_ARN}"

# Configure kubectl
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --alias "${CLUSTER_NAME}" --profile "${AWS_PROFILE}"
kubectl config use-context "${CLUSTER_NAME}"

# Clean up any pre-existing ServiceAccount not managed by Helm
if kubectl get serviceaccount aws-load-balancer-controller -n kube-system &> /dev/null; then
  echo "[alb-controller] Found existing ServiceAccount, checking if Helm-managed..."
  if ! kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' | grep -q "Helm"; then
    echo "[alb-controller] Deleting non-Helm ServiceAccount..."
    kubectl delete serviceaccount aws-load-balancer-controller -n kube-system
  fi
fi

# Get VPC ID
VPC_ID="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --profile "${AWS_PROFILE}" --query 'cluster.resourcesVpcConfig.vpcId' --output text)"
echo "[alb-controller] VPC ID: ${VPC_ID}"

# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts > /dev/null 2>&1 || true
helm repo update > /dev/null

# Check for and clear any pending Helm operations
echo "[alb-controller] Checking for existing Helm release..."
if helm list -n kube-system | grep -q aws-load-balancer-controller; then
  RELEASE_STATUS=$(helm status aws-load-balancer-controller -n kube-system -o json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
  echo "[alb-controller] Current release status: ${RELEASE_STATUS}"
  
  if [ "$RELEASE_STATUS" = "pending-install" ] || [ "$RELEASE_STATUS" = "pending-upgrade" ] || [ "$RELEASE_STATUS" = "pending-rollback" ]; then
    echo "[alb-controller] Detected stuck release, cleaning up..."
    # Delete the pending operation secret
    kubectl delete secret -n kube-system -l status=pending-install,name=aws-load-balancer-controller 2>/dev/null || true
    kubectl delete secret -n kube-system -l status=pending-upgrade,name=aws-load-balancer-controller 2>/dev/null || true
    sleep 2
  fi
fi

# Install / upgrade the controller with Helm-managed ServiceAccount
echo "[alb-controller] Installing Helm chart..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f helm/alb-controller/values.yaml \
  --set clusterName="${CLUSTER_NAME}" \
  --set region="${AWS_REGION}" \
  --set vpcId="${VPC_ID}" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ALB_CONTROLLER_ROLE_ARN}" \
  --wait

echo "[alb-controller] ✅ Installation complete"
kubectl get deployment -n kube-system aws-load-balancer-controller
