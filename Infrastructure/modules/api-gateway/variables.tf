variable "app_name" {
  type        = string
  description = "Application name"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN to queue"
}

variable "submit_lambda_invoke_arn" {
  type        = string
  description = "API Gateway invocation ARN for the submit Lambda function"
}

variable "submit_lambda_function_name" {
  type        = string
  description = "Function name of the submit Lambda function"
}