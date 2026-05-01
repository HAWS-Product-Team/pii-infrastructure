variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "existing_vpc_id" {
  type    = string
}

variable "existing_subnet_ids" {
  type    = list(string)

  validation {
    condition = (
      (var.existing_vpc_id != null && var.existing_subnet_ids != null && length(var.existing_subnet_ids) >= 2)
    )
    error_message = "Set both existing_vpc_id and existing_subnet_ids (min 2), or set neither."
  }
}

variable "batch_min_vcpus" {
  description = "Minimum vCPUs for Batch compute environment"
  type        = number
  default     = 0
}

variable "batch_desired_vcpus" {
  description = "Desired vCPUs for Batch compute environment"
  type        = number
  default     = 0
}

variable "batch_max_vcpus" {
  description = "Maximum vCPUs for Batch compute environment"
  type        = number
  default     = 16
}

variable "batch_allocation_strategy" {
  description = "Allocation strategy for Batch compute environment"
  type        = string
  default     = "SPOT_PRICE_CAPACITY_OPTIMIZED"
}

variable "batch_instance_architecture" {
  description = "Architecture for Batch compute environment"
  type        = string
  default     = "arm64"
}

variable "batch_allowed_instance_families" {
  description = "Allowed instance families for Batch compute environment"
  type        = list(string)
  default     = ["c", "m"]
}

variable "batch_allowed_instance_generations" {
  description = "Allowed instance generations for Batch compute environment"
  type        = list(string)
  default     = ["6g", "7g", "8g"]
}

variable "batch_min_instance_size" {
  description = "Minimum instance size for Batch compute environment"
  type        = string
  default     = "large"
}

variable "batch_use_optimal_instance_classes" {
  description = "Whether to use optimal instance classes for Batch compute environment"
  type        = bool
  default     = true
}

variable "job_vcpu" {
  description = "vCPUs for the Batch job"
  type        = number
  default     = 2
}

variable "job_memory_mb" {
  description = "Memory for the Batch job"
  type        = number
  default     = 4096
}

variable "job_timeout_seconds" {
  description = "Timeout for the Batch job"
  type        = number
  default     = 1800
}

variable "job_retry_attempts" {
  description = "Retry attempts for the Batch job"
  type        = number
  default     = 1
}

variable "input_key_prefix" {
  description = "Prefix for S3 input bucket"
  type        = string
  default     = "input/"
}

variable "output_key_prefix" {
  description = "Prefix for S3 output bucket"
  type        = string
  default     = "output/"
}

variable "input_retention_days" {
  description = "Retention period for S3 input bucket"
  type        = number
  default     = 2
}

variable "output_retention_days" {
  description = "Retention period for S3 output bucket"
  type        = number
  default     = 14
}

variable "model_id" {
  description = "Model ID to download from Hugging Face"
  type        = string
  default     = "google/flan-t5-small" # POC default
}
