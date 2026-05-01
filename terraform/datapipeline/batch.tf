resource "aws_batch_compute_environment" "batch_ce" {
  compute_environment_name = "${var.app_name}-batch-ce-${var.environment}"

  compute_resources {
    allocation_strategy = var.batch_allocation_strategy
    instance_role       = aws_iam_instance_profile.batch_instance_profile.arn

    # broad eligibility for Graviton ARM64
    instance_type = ["c6g.large", "c7g.large", "c8g.large", "m6g.large", "m7g.large", "m8g.large"]

    max_vcpus = var.batch_max_vcpus
    desired_vcpus = var.batch_desired_vcpus
    min_vcpus = var.batch_min_vcpus

    security_group_ids = [aws_security_group.batch_sg.id]
    subnets            = local.subnet_ids
    type               = "SPOT"
  }

  service_role = aws_iam_role.batch_service_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.batch_service_role]
}

# Adjusting compute_resources to better match Graviton ARM64 requirement
# Since the story says: "Allow broad Graviton ARM64 instance eligibility across compute-optimized and memory-optimized families."
# and "Use allocation strategy SPOT_PRICE_CAPACITY_OPTIMIZED."

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
  name = "${var.app_name}-batch-jobdef-${var.environment}"
  type = "container"

  container_properties = <<EOF
{
    "image": "${aws_ecr_repository.app.repository_url}:latest",
    "resourceRequirements": [
        {"type": "VCPU", "value": "${tostring(var.job_vcpu)}"},
        {"type": "MEMORY", "value": "${tostring(var.job_memory_mb)}"}
    ],
    "jobRoleArn": "${aws_iam_role.batch_job_role.arn}",
    "executionRoleArn": "${aws_iam_role.batch_job_role.arn}",
    "environment": [
        {"name": "INPUT_S3_URI", "value": ""},
        {"name": "OUTPUT_S3_URI", "value": ""},
        {"name": "MODEL_ID", "value": "${var.model_id}"}
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.batch.name}",
            "awslogs-region": "${var.aws_region}",
            "awslogs-stream-prefix": "batch"
        }
    }
}
EOF

  timeout {
    attempt_duration_seconds = var.job_timeout_seconds
  }

  retry_strategy {
    attempts = var.job_retry_attempts
  }
}
