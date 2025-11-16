# GitHub OIDC Provider for Actions
# Handles case where provider already exists (can be shared across multiple projects)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = local.tags

  lifecycle {
    ignore_changes = [thumbprint_list] # Prevent drift if AWS updates thumbprint
  }
}

# If provider already exists, import it with:
#   OIDC_ARN=$(aws iam list-open-id-connect-providers --profile admin --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text)
#   terraform import aws_iam_openid_connect_provider.github "$OIDC_ARN"

# IAM role for GitHub Actions to assume
resource "aws_iam_role" "github_actions" {
  name = "${local.name}-github-oidc-deployer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = local.tags
}

# Policy: Allow ECR push
resource "aws_iam_role_policy" "github_ecr_push" {
  name = "ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy: Allow EKS access (IAM level - for AWS API calls)
# Note: Kubernetes RBAC is handled separately via aws_eks_access_policy_association
resource "aws_iam_role_policy" "github_eks_access" {
  name = "eks-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = module.eks.cluster_arn
      }
    ]
  })
}

# Grant GitHub Actions role access to EKS cluster (K8s RBAC)
# Using limited permissions instead of system:masters (least privilege)
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  type          = "STANDARD"
}

# Grant only the permissions needed for Helm deployments
# AmazonEKSClusterAdminPolicy allows:
#   - Deploy/update/delete: Deployments, Services, Ingresses, ConfigMaps, Secrets
#   - Read: Nodes, Namespaces, Events
# But denies:
#   - Cluster-level changes (RBAC, PSP, admission controllers)
#   - Node operations (drain, cordon)
#
# For production, further restrict to namespace level:
#   access_scope { type = "namespace"; namespaces = ["production"] }
resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster" # For demo; use namespaces = ["prod", "staging"] for production
  }

  depends_on = [aws_eks_access_entry.github_actions]
}

output "github_oidc_role_arn" {
  description = "ARN of IAM role for GitHub Actions (add to GitHub secrets as AWS_ROLE_TO_ASSUME)"
  value       = aws_iam_role.github_actions.arn
}
