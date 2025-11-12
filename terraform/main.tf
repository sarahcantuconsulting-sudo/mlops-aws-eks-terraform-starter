############################
# DEMO-ONLY: illustrative modules
# Do not apply as-is in production.
############################

locals {
  name = "${var.project}-${var.env}"
  tags = {
    project = var.project
    env     = var.env
    owner   = "mlops-starter"
  }
}

# VPC (simple 2-az)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name               = local.name
  cidr               = "10.0.0.0/16"
  azs                = ["${var.region}a", "${var.region}b"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  tags               = local.tags
}

# EKS (managed node group demo)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      labels         = { role = "workers" }
      tags           = local.tags
    }
  }

  # Core addons (managed by AWS)
  cluster_addons = {
    vpc-cni    = { most_recent = true }
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
  }

  tags = local.tags
}



# ECR repository for image builds
resource "aws_ecr_repository" "ml_service" {
  name = "${local.name}-ml-service"
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}
