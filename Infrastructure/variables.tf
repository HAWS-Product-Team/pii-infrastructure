variable "amplify_github_token" {
  description = "GitHub token used by Amplify to access the application repository"
  type        = string
  sensitive   = true
}

variable "app_name" {
  description = "Application name used for shared infrastructure naming"
  type        = string
  default     = "pii"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for resources in this root module"
  type        = string
  default     = "us-east-1"
}

variable "submit_lambda_s3_key" {
  description = "S3 key for the submit Lambda deployment package in the input bucket"
  type        = string
  default     = "lambdas/submit.zip"
}

