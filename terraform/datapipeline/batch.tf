resource "aws_batch_compute_environment" "batch_ce" {
  compute_environment_name = "${var.app_name}-batch-ce-fargate-${var.environment}"

  compute_resources {
    max_vcpus = var.batch_max_vcpus

    security_group_ids = [aws_security_group.batch_sg.id]
    subnets            = local.subnet_ids
    type               = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
  }

  service_role = aws_iam_role.batch_service_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.batch_service_role]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_batch_job_queue" "batch_queue" {
  name     = "${var.app_name}-batch-queue-${var.environment}"
  state    = "ENABLED"
  priority = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.batch_ce.arn
  }
}

resource "aws_batch_job_definition" "batch_job" {
  name = "${var.app_name}-batch-jobdef-fargate-${var.environment}"
  type = "container"

  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image = "${aws_ecr_repository.app.repository_url}:latest"
    fargatePlatformConfiguration = {
      platformVersion = var.fargate_platform_version
    }
    resourceRequirements = [
      { type = "VCPU", value = tostring(var.job_vcpu) },
      { type = "MEMORY", value = tostring(var.job_memory_mb) }
    ]
    jobRoleArn       = aws_iam_role.batch_job_role.arn
    executionRoleArn = aws_iam_role.batch_execution_role.arn
    environment = [
      { name = "INPUT_S3_URI", value = "" },
      { name = "OUTPUT_S3_URI", value = "" },
      { name = "MODEL_ID", value = var.model_id }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.batch.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "batch"
      }
    }
    runtimePlatform = {
      operatingSystemFamily = "LINUX"
      cpuArchitecture       = "ARM64"
    }
    networkConfiguration = {
      assignPublicIp = "ENABLED"
    }
  })

  timeout {
    attempt_duration_seconds = var.job_timeout_seconds
  }

  retry_strategy {
    attempts = var.job_retry_attempts
  }
}
