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
# ###Step 3: Create the S3 event trigger for the SQS queue
# Go to the S3 Console in your AWS Account and select the S3 Input Bucket that the CloudFormation template created and go to Properties -> Events.
# Configure an event notification to the SQS queue called SQSBatchQueue for the ObjectCreated (All) event and in the Suffix field enter "jpg".
# You can learn more about configuring S3 event notifications [here](http://docs.aws.amazon.com/AmazonS3/latest/dev/NotificationHowTo.html).
module "input_s3_bucket_notification" {
  source  = "terraform-aws-modules/s3-bucket/aws//modules/notification"
  version = "5.5.0"
  bucket  = module.input_s3_bucket.s3_bucket_id
  sqs_notifications = {
    sqs = {
      queue_arn     = module.sqs.queue_arn
      events        = ["s3:ObjectCreated:*"]
      filter_suffix = ".jpg"
    }
  }
}
# resource "aws_s3_bucket_notification" "bucket_notification" {
#   bucket = aws_s3_bucket.bucket.id

#   queue {
#     queue_arn     = aws_sqs_queue.queue.arn
#     events        = ["s3:ObjectCreated:*"]
#     filter_suffix = ".log"
#   }
# }
# myS3OutputBucket - An S3 bucket where resized objects are stored with keys thumbs/ and resized/.
module "output_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.5.0"
  bucket  = "${var.project_name}-output-${var.environment}"
}
# SQSQueue - A SQS queue that holds messages containing the name of the uploaded object.
# SQSDeadLetterQueue - A SQS dead letter queue for messages that was unsuccessfully handled.
module "sqs" {
  source     = "terraform-aws-modules/sqs/aws"
  version    = "5.0.0"
  name       = "${var.project_name}-sqs-${var.environment}"
  create_dlq = true
  # create_queue_policy = true
  # queue_policy_statements = {
  #   s3 = {
  #     sid    = "Allow-send-message-from-S3"
  #     effect = "Allow"
  #     principals = [{
  #       type        = "*"
  #       identifiers = ["*"]
  #     }]
  #     actions = ["sqs:SendMessage"]
  #     conditions = [{
  #       test     = "ArnLike"
  #       variable = "aws:SourceArn"
  #       values   = ["arn:aws:s3:::${module.input_s3_bucket.s3_bucket_id}"]
  #     }]
  #   }
  # }
}
# ECSCluster - An ECS cluster.
# TaskDefinition - An ECS task definition that is started by the ECS service. The ECS task schedules a Docker container that copies the uploaded object and creates a thumbnail and a resized (1024x768) image file in the output S3 bucket.
# ###Step 4: Create the ECS Service Go to the ECS Console in your AWS Account and create an ECS Service choosing the ECS Cluster and Task definition created by the CloudFormation template. Give the service a name and set the number of desired tasks to deploy as part of the service. For this example, you can configure the basic service parameters.
data "aws_subnets" "default" {}
module "ecs" {
  source       = "terraform-aws-modules/ecs/aws"
  version      = "6.2.2"
  cluster_name = "${var.project_name}-ecs-${var.environment}"
  services = {
    image_processing = {
      subnet_ids = sort(data.aws_subnets.default.ids)
      # create_task_exec_policy = false
      # create_security_group = false
      enable_autoscaling = false
      # autoscaling_policies = {
      #   queue_depth = {
      #     policy_type = "TargetTrackingScaling"
      #     target_tracking_scaling_policy_configuration = {

      #     }
      #   }
      # }
      container_definitions = {
        worker = {
          cpu       = 10
          memory    = 300
          essential = true
          image     = var.docker_image
          environment = [
            {
              name  = "s3OutputBucket"
              value = module.output_s3_bucket.s3_bucket_id
            },
            {
              name  = "s3InputBucket"
              value = module.input_s3_bucket.s3_bucket_id
            },
            {
              name  = "AWSRegion"
              value = var.aws_region
            },
            {
              name  = "SQSBatchQueue"
              value = module.sqs.queue_name
            }
          ]
        }
      }
      security_group_egress_rules = {
        all = {
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }
    }
  }
}
# SQSCloudWatchAlarm - A CloudWatch Alarm for the SQS queue for the ApproximateNumberOfMessagesVisible metric.
module "metric_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.1"

  alarm_description   = "Scale ECS Service based on SQS queue depth"
  alarm_name          = "SQSQueueDepth"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    QueueName = module.sqs.queue_name
  }
  evaluation_periods = 1
  metric_name        = "ApproximateNumberOfMessagesVisible"
  namespace          = "AWS/SQS"
  period             = 60
  statistic          = "Average"
  threshold          = 5
  unit               = "Count"
  alarm_actions      = ["arn:aws:autoscaling:us-west-2:435236256477:scalingPolicy:93b8e209-d4d3-43f3-b894-c071cc669e4b:resource/ecs/service/ecs-refarch-batch-processing-ecs-dev/image_processing:policyName/step5"] # manually created
  # lifecycle {
  #   ignore_changes = [alarm_actions]
  # }

}
# ECSAutoScalingGroup - An Auto Scaling group used to create your instances.
# InstanceSecurityGroup - Security Group to which your instances are added.
# ECSServiceRole - An IAM role assumed by the ECS service, which gives the service the right to register instances to an Elastic Load Balancer if needed.
# EC2Role - An IAM role assumed by the EC2 instances, which gives them the right to register themselves with the ECS services.
# ECSTaskRole - An IAM role assumed by the ECS task. This role gives the Docker container the right to upload and fetch objects to and from S3 as well as read and delete messages from the SQS queue. By using an ECS task role, the underlying EC2 instances do not need to be given access rights to the resources that the container uses. For more information about IAM roles for tasks, see IAM Roles for Tasks.
