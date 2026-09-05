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
  type = string
}

variable "existing_subnet_ids" {
  description = "IDs of existing public subnets with internet connectivity via IGW"
  type        = list(string)

  validation {
    condition = (
      (var.existing_vpc_id != null && var.existing_subnet_ids != null && length(var.existing_subnet_ids) >= 2)
    )
    error_message = "Set both existing_vpc_id and existing_subnet_ids (min 2), or set neither."
  }
}

variable "use_fargate_spot" {
  description = "Whether to use Fargate Spot for Batch compute environment"
  type        = bool
  default     = true
}

variable "fargate_platform_version" {
  description = "Fargate platform version for Batch jobs"
  type        = string
  default     = "LATEST"
}

variable "batch_max_vcpus" {
  description = "Maximum vCPUs for Batch compute environment"
  type        = number
  default     = 16
}

variable "job_vcpu" {
  description = "vCPUs for the Batch job"
  type        = number
  default     = 2

  validation {
    condition     = contains([2, 4, 8, 16], var.job_vcpu)
    error_message = "job_vcpu must be one of 2, 4, 8, or 16."
  }
}

variable "job_memory_mb" {
  description = "Memory for the Batch job"
  type        = number
  default     = 4096

  validation {
    # 2 vCPU: 4096–16384 MB in 1024 MB increments
    # 4 vCPU: 8192–30720 MB in 1024 MB increments
    # 8 vCPU: 16384–61440 MB in 4096 MB increments
    # 16 vCPU: 32768–122880 MB in 8192 MB increments
    condition = (
      var.job_vcpu == 2 ? (var.job_memory_mb >= 4096 && var.job_memory_mb <= 16384 && var.job_memory_mb % 1024 == 0) :
      var.job_vcpu == 4 ? (var.job_memory_mb >= 8192 && var.job_memory_mb <= 30720 && var.job_memory_mb % 1024 == 0) :
      var.job_vcpu == 8 ? (var.job_memory_mb >= 16384 && var.job_memory_mb <= 61440 && var.job_memory_mb % 4096 == 0) :
      var.job_vcpu == 16 ? (var.job_memory_mb >= 32768 && var.job_memory_mb <= 122880 && var.job_memory_mb % 8192 == 0) :
      true # Allow other vCPU values if they weren't explicitly restricted by the story but we restricted them above anyway
    )
    error_message = "job_memory_mb is not a supported Fargate value for the chosen job_vcpu."
  }
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

variable "normalizer_lambda_s3_key" {
  description = "S3 key for the Normalizer Lambda deployment package in the input bucket"
  type        = string
  default     = "lambdas/normalizer.zip"
}

variable "normalizer_lambda_runtime" {
  description = "Runtime for the Normalizer Lambda function"
  type        = string
  default     = "python3.12"
}

variable "normalizer_lambda_handler" {
  description = "Handler for the Normalizer Lambda function"
  type        = string
  default     = "pdf2csv.lambda_handler.handler"
}

# A good default for native PDF text extraction with pypdf, S3 read/write, and a 32 MB max PDF input size.
#If the Lambda will process multiple PDFs per invocation from an S3 prefix, I’d use:
#| Workload                             | Memory    | Timeout
#| Small uploads, 1–5 PDFs (around 1MB) | 1024 MB   | 60 sec
#| Typical batch, 5–25 PDFs             | 1536 MB   | 2–3 min
#| Larger batch, many PDFs near 32 MB   | 2048 MB   | 5 min

variable "normalizer_lambda_memory_size" {
  description = "Memory size (MB) for the Normalizer Lambda function"
  type        = number
  default     = 1536
}

# timeout = 3 min * 60s
variable "normalizer_lambda_timeout_seconds" {
  description = "Timeout (seconds) for the Normalizer Lambda function"
  type        = number
  default     = 180
}

variable "pii_calculator_lambda_s3_key" {
  description = "S3 key for the PIICalculator Lambda deployment package in the input bucket"
  type        = string
  default     = "lambdas/pii-calculator.zip"
}

variable "pii_calculator_lambda_runtime" {
  description = "Runtime for the PIICalculator Lambda function"
  type        = string
  default     = "python3.12"
}

variable "pii_calculator_lambda_handler" {
  description = "Handler for the PIICalculator Lambda function"
  type        = string
  default     = "piicalculator.lambda_handler.handler"
}

variable "pii_calculator_lambda_memory_size" {
  description = "Memory size (MB) for the PIICalculator Lambda function"
  type        = number
  default     = 256
}

variable "pii_calculator_lambda_timeout_seconds" {
  description = "Timeout (seconds) for the PIICalculator Lambda function"
  type        = number
  default     = 300
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention in days for PIICalculator Lambda"
  type        = number
  default     = 3
}

variable "step_functions_log_retention_days" {
  description = "CloudWatch log retention in days for Step Functions State Machine"
  type        = number
  default     = 3
}