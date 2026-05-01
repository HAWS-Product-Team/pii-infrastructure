resource "aws_s3_bucket" "input" {
  bucket = "${var.app_name}-data-pipeline-input-${var.environment}"

  tags = {
    Name        = "${var.app_name}-data-pipeline-input-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "input" {
  bucket = aws_s3_bucket.input.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "input" {
  bucket = aws_s3_bucket.input.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "input" {
  bucket = aws_s3_bucket.input.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "input" {
  bucket = aws_s3_bucket.input.id

  rule {
    id     = "input-retention"
    status = "Enabled"

    filter {
      prefix = var.input_key_prefix
    }

    expiration {
      days = var.input_retention_days
    }
  }
}

resource "aws_s3_bucket" "output" {
  bucket = "${var.app_name}-data-pipeline-output-${var.environment}"

  tags = {
    Name        = "${var.app_name}-data-pipeline-output-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output" {
  bucket = aws_s3_bucket.output.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "output" {
  bucket = aws_s3_bucket.output.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "output" {
  bucket = aws_s3_bucket.output.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "output" {
  count  = var.output_retention_days != null ? 1 : 0
  bucket = aws_s3_bucket.output.id

  rule {
    id     = "output-retention"
    status = "Enabled"

    filter {
      prefix = var.output_key_prefix
    }

    expiration {
      days = var.output_retention_days
    }
  }
}
