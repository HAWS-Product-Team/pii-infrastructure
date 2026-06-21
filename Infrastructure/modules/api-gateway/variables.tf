variable "app_name" {
  type        = string
  description = "Application name"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable sqs_queue_arn {
  type = string
  description = "ARN to queue"
}