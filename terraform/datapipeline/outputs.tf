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
