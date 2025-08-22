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

output "cloudwatch_metric_alarm_id" {
  description = "CloudWatch metric alarm ID"
  value       = module.metric_alarm.cloudwatch_metric_alarm_id
}

output "subnets" {
  description = "List of subnets in the VPC"
  value       = sort(data.aws_subnets.default.ids)
}

output "ecs_autoscaling_policy_arn" {
  description = "ARN of the ECS service autoscaling policy"
  value       = module.ecs.services.image_processing.autoscaling_policies.queue_depth.arn
}

output "ecs_autoscaling_policies" {
  description = "ECS service autoscaling policies"
  value       = module.ecs.services.image_processing.autoscaling_policies
}
