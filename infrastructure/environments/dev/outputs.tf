# For other modules that need ECR references
output "ecr_repository_url" {
  description = "ECR repository URL for Docker images"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = module.ecr.repository_name
}

output "s3_input_bucket_name" {
  description = "S3 bucket name for input images"
  value       = module.input_s3_bucket.s3_bucket_id
}
