output "submit_lambda_arn" {
  description = "ARN of the submit Lambda function"
  value       = aws_lambda_function.submit.arn
}

output "submit_lambda_invoke_arn" {
  description = "API Gateway invocation ARN for the submit Lambda function"
  value       = aws_lambda_function.submit.invoke_arn
}

output "submit_lambda_function_name" {
  description = "Name of the submit Lambda function"
  value       = aws_lambda_function.submit.function_name
}

output "tickets_table_name" {
  description = "Name of the DynamoDB tickets table"
  value       = aws_dynamodb_table.tickets.name
}

output "tickets_table_arn" {
  description = "ARN of the DynamoDB tickets table"
  value       = aws_dynamodb_table.tickets.arn
}
