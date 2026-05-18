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

