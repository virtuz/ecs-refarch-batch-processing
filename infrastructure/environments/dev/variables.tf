# variables.tf
variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "ecs-refarch-batch-processing"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "docker_image" {
  description = "Docker image to use for the ECS task"
  type        = string
  default     = "435236256477.dkr.ecr.us-west-2.amazonaws.com/ecs-refarch-batch-processing-ecr-dev:feature-github-actions-terraform-7d86475"
}