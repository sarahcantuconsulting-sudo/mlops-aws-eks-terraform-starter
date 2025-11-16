#!/bin/bash
# Import existing GitHub OIDC provider into Terraform state if it exists
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-admin}"
TERRAFORM_DIR="${1:-terraform}"

cd "$TERRAFORM_DIR"

echo "🔍 Checking if GitHub OIDC provider already exists in AWS..."

# Check if already in Terraform state
if terraform state show aws_iam_openid_connect_provider.github &>/dev/null; then
    echo "✅ OIDC provider already in Terraform state - nothing to do"
    exit 0
fi

# Look for existing provider in AWS
OIDC_ARN=$(aws iam list-open-id-connect-providers \
    --profile "$AWS_PROFILE" \
    --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' \
    --output text 2>/dev/null || echo "")

if [ -z "$OIDC_ARN" ]; then
    echo "✅ No existing OIDC provider found - Terraform will create it"
    exit 0
fi

echo "📥 Found existing OIDC provider: $OIDC_ARN"
echo "   Importing into Terraform state..."

if AWS_PROFILE="$AWS_PROFILE" terraform import aws_iam_openid_connect_provider.github "$OIDC_ARN"; then
    echo "✅ Successfully imported OIDC provider into Terraform state"
    echo ""
    echo "You can now run: terraform apply"
else
    echo "❌ Failed to import OIDC provider"
    exit 1
fi
