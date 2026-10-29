# Story 10 — Ticket Number, Session Token, and Submit Infrastructure

## Summary

As a platform engineer,  
I want to provision the AWS infrastructure required to run the `submit` Lambda handler and its dependency `mint-ticket`,  
so that unauthenticated users can initiate a session, receive a cryptographically secure ticket and session token in DynamoDB, and obtain presigned S3 upload URLs to push statement PDFs directly to S3 under `uploads/<ticketId>/` with minimal latency and optimal resource efficiency.

---

## Background & Architecture Overview

The `submit` Lambda handler serves as the public front door for the PII application at `POST /spending-history`. It handles batch upload requests from users wishing to calculate their Personal Inflation Index.

### Downstream Ingestion Flow
1. **Session Inception:** The client sends a batch manifest (`files` array) to `POST /spending-history` on API Gateway.
2. **Ticket Issuance (`mint-ticket`):** The `submit` handler calls the `mint_ticket` module to generate a 26-character canonical ULID (`ticket_id`) and a 32-byte CSPRNG bearer secret (base64url without padding, returned exactly once).
3. **State Persistence:**
   - `mint_ticket` records the initial item in DynamoDB with partition key `ticket_id`, `secret_hash` (SHA-256 hex digest), `job_status: "issued"`, `created_at` (ISO-8601 UTC), and `expires_at` (UNIX epoch timestamp).
   - `submit` immediately executes an `UpdateItem` on DynamoDB to set `job_status = "AWAITING_UPLOAD"` and `expected_file_count` (snake_case integer).
4. **Presigned URL Generation:** For each validated PDF descriptor, `submit` generates an S3 presigned PUT URL pinned to `uploads/<ticketId>/<filename>` with `ContentType: "application/pdf"`.
5. **Direct Client Upload:** The client uploads files directly to the S3 input bucket using the presigned URLs, bypassing API Gateway and Lambda payload size limitations to conserve compute bandwidth and reduce operational costs.
6. **Decoupled Pipeline Trigger:** The `submit` Lambda deliberately does **not** trigger AWS Step Functions. Downstream processing is owned by the separate `UploadWatcher` Lambda, which initiates the Step Functions state machine once all declared files have arrived in S3.

---

## Architectural Decisions & Clarified Insights

The infrastructure design incorporates key architectural decisions formulated to maximize system reliability, minimize operational friction, and maintain clean separation of concerns:

1. **Dedicated Module (`modules/submit`):**
   - The `submit` Lambda, DynamoDB tickets table, IAM roles, and CloudWatch log groups are encapsulated within a dedicated `modules/submit` module.
   - This isolates session creation and credential storage from the downstream data processing pipeline and central API routing, reducing the blast radius of changes.

2. **Direct API Gateway Lambda Proxy:**
   - The mock integration on `POST /spending-history` in `modules/api-gateway` is replaced with an `AWS_PROXY` integration to the `submit` Lambda.
   - API Gateway forwards the raw request body to the Lambda and returns the handler's CORS-enabled proxy response directly to the client.

3. **Reuse of Existing Input S3 Bucket:**
   - The environment variable `UPLOADS_BUCKET_NAME` references the existing data pipeline input bucket (`${var.app_name}-data-pipeline-input-${var.environment}`).
   - Uploading directly under the prefix `uploads/<ticketId>/` in the input bucket eliminates cross-bucket data copying, simplifying ingestion into the subsequent `Normalizer` stage.

4. **S3 CORS Configuration for Direct Browser Uploads:**
   - An `aws_s3_bucket_cors_configuration` resource is attached to the input S3 bucket to allow browser `PUT` requests with the required `Content-Type: application/pdf` header and to expose the `ETag` header.

5. **Deployment Artifact from S3:**
   - Consistent with existing pipeline Lambdas (`Normalizer`, `Merge`, `PIICalculator`), the `submit` Lambda code is sourced from an S3 zip archive key (`lambdas/submit.zip`) in the input bucket.

---

## Infrastructure Component Specifications

### 1. DynamoDB Tickets Table

- **Resource:** `aws_dynamodb_table.tickets`
- **Table Name:** `${var.app_name}-tickets-${var.environment}`
- **Billing Mode:** `PAY_PER_REQUEST` (On-Demand capacity optimizes cost for spiky front-door traffic and eliminates throughput management).
- **Partition Key:** `ticket_id` (Type: `S` — 26-character canonical ULID).
- **Time-to-Live (TTL):**
  - **Attribute Name:** `expires_at`
  - **Enabled:** `true` (enables automatic purging of expired session tokens and tickets after TTL without custom sweeper overhead).
- **Point-in-Time Recovery (PITR):** Enabled to ensure data resilience.
- **Server-Side Encryption:** Default AWS KMS or SSE-S3 (`AES256`).
- **Tags:**
  ```hcl
  tags = {
    Name        = "${var.app_name}-tickets-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  ```

### 2. Submit Lambda Function

- **Resource:** `aws_lambda_function.submit`
- **Function Name:** `${var.app_name}-submit-${var.environment}`
- **Runtime:** `python3.12`
- **Architecture:** `arm64` (AWS Graviton2 for cost and power efficiency).
- **Handler:** `submit.lambda_handler.handler`
- **Memory Size:** `256 MB` (optimized for lightweight JSON validation, hashing, and presigning).
- **Timeout:** `15 seconds` (ensures fast turnaround for synchronous HTTP clients).
- **Ephemeral Storage (`/tmp`):** `512 MB`.
- **Code Package:**
  - `s3_bucket`: `aws_s3_bucket.input.id`
  - `s3_key`: `var.submit_lambda_s3_key` (default: `"lambdas/submit.zip"`)
- **Environment Variables:**
  ```hcl
  environment {
    variables = {
      TICKETS_TABLE_NAME       = aws_dynamodb_table.tickets.name
      UPLOADS_BUCKET_NAME      = var.uploads_bucket_name
      MAX_FILES                = tostring(var.max_files)               # default: "20"
      MAX_TOTAL_BYTES          = tostring(var.max_total_bytes)         # default: "4294967296" (4 GiB)
      PRESIGNED_EXPIRY_SECONDS = tostring(var.presigned_expiry_seconds)# default: "900" (15 minutes)
      TICKET_TTL_SECONDS       = tostring(var.ticket_ttl_seconds)      # default: "86400" (24 hours)
    }
  }
  ```

### 3. Submit Lambda IAM Role & Policies

- **Role Name:** `${var.app_name}-submit-lambda-role-${var.environment}`
- **Assume Role Policy:** Standard Lambda trust policy for `lambda.amazonaws.com`.
- **Permissions Policy (`aws_iam_policy.submit_lambda_policy`):**
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "CloudWatchLogs",
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": [
          "${aws_cloudwatch_log_group.submit_lambda.arn}",
          "${aws_cloudwatch_log_group.submit_lambda.arn}:*"
        ]
      },
      {
        "Sid": "DynamoDBTicketAccess",
        "Effect": "Allow",
        "Action": [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        "Resource": "${aws_dynamodb_table.tickets.arn}"
      },
      {
        "Sid": "S3PresignedPutScope",
        "Effect": "Allow",
        "Action": [
          "s3:PutObject"
        ],
        "Resource": "${var.uploads_bucket_arn}/uploads/*"
      }
    ]
  }
  ```

### 4. CloudWatch Log Group

- **Resource:** `aws_cloudwatch_log_group.submit_lambda`
- **Name:** `/aws/lambda/${var.app_name}-submit-${var.environment}`
- **Retention:** `var.lambda_log_retention_days` (default: 3 days in dev, configurable per environment).

### 5. API Gateway Integration Updates

- **Path:** `/spending-history`
- **Method:** `POST`
- **Authorization:** `NONE` (unauthenticated front door).
- **Integration (`aws_api_gateway_integration.spending_history`):**
  - Type: `AWS_PROXY`
  - HTTP Method: `POST`
  - Integration HTTP Method: `POST`
  - URI: `aws_lambda_function.submit.invoke_arn`
- **Lambda Permission (`aws_lambda_permission.apigw_submit`):**
  ```hcl
  resource "aws_lambda_permission" "apigw_submit" {
    statement_id  = "AllowAPIGatewayInvokeSubmit"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.submit.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${var.rest_api_execution_arn}/*/${aws_api_gateway_method.spending_history_post.http_method}${aws_api_gateway_resource.spending_history.path}"
  }
  ```
- **Redeployment Trigger:**
  - Update `aws_api_gateway_deployment.pii_api_deployment.triggers.redeployment` to track `aws_api_gateway_integration.spending_history` and `aws_lambda_permission.apigw_submit`.

### 6. S3 Bucket CORS Configuration

- **Resource:** `aws_s3_bucket_cors_configuration.input_uploads`
- **Bucket:** `aws_s3_bucket.input.id`
- **Rules:**
  ```hcl
  resource "aws_s3_bucket_cors_configuration" "input_uploads" {
    bucket = aws_s3_bucket.input.id

    cors_rule {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "OPTIONS"]
      allowed_origins = var.cors_allowed_origins # default: ["*"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3600
    }
  }
  ```

---

## Terraform Module Structure

```text
Infrastructure/
├── main.tf                         # Root orchestrator: invokes submit and api_gateway modules
├── variables.tf                    # Root variables
├── outputs.tf                      # Root outputs (submit URL, table name, ARNs)
├── modules/
│   ├── submit/                     # New dedicated module
│   │   ├── main.tf                 # Lambda, DynamoDB, IAM role & policies, Log Group
│   │   ├── variables.tf            # Module input variables
│   │   └── outputs.tf              # Module outputs (lambda ARN, invoke ARN, table ARN/name)
│   ├── api-gateway/
│   │   ├── main.tf                 # Updated with live proxy integration & permissions
│   │   ├── mocks.tf                # Deprecate/remove spending_history_mock
│   │   ├── variables.tf            # Add submit_lambda_invoke_arn and submit_lambda_arn
│   │   └── outputs.tf
│   └── datapipeline/
│       └── s3.tf                   # Add S3 CORS configuration for browser uploads
```

### Module Inputs (`modules/submit/variables.tf`)

| Variable Name | Type | Default | Description |
|---|---|---|---|
| `app_name` | `string` | `"pii"` | Application name prefix |
| `environment` | `string` | `"dev"` | Target deployment environment |
| `uploads_bucket_name` | `string` | — | Target S3 bucket name for batch uploads |
| `uploads_bucket_arn` | `string` | — | ARN of target S3 bucket for uploads |
| `submit_lambda_s3_key` | `string` | `"lambdas/submit.zip"` | S3 key for the submit Lambda zip package |
| `max_files` | `number` | `20` | Maximum PDFs allowed per batch request |
| `max_total_bytes` | `number` | `4294967296` | Maximum cumulative batch size in bytes (4 GiB) |
| `presigned_expiry_seconds` | `number` | `900` | Expiration time for presigned upload URLs (15 min) |
| `ticket_ttl_seconds` | `number` | `86400` | Ticket session expiration time in seconds (24 hours) |
| `lambda_log_retention_days` | `number` | `3` | CloudWatch log retention period in days |

### Module Outputs (`modules/submit/outputs.tf`)

| Output Name | Value | Description |
|---|---|---|
| `submit_lambda_arn` | `aws_lambda_function.submit.arn` | ARN of the submit Lambda function |
| `submit_lambda_invoke_arn` | `aws_lambda_function.submit.invoke_arn` | API Gateway invocation ARN |
| `submit_lambda_function_name`| `aws_lambda_function.submit.function_name` | Name of the submit Lambda function |
| `tickets_table_name` | `aws_dynamodb_table.tickets.name` | Name of the DynamoDB tickets table |
| `tickets_table_arn` | `aws_dynamodb_table.tickets.arn` | ARN of the DynamoDB tickets table |

---

## Acceptance Criteria

1. **Terraform Clean Apply:**
   - `terraform validate` and `terraform plan` pass without errors.
   - Running `terraform apply` provisions the DynamoDB table, submit Lambda, IAM roles, CloudWatch log group, API Gateway integration, and S3 CORS configuration.

2. **DynamoDB Table Conformance:**
   - Table `${var.app_name}-tickets-${var.environment}` exists with partition key `ticket_id` (`String`).
   - TTL is enabled on attribute `expires_at`.
   - Billing mode is `PAY_PER_REQUEST`.

3. **Lambda Configuration & Security:**
   - Submit Lambda runtime is `python3.12`, architecture `arm64`, memory `256 MB`, timeout `15 seconds`.
   - Environment variables `TICKETS_TABLE_NAME` and `UPLOADS_BUCKET_NAME` match the deployed table and input bucket.
   - IAM role enforces least privilege: strictly scoped to the tickets table, the uploads S3 path, and CloudWatch logs.
   - Raw secrets and presigned URLs are never written to logs.

4. **API Gateway Proxy Routing:**
   - `POST /spending-history` routes directly to the `submit` Lambda via `AWS_PROXY`.
   - Static mock for `/spending-history` is decommissioned.
   - Appropriate `aws_lambda_permission` is established so API Gateway can invoke the function.

5. **S3 CORS Readiness:**
   - The input S3 bucket accepts HTTP `PUT` and `OPTIONS` requests from browser origins with `Content-Type: application/pdf`.

6. **End-to-End Functional Verification:**
   - Sending a valid `POST /spending-history` payload returns HTTP 200 with CORS headers containing `ticketId`, `secret`, `uploadPrefix`, and an `uploads` array of presigned PUT URLs.
   - Direct `curl -T sample.pdf -H "Content-Type: application/pdf" "<presigned_uploadUrl>"` successfully writes to S3 with HTTP 200.
   - DynamoDB confirms a record with `job_status: "AWAITING_UPLOAD"`, `expected_file_count`, and active TTL.
