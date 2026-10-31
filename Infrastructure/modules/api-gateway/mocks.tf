# *****************************************  Mocking  *****************************************
# Mocking of the api gateway endpoints

# Endpoint 1: Welcome Page (/)
resource "aws_api_gateway_integration" "welcome_mock" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_rest_api.pii_api.root_resource_id
  http_method = "GET"
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
  depends_on = [aws_api_gateway_method.welcome_get]
}

resource "aws_api_gateway_method_response" "welcome_200" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_rest_api.pii_api.root_resource_id
  http_method = "GET"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
  depends_on = [aws_api_gateway_method.welcome_get]
}

resource "aws_api_gateway_integration_response" "welcome_mock_response" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_rest_api.pii_api.root_resource_id
  http_method = "GET"
  status_code = aws_api_gateway_method_response.welcome_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  response_templates = {
    "application/json" = jsonencode({
      messages = ["Not welcome my dude! My Inflation Index. Here you can......"],
      links = [
        {
          rel  = "upload"
          href = "/spending-history"
        }
      ]
    })
  }
  depends_on = [aws_api_gateway_integration.welcome_mock]
}

#************* Endpoint 2: Submit Spending History (/spending-history) ******************************
# Mock decommissioned for Story 10; POST /spending-history is now an AWS_PROXY integration to submit Lambda in main.tf

# Endpoint 3: Processing Screen (/pii-report-status)
resource "aws_api_gateway_integration" "pii_report_status_mock" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_resource.pii_report_status.id
  http_method = "GET"
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
  depends_on = [aws_api_gateway_method.pii_report_status_get]
}

resource "aws_api_gateway_method_response" "pii_report_status_200" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_resource.pii_report_status.id
  http_method = "GET"
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
  depends_on = [aws_api_gateway_method.pii_report_status_get]
}

resource "aws_api_gateway_integration_response" "pii_report_status_mock_response" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_resource.pii_report_status.id
  http_method = "GET"
  status_code = aws_api_gateway_method_response.pii_report_status_200.status_code

  response_templates = {
    "application/json" = jsonencode({
      status          = "PROCESSING"
      percentComplete = 72
      links = [
        {
          rel  = "self"
          href = "/pii-report-status"
        }
      ]
    })
  }

  depends_on = [aws_api_gateway_integration.pii_report_status_mock]
}

# Endpoint 4: pii-report (/pii-report)
resource "aws_api_gateway_integration" "pii_report_mock" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_resource.pii_report.id
  http_method = "GET"
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
  depends_on = [aws_api_gateway_method.pii_report_get]
}

resource "aws_api_gateway_method_response" "pii_report_200" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_resource.pii_report.id
  http_method = "GET"
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
  depends_on = [aws_api_gateway_method.pii_report_get]
}

resource "aws_api_gateway_integration_response" "pii_report_mock_response" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_resource.pii_report.id
  http_method = "GET"
  status_code = aws_api_gateway_method_response.pii_report_200.status_code

  response_templates = {
    "application/json" = jsonencode({
      message = "Your personal inflation is 14."
      links = [
        {
          rel  = "self"
          href = "/pii-report"
        }
      ]
    })
  }

  depends_on = [aws_api_gateway_integration.pii_report_mock]
}