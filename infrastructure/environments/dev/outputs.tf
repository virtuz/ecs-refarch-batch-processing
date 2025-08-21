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

output "s3_output_bucket_name" {
  description = "S3 bucket name for output images"
  value       = module.output_s3_bucket.s3_bucket_id
}

output "sqs_queue_name" {
  description = "SQS queue name"
  value       = module.sqs.queue_name
}

output "sqs_dead_letter_queue_name" {
  description = "SQS dead letter queue name"
  value       = module.sqs.dead_letter_queue_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}
