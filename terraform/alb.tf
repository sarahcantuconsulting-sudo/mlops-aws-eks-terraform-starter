# Who am I (for account ID)?
data "aws_caller_identity" "current" {}

# IAM policy for AWS Load Balancer Controller
resource "aws_iam_policy" "alb_controller" {
  name        = "${local.name}-alb-controller"
  description = "IAM policy for AWS Load Balancer Controller for ${local.name}"
  policy      = file("${path.module}/policies/aws-load-balancer-controller-iam-policy.json")
  tags        = local.tags
}

# Trust policy for IRSA (service account in kube-system namespace)
data "aws_iam_policy_document" "alb_irsa_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"
      ]
    }

    condition {
      test = "StringEquals"
      # oidc_provider is issuer URL *without* https://, e.g. oidc.eks.us-east-1.amazonaws.com/id/...
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

# IAM role for ALB controller
resource "aws_iam_role" "alb_controller" {
  name               = "${local.name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_irsa_assume.json
  tags               = local.tags
}

# Attach policy -> role
resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
