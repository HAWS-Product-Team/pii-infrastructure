resource "aws_api_gateway_rest_api" "pii_api" {
  name = "${var.app_name}-${var.environment}-api"
}

# Luke, I commented out the below because it was causing my plan to fail. For some reason it expects
# an integration to be defined for the resource.  I'm not sure why I need one for this resource.
# I'll need to look at your old plan to figure out how it worked in the past without an integration defined, or it had
# one and I lost it when moving your work into this plan.
# Claude: Alternatively, if /submit is meant to eventually forward to SQS (which your IAM role apigw_sqs_role suggests),
# you'd replace the mock with an AWS type integration pointing at the SQS queue — but the mock unblocks you now and
# you can swap it out later.

# Luke's API, defines the path
# resource "aws_api_gateway_resource" "submit" {
#   rest_api_id = aws_api_gateway_rest_api.pii_api.id
#   parent_id   = aws_api_gateway_rest_api.pii_api.root_resource_id
#   path_part   = "submit"
# }
#
# # Luke's API, defines the method
# resource "aws_api_gateway_method" "submit_post" {
#   rest_api_id   = aws_api_gateway_rest_api.pii_api.id
#   resource_id   = aws_api_gateway_resource.submit.id
#   http_method   = "POST"
#   authorization = "NONE"
# }

resource "aws_iam_role" "apigw_sqs_role" {
  name = "${var.app_name}-${var.environment}-apigw-sqs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "apigateway.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "apigw_sqs_policy" {
  name = "sqs-send-message"
  role = aws_iam_role.apigw_sqs_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "sqs:SendMessage"
      ]

      Resource = var.sqs_queue_arn
    }]
  })
}

# Endpoint 1: Welcome Page (Root)
resource "aws_api_gateway_method" "welcome_get" {
  rest_api_id   = aws_api_gateway_rest_api.pii_api.id
  resource_id   = aws_api_gateway_rest_api.pii_api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

# Endpoint 2: Submit Spending History (/spending-history)
resource "aws_api_gateway_resource" "spending_history" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  parent_id   = aws_api_gateway_rest_api.pii_api.root_resource_id
  path_part   = "spending-history"
}

resource "aws_api_gateway_method" "spending_history_post" {
  rest_api_id   = aws_api_gateway_rest_api.pii_api.id
  resource_id   = aws_api_gateway_resource.spending_history.id
  http_method   = "POST"
  authorization = "NONE"
}

# Endpoint 3: Processing Screen (/pii-report-status)
resource "aws_api_gateway_resource" "pii_report_status" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  parent_id   = aws_api_gateway_rest_api.pii_api.root_resource_id
  path_part   = "pii-report-status"
}

# Lambda Authorizer Mock
resource "aws_iam_role" "authorizer_role" {
  name = "${var.app_name}-${var.environment}-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_lambda_function" "authorizer" {
  filename      = "${path.module}/authorizer.zip"
  function_name = "${var.app_name}-${var.environment}-authorizer"
  role          = aws_iam_role.authorizer_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  source_code_hash = filebase64sha256("${path.module}/authorizer.zip")
}

resource "aws_api_gateway_authorizer" "bearer_auth" {
  name                   = "BearerAuth"
  rest_api_id            = aws_api_gateway_rest_api.pii_api.id
  authorizer_uri         = aws_lambda_function.authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.invocation_role.arn
  type                   = "TOKEN"
  identity_source        = "method.request.header.Authorization"
}

resource "aws_iam_role" "invocation_role" {
  name = "${var.app_name}-${var.environment}-authorizer-invocation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "invocation_policy" {
  name = "default"
  role = aws_iam_role.invocation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "lambda:InvokeFunction"
      Effect   = "Allow"
      Resource = aws_lambda_function.authorizer.arn
    }]
  })
}

resource "aws_api_gateway_method" "pii_report_status_get" {
  rest_api_id   = aws_api_gateway_rest_api.pii_api.id
  resource_id   = aws_api_gateway_resource.pii_report_status.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.bearer_auth.id
}

# Deployment & Stage
resource "aws_api_gateway_deployment" "pii_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id

  # triggers define what triggers re-creation of resources. By adding the below, if those blocks change, terraform
  # will be triggered to redeployment.  API Gateway provider has this special case that we need to set this up.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.welcome_get,
      aws_api_gateway_method.spending_history_post,
      aws_api_gateway_method.pii_report_status_get,
      aws_api_gateway_integration.welcome_mock,
      aws_api_gateway_integration.spending_history_mock,
      aws_api_gateway_integration.pii_report_status_mock
    ]))
  }

  # Wait for the integrations to be created
  depends_on = [
    aws_api_gateway_integration.welcome_mock,
    aws_api_gateway_integration.spending_history_mock,
    aws_api_gateway_integration.pii_report_status_mock
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "pii_api_stage" {
  deployment_id = aws_api_gateway_deployment.pii_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.pii_api.id
  stage_name    = var.environment
}