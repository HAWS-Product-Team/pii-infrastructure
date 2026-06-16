resource "aws_sqs_queue" "pii_queue" {
  name = "${var.app_name}-${var.environment}-queue"
}