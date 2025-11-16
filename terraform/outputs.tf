output "cluster_name" { value = module.eks.cluster_name }
output "cluster_region" { value = var.region }
output "vpc_id" { value = module.vpc.vpc_id }
output "alb_controller_role_arn" { value = aws_iam_role.alb_controller.arn }
# output "cluster_endpoint" { value = module.eks.cluster_endpoint }
# output "cluster_ca" { value = module.eks.cluster_certificate_authority_data }
output "ecr_repository" { value = aws_ecr_repository.ml_service.repository_url }
