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
# myS3InputBucket - An S3 bucket where objects (images with a .jpg suffix) can be uploaded to trigger the resize.
module "input_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.5.0"
  bucket  = "${var.project_name}-input-${var.environment}"
}
# myS3OutputBucket - An S3 bucket where resized objects are stored with keys thumbs/ and resized/.
module "output_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.5.0"
  bucket  = "${var.project_name}-output-${var.environment}"
}
# SQSQueue - A SQS queue that holds messages containing the name of the uploaded object.
# SQSDeadLetterQueue - A SQS dead letter queue for messages that was unsuccessfully handled.
module "sqs" {
  source              = "terraform-aws-modules/sqs/aws"
  version             = "5.0.0"
  name                = "${var.project_name}-sqs-${var.environment}"
  create_dlq          = true
  create_queue_policy = true
  queue_policy_statements = {
    s3 = {
      sid    = "Allow-send-message-from-S3"
      effect = "Allow"
      principals = [{
        type        = "*"
        identifiers = ["*"]
      }]
      actions = ["sqs:SendMessage"]
      conditions = [{
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = ["arn:aws:s3:::${module.input_s3_bucket.s3_bucket_id}"]
      }]
    }
  }
}
