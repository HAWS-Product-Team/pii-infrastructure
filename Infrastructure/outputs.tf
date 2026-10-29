output "submit_lambda_arn" {
  description = "ARN of the submit Lambda function"
  value       = module.submit.submit_lambda_arn
}

output "submit_lambda_invoke_arn" {
  description = "API Gateway invocation ARN for the submit Lambda function"
  value       = module.submit.submit_lambda_invoke_arn
}

output "submit_lambda_function_name" {
  description = "Name of the submit Lambda function"
  value       = module.submit.submit_lambda_function_name
}

output "tickets_table_name" {
  description = "Name of the DynamoDB tickets table"
  value       = module.submit.tickets_table_name
}

output "tickets_table_arn" {
  description = "ARN of the DynamoDB tickets table"
  value       = module.submit.tickets_table_arn
}

output "spending_history_url" {
  description = "Direct endpoint URL for POST /spending-history"
  value       = module.api_gateway.spending_history_endpoint_url
}
