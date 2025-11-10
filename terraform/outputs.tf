output "cluster_name"   { value = module.eks.cluster_name }
output "cluster_arn"    { value = module.eks.cluster_arn }
output "ecr_repository" { value = aws_ecr_repository.ml_service.repository_url }
