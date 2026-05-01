resource "aws_cloudwatch_log_group" "batch" {
  name              = "/aws/batch/${var.app_name}/${var.environment}"
  retention_in_days = 3

  tags = {
    Name        = "/aws/batch/${var.app_name}/${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
