module "ecr" {
  source          = "terraform-aws-modules/ecr/aws"
  version         = "3.0.0"
  repository_name = "${var.project_name}-ecr-${var.environment}"
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}
