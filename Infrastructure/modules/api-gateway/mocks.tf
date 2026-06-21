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

  response_templates = {
    "application/json" = jsonencode({
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

resource "aws_api_gateway_integration" "spending_history_mock" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_resource.spending_history.id
  http_method = "POST"
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
  depends_on = [aws_api_gateway_method.spending_history_post]
}

# **************  Endpoint 0: Submit (Root/Submit) - MISSING INTEGRATION
# resource "aws_api_gateway_integration" "submit_mock" {
#   rest_api_id = aws_api_gateway_rest_api.pii_api.id
#   resource_id = aws_api_gateway_resource.submit.id
#   http_method = aws_api_gateway_method.submit_post.http_method
#   type        = "MOCK"
#
#   request_templates = {
#     "application/json" = "{\"statusCode\": 200}"
#   }
#
#   depends_on = [aws_api_gateway_method.submit_post]
# }
# *************

resource "aws_api_gateway_method_response" "spending_history_200" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_resource.spending_history.id
  http_method = "POST"
  status_code = "200"

  response_parameters = {
    "method.response.header.Authorization" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
  depends_on = [aws_api_gateway_method.spending_history_post]
}

resource "aws_api_gateway_integration_response" "spending_history_mock_response" {
  rest_api_id = aws_api_gateway_rest_api.pii_api.id
  resource_id = aws_api_gateway_resource.spending_history.id
  http_method = "POST"
  status_code = aws_api_gateway_method_response.spending_history_200.status_code

  response_parameters = {
    "method.response.header.Authorization" = "'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoyMDE2MjMyMTIzfQ.example_signature'"
  }

  response_templates = {
    "application/json" = jsonencode({
      links = [
        {
          rel  = "pii-report-status"
          href = "/pii-report-status"
        }
      ]
    })
  }

  depends_on = [aws_api_gateway_integration.spending_history_mock]
}

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