terraform {
  backend "s3" {
    bucket         = "ecs-refarch-batch-processing-terraform-state-dev-435236256477"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "ecs-refarch-batch-processing-terraform-lock-dev"
    encrypt        = true
  }
}
