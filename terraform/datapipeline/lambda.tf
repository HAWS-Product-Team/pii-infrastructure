resource "aws_cloudwatch_log_group" "normalizer_lambda" {
  name              = "/aws/lambda/${var.app_name}-normalizer-${var.environment}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name        = "/aws/lambda/${var.app_name}-normalizer-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "normalizer_lambda_role" {
  name = "${var.app_name}-normalizer-lambda-role-${var.environment}"

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
    Name        = "${var.app_name}-normalizer-lambda-role-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "normalizer_lambda_policy" {
  name        = "${var.app_name}-normalizer-lambda-policy-${var.environment}"
  description = "IAM policy for Normalizer Lambda to access S3 and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.normalizer_lambda.arn,
          "${aws_cloudwatch_log_group.normalizer_lambda.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.input.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.input.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "normalizer_lambda_policy_attach" {
  role       = aws_iam_role.normalizer_lambda_role.name
  policy_arn = aws_iam_policy.normalizer_lambda_policy.arn
}

resource "aws_lambda_function" "normalizer" {
  function_name = "${var.app_name}-normalizer-${var.environment}"
  description   = "Normalizer Lambda stage for data pipeline"

  s3_bucket = aws_s3_bucket.input.id
  s3_key    = var.normalizer_lambda_s3_key

  handler     = var.normalizer_lambda_handler
  runtime     = var.normalizer_lambda_runtime
  memory_size = var.normalizer_lambda_memory_size
  timeout     = var.normalizer_lambda_timeout_seconds
  role        = aws_iam_role.normalizer_lambda_role.arn

  depends_on = [
    aws_cloudwatch_log_group.normalizer_lambda,
    aws_iam_role_policy_attachment.normalizer_lambda_policy_attach
  ]

  architectures = ["arm64"]

  tags = {
    Name        = "${var.app_name}-normalizer-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "pii_calculator_lambda" {
  name              = "/aws/lambda/${var.app_name}-pii-calculator-${var.environment}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name        = "/aws/lambda/${var.app_name}-pii-calculator-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "pii_calculator_lambda_role" {
  name = "${var.app_name}-pii-calculator-lambda-role-${var.environment}"

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
    Name        = "${var.app_name}-pii-calculator-lambda-role-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "pii_calculator_lambda_policy" {
  name        = "${var.app_name}-pii-calc-lambda-policy-${var.environment}"
  description = "IAM policy for PIICalculator Lambda to access S3 and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.pii_calculator_lambda.arn,
          "${aws_cloudwatch_log_group.pii_calculator_lambda.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.input.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.output.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "pii_calculator_lambda_policy_attach" {
  role       = aws_iam_role.pii_calculator_lambda_role.name
  policy_arn = aws_iam_policy.pii_calculator_lambda_policy.arn
}

resource "aws_lambda_function" "pii_calculator" {
  function_name = "${var.app_name}-pii-calculator-${var.environment}"
  description   = "PIICalculator Lambda stage for data pipeline"

  s3_bucket = aws_s3_bucket.input.id
  s3_key    = var.pii_calculator_lambda_s3_key

  handler     = var.pii_calculator_lambda_handler
  runtime     = var.pii_calculator_lambda_runtime
  memory_size = var.pii_calculator_lambda_memory_size
  timeout     = var.pii_calculator_lambda_timeout_seconds
  role        = aws_iam_role.pii_calculator_lambda_role.arn

  depends_on = [
    aws_cloudwatch_log_group.pii_calculator_lambda,
    aws_iam_role_policy_attachment.pii_calculator_lambda_policy_attach
  ]

  architectures = ["arm64"]

  tags = {
    Name        = "${var.app_name}-pii-calculator-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
