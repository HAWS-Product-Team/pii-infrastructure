variable "app_name" {
  description = "Application name prefix"
  type        = string
  default     = "pii"
}

variable "environment" {
  description = "Target deployment environment"
  type        = string
  default     = "dev"
}

variable "uploads_bucket_name" {
  description = "Target S3 bucket name for batch uploads"
  type        = string
}

variable "uploads_bucket_arn" {
  description = "ARN of target S3 bucket for uploads"
  type        = string
}

variable "submit_lambda_s3_key" {
  description = "S3 key for the submit Lambda zip package"
  type        = string
  default     = "lambdas/submit.zip"
}

variable "max_files" {
  description = "Maximum PDFs allowed per batch request"
  type        = number
  default     = 20
}

variable "max_total_bytes" {
  description = "Maximum cumulative batch size in bytes (default: 4 GiB)"
  type        = number
  default     = 4294967296
}

variable "presigned_expiry_seconds" {
  description = "Expiration time for presigned upload URLs (default: 15 min)"
  type        = number
  default     = 900
}

variable "ticket_ttl_seconds" {
  description = "Ticket session expiration time in seconds (default: 24 hours)"
  type        = number
  default     = 86400
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 3
}
