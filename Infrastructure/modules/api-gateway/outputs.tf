output "rest_api_id" {
  description = "ID of the REST API"
  value       = aws_api_gateway_rest_api.pii_api.id
}

output "rest_api_execution_arn" {
  description = "Execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.pii_api.execution_arn
}

output "stage_invoke_url" {
  description = "Base invocation URL for the API Gateway stage"
  value       = aws_api_gateway_stage.pii_api_stage.invoke_url
}

output "spending_history_endpoint_url" {
  description = "Full URL for the spending-history endpoint"
  value       = "${aws_api_gateway_stage.pii_api_stage.invoke_url}${aws_api_gateway_resource.spending_history.path}"
}
