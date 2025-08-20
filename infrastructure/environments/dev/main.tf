module "ecr" {
  source          = "terraform-aws-modules/ecr/aws"
  version         = "3.0.0"
  repository_name = "${var.project_name}-ecr-${var.environment}"
}
