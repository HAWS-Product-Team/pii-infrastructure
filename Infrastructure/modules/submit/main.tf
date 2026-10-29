resource "aws_dynamodb_table" "tickets" {
  name         = "${var.app_name}-tickets-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ticket_id"

  attribute {
    name = "ticket_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.app_name}-tickets-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "submit_lambda" {
  name              = "/aws/lambda/${var.app_name}-submit-${var.environment}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name        = "/aws/lambda/${var.app_name}-submit-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "submit_lambda_role" {
  name = "${var.app_name}-submit-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-submit-lambda-role-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "submit_lambda_policy" {
  name        = "${var.app_name}-submit-lambda-policy-${var.environment}"
  description = "IAM policy for submit Lambda to access DynamoDB, S3 uploads prefix, and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.submit_lambda.arn,
          "${aws_cloudwatch_log_group.submit_lambda.arn}:*"
        ]
      },
      {
        Sid    = "DynamoDBTicketAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.tickets.arn
      },
      {
        Sid    = "S3PresignedPutScope"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.uploads_bucket_arn}/uploads/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "submit_lambda_policy_attach" {
  role       = aws_iam_role.submit_lambda_role.name
  policy_arn = aws_iam_policy.submit_lambda_policy.arn
}

resource "aws_lambda_function" "submit" {
  function_name = "${var.app_name}-submit-${var.environment}"
  description   = "Submit Lambda handler for session inception and presigned URL generation"

  s3_bucket = var.uploads_bucket_name
  s3_key    = var.submit_lambda_s3_key

  handler     = "submit.lambda_handler.handler"
  runtime     = "python3.12"
  memory_size = 256
  timeout     = 15
  role        = aws_iam_role.submit_lambda_role.arn

  architectures = ["arm64"]

  ephemeral_storage {
    size = 512
  }

  environment {
    variables = {
      TICKETS_TABLE_NAME       = aws_dynamodb_table.tickets.name
      UPLOADS_BUCKET_NAME      = var.uploads_bucket_name
      MAX_FILES                = tostring(var.max_files)
      MAX_TOTAL_BYTES          = tostring(var.max_total_bytes)
      PRESIGNED_EXPIRY_SECONDS = tostring(var.presigned_expiry_seconds)
      TICKET_TTL_SECONDS       = tostring(var.ticket_ttl_seconds)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.submit_lambda,
    aws_iam_role_policy_attachment.submit_lambda_policy_attach
  ]

  tags = {
    Name        = "${var.app_name}-submit-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
