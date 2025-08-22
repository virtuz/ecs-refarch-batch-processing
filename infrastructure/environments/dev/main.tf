module "ecr" {
  source                          = "terraform-aws-modules/ecr/aws"
  version                         = "3.0.0"
  repository_name                 = "${var.project_name}-ecr-${var.environment}"
  repository_image_tag_mutability = "MUTABLE"
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
# myS3OutputBucket - An S3 bucket where resized objects are stored with keys thumbs/ and resized/.
module "output_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.5.0"
  bucket  = "${var.project_name}-output-${var.environment}"
}
# SQSQueue - A SQS queue that holds messages containing the name of the uploaded object.
module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "5.0.0"
  name    = "${var.project_name}-sqs-${var.environment}"
  # SQSDeadLetterQueue - A SQS dead letter queue for messages that was unsuccessfully handled.
  create_dlq = true
}
# ECSCluster - An ECS cluster.
data "aws_subnets" "default" {}
module "ecs" {
  source       = "terraform-aws-modules/ecs/aws"
  version      = "6.2.2"
  cluster_name = "${var.project_name}-ecs-${var.environment}"
  services = {
    # ###Step 4: Create the ECS Service Go to the ECS Console in your AWS Account and create an ECS Service choosing the ECS Cluster and Task definition created by the CloudFormation template. Give the service a name and set the number of desired tasks to deploy as part of the service. For this example, you can configure the basic service parameters.
    image_processing = {
      subnet_ids = sort(data.aws_subnets.default.ids)

      task_exec_iam_role_name = "ECSTaskExecRole" # This role allows Amazon ECS to use other AWS services on your behalf.
      # ECSTaskRole - An IAM role assumed by the ECS task. This role gives the Docker container the right to upload and fetch objects to and from S3 as well as read and delete messages from the SQS queue. By using an ECS task role, the underlying EC2 instances do not need to be given access rights to the resources that the container uses. For more information about IAM roles for tasks, see IAM Roles for Tasks.
      tasks_iam_role_name = "ECSTaskRole" # This role allows your application code (on the container) to use other AWS services.
      tasks_iam_role_statements = [{
        sid       = "S3ReadAccess"
        effect    = "Allow"
        actions   = ["s3:GetObject"]
        resources = ["*"]
        },
        {
          sid       = "S3WriteAccess"
          effect    = "Allow"
          actions   = ["s3:PutObject"]
          resources = ["arn:aws:s3:::${module.output_s3_bucket.s3_bucket_id}/*"]
        },
        {
          sid    = "SQSReadAccess"
          effect = "Allow"
          actions = [
            "sqs:ListQueues",
            "sqs:GetQueueUrl",
          ]
          resources = ["*"]
        },
        {
          sid    = "SQSWriteAccess"
          effect = "Allow"
          actions = [
            "sqs:DeleteMessage",
            "sqs:ReceiveMessage",
            "sqs:ChangeMessageVisibility",
          ]
          resources = [module.sqs.queue_arn]
        }
      ]
      enable_autoscaling = true
      # ###Step 5: Update the ECS Service to configure Auto Scaling In this step you will configure auto scaling for the service you created in step 4.
      autoscaling_policies = {
        queue_depth = {
          name        = "step5"
          policy_type = "StepScaling"
          step_scaling_policy_configuration = {
            adjustment_type          = "ChangeInCapacity"
            cooldown                 = 60
            metric_aggregation_type  = "Average"
            min_adjustment_magnitude = 0
            step_adjustment = [
              {
                metric_interval_lower_bound = 0
                scaling_adjustment          = 1
              }
            ]
          }
        }
      }
      # TaskDefinition - An ECS task definition that is started by the ECS service. The ECS task schedules a Docker container that copies the uploaded object and creates a thumbnail and a resized (1024x768) image file in the output S3 bucket.
      container_definitions = {
        worker = {
          cpu                    = 10
          memory                 = 300
          essential              = true
          image                  = var.docker_image
          readonlyRootFilesystem = false
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
  alarm_actions      = [module.ecs.services.image_processing.autoscaling_policies.queue_depth.arn]
}
# Did not created below mentioned resources since task runs on fargate instead of ec2
# ECSAutoScalingGroup - An Auto Scaling group used to create your instances.
# InstanceSecurityGroup - Security Group to which your instances are added.
# ECSServiceRole - An IAM role assumed by the ECS service, which gives the service the right to register instances to an Elastic Load Balancer if needed.
# EC2Role - An IAM role assumed by the EC2 instances, which gives them the right to register themselves with the ECS services.
