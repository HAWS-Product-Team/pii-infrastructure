data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/vendedlogs/states/${var.app_name}-data-pipeline-${var.environment}"
  retention_in_days = var.step_functions_log_retention_days

  tags = {
    Name        = "/aws/vendedlogs/states/${var.app_name}-data-pipeline-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "step_functions_role" {
  name = "${var.app_name}-step-functions-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-step-functions-role-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "step_functions_policy" {
  name        = "${var.app_name}-step-functions-policy-${var.environment}"
  description = "IAM policy for Step Functions to orchestrate Batch and Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "batch:SubmitJob",
          "batch:DescribeJobs",
          "batch:TerminateJob"
        ]
        Resource = [
          aws_batch_job_queue.batch_queue.arn,
          "${aws_batch_job_definition.batch_job.arn_prefix}:*",
          "arn:aws:batch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:job/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ]
        Resource = [
          "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForBatchJobsRule"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.batch_execution_role.arn,
          aws_iam_role.batch_job_role.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.normalizer.arn,
          "${aws_lambda_function.normalizer.arn}:*",
          aws_lambda_function.pii_calculator.arn,
          "${aws_lambda_function.pii_calculator.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.step_functions.arn,
          "${aws_cloudwatch_log_group.step_functions.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_functions_policy_attach" {
  role       = aws_iam_role.step_functions_role.name
  policy_arn = aws_iam_policy.step_functions_policy.arn
}

resource "aws_sfn_state_machine" "data_pipeline" {
  name     = "${var.app_name}-data-pipeline-${var.environment}"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "Data Pipeline State Machine orchestrating Normalizer Lambda, Batch Classifier, and PIICalculation Lambda"
    StartAt = "Normalize"
    States = {
      Normalize = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.normalizer.arn
          Payload = {
            "input-s3-uri.$"  = "$.uploads"
            "output-s3-uri.$" = "$.uploads"
          }
        }
        ResultPath = "$.normalizerResult"
        Retry = [
          {
            ErrorEquals = [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException",
              "Lambda.TooManyRequestsException"
            ]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Next = "Classify"
      }
      Classify = {
        Type     = "Task"
        Resource = "arn:aws:states:::batch:submitJob.sync"
        Parameters = {
          # tickets can only have digits, letters, dashes, underbars for it to be a jobname.
          "JobName.$"   = "States.Format('classify-{}', $.ticket)"
          JobQueue      = aws_batch_job_queue.batch_queue.arn
          JobDefinition = aws_batch_job_definition.batch_job.arn
          Parameters = {
            "input_s3_uri.$"  = "$.inputCsv"
            "output_s3_uri.$" = "$.classifiedCsv"
          }
        }
        ResultPath = "$.batchResult"
        Retry = [
          {
            ErrorEquals     = ["Batch.AWSBatchException"]
            IntervalSeconds = 30
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
        Next = "CalculatePII"
      }
      CalculatePII = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.pii_calculator.arn
          Payload = {
            "ticket.$"        = "$.ticket"
            "input-s3-uri.$"  = "$.classifiedCsv"
            "output-s3-uri.$" = "$.piiReportJson"
          }
        }
        ResultPath = "$.lambdaResult"
        Retry = [
          {
            ErrorEquals = [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException",
              "Lambda.TooManyRequestsException"
            ]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        End = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Name        = "${var.app_name}-data-pipeline-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.step_functions_policy_attach,
    aws_cloudwatch_log_group.step_functions
  ]
}
