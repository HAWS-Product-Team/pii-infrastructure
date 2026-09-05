output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "input_bucket_name" {
  value = aws_s3_bucket.input.id
}

output "output_bucket_name" {
  value = aws_s3_bucket.output.id
}

output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.batch.name
}

output "batch_job_queue_name" {
  value = aws_batch_job_queue.batch_queue.name
}

output "batch_job_definition_name" {
  value = aws_batch_job_definition.batch_job.name
}

output "vpc_id" {
  value = local.vpc_id
}

output "subnet_ids" {
  value = local.subnet_ids
}

output "batch_service_role_arn" {
  value = aws_iam_role.batch_service_role.arn
}

output "batch_execution_role_arn" {
  value = aws_iam_role.batch_execution_role.arn
}

output "batch_job_role_arn" {
  value = aws_iam_role.batch_job_role.arn
}

output "batch_security_group_id" {
  value = aws_security_group.batch_sg.id
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.data_pipeline.arn
}

output "state_machine_name" {
  value = aws_sfn_state_machine.data_pipeline.name
}

output "step_functions_role_arn" {
  value = aws_iam_role.step_functions_role.arn
}

output "step_functions_log_group_name" {
  value = aws_cloudwatch_log_group.step_functions.name
}

output "normalizer_lambda_arn" {
  value = aws_lambda_function.normalizer.arn
}

output "normalizer_lambda_name" {
  value = aws_lambda_function.normalizer.function_name
}

output "normalizer_lambda_role_arn" {
  value = aws_iam_role.normalizer_lambda_role.arn
}

output "normalizer_log_group_name" {
  value = aws_cloudwatch_log_group.normalizer_lambda.name
}

output "pii_calculator_lambda_arn" {
  value = aws_lambda_function.pii_calculator.arn
}

output "pii_calculator_lambda_name" {
  value = aws_lambda_function.pii_calculator.function_name
}

output "pii_calculator_lambda_role_arn" {
  value = aws_iam_role.pii_calculator_lambda_role.arn
}

output "pii_calculator_log_group_name" {
  value = aws_cloudwatch_log_group.pii_calculator_lambda.name
}
