# Story: Add pdf2csv to data pipeline

## Summary

As a platform engineer,  
I want to add a Normalizer to the datapipeline so that the Amazon purchase data uploaded by the user can be used to 
compute their PII.

## Background

The data pipeline is orchestrated by AWS step functions.  S3 buckets hold the artifacts between stages.  Users 
upload their purchase data to the input-bucket.

The current pipeline elements are:
```Classifier PIICalculation```
Let's add Normalizer to the front:
```Normalizer Classifier PIICalculation```

The intended execution flow is:
```Normalizer -> Merge -> Classifier -> PIICalculation``` 

Pipeline data should be passed between stages using S3 object URIs. PDF, CSV, and JSON file contents should not be 
passed inline through Step Functions state.

## Existing Architecture
There are two s3 buckets:
- ```input-bucket``` where the initial data is uploaded by the user and artifacts the data pipeline works on for input data 
for each stage.  Each stage produces a CSV file that is used as input for the next stage.  The initial file is named
anonymized.csv.
- ```output-bucket``` for .json report generation that will be returned to the user
As each user is associated with a ticket number, the ticket number will stay the same for each operation of the pipeline.

s3.tf refers to these buckets as the following:
- `<input-bucket>` = "${var.app_name}-data-pipeline-input-${var.environment}"
- `<output-bucket>` = "${var.app_name}-data-pipeline-output-${var.environment}"
This will be the standard for input and output file creation for all step functions.

## Target Architecture
Implementing Merge is out of scope for this story.

```text 
Step Functions State Machine | 
v s3://<input-bucket>/<ticket number>/uploads/*.pdf |
v Task 1: run Normalizer -> *.csv |
v s3://<input-bucket>/<ticket number>/uploads/*.csv |
v Task 2: merge -> anonymized.csv |
v s3://<input-bucket>/<ticket number>/anonymized.csv |
v Task 3: Submit Classifier AWS Batch Job | 
v s3://<input-bucket>/<ticket-number>/classified.csv | 
v Task 4: Invoke PIICalculation Lambda | 
v s3://<output-bucket>/<ticket-number>/pii-report.json
```

## Proposed Workflow Input

The Step Functions execution should accept an input payload similar to:
```json
{
  "ticket": "123456789",
  "uploads": "s3://pii-data-pipeline-input-dev/123456789/uploads/",
  "inputCsv": "s3://pii-data-pipeline-input-dev/123456789/anonymized.csv",
  "classifiedCsv": "s3://pii-data-pipeline-input-dev/123456789/classified.csv",
  "piiReportJson": "s3://pii-data-pipeline-output-dev/123456789/pii-report.json"
}
```

## Step Functions State Machine Behavior

The state machine contains three primary task states (with Merge skipped for this story):
```text
Normalize -> Classify -> CalculatePII -> Success
```

## State 1: `Normalize`
`Normalize` invokes the Normalizer Lambda with the uploads S3 URI to convert uploaded PDF files into CSV files.
### Inputs:
- `ticket`
- `uploads`
### Expected Behavior
1. read uploads from S3,
2. submit uploads to pdf2csv / Normalizer Lambda,
3. Normalizer creates csv files for each pdf file in uploads,
4. complete successfully and transition to `Classify`.

## State 2: `Merge`
`Merge` merges the CSVs into a single anonymized.csv. (This is out of scope for this story. So we transition directly from `Normalize` to `Classify` for now and require some manual effort to merge the CSVs if needed).

## State 3: `Classify`
`Classify` submits the existing classifier AWS Batch job.

## State 4: `CalculatePII`
`PIICalculator` computes the PII.

### Lambda Event Contract

The Normalizer Lambda receives an event:
```json 
{ 
  "ticket": "123456789", 
  "uploads": "s3://pii-data-pipeline-input-dev/123456789/uploads"
}
```

The Lambda response includes execution information for Step Functions observability, for example:
```json 
{ 
  "ticket": "123456789", 
  "status": "SUCCEEDED", 
  "uploads": "s3://pii-data-pipeline-input-dev/123456789/uploads"
}
```

## Infrastructure Scope

Update the Terraform module datapipeline to include:

- AWS Step Functions state machine to put Normalizer at the front of the pipeline (`Normalize -> Classify -> CalculatePII`).
- Task state to invoke the Normalizer Lambda function.
- IAM role for Step Functions execution updated with permissions to invoke Normalizer Lambda.
- Permissions for Step Functions to:
  - invoke the Normalizer Lambda function
  - invoke the PIICalculator Lambda function
  - submit/manage Batch classifier jobs
  - write Step Functions logs to CloudWatch
- AWS Lambda function definition for Normalizer (`arm64`, runtime `python3.12`, handler `lambda_function.lambda_handler`).
- Lambda execution role for Normalizer with `s3:GetObject`, `s3:PutObject`, and `s3:ListBucket` permissions on the input bucket.
- CloudWatch log group for the Normalizer Lambda.
- Environment-specific variables for:
  - Normalizer Lambda S3 key (`lambdas/normalizer.zip`)
  - Normalizer Lambda handler (`lambda_function.lambda_handler`)
  - Normalizer Lambda runtime (`python3.12`)
  - Normalizer Lambda timeout (default 600s / 10 min)
  - Normalizer Lambda memory size (default 512 MB)

## Normalizer Lambda Execution Role

The Normalizer Lambda execution role provides:

- Read `*.pdf` from the input bucket's <ticket>/uploads path (`s3:GetObject`).
- List objects in the input bucket (`s3:ListBucket`) to discover uploaded PDFs.
- Write `*.csv` to the input bucket's <ticket>/uploads path (`s3:PutObject`).
- Write logs to CloudWatch.

## Retry and Error Handling

The state machine should include retry behavior for transient infrastructure failures.

## Normalizer Lambda Retry Policy

Because Normaliver is moderately fast and cheap:

- Retry transient Lambda/S3 failures.
- Use a 10 minute timeout.
- Fail clearly on validation errors.

Suggested policy:
```text 
max attempts: 2-3 backoff: exponential timeout: 1-5 minutes
``` 

## Failure Behavior

- If `Normalizer` fails, `Classify` must not run.
- The pdfs in the S3 bucket should remain available in S3 after Normalizer success.
- Failed executions should preserve the S3 artifact URIs needed for manual retry or investigation.

## Observability Requirements

The infrastructure should provide:

- CloudWatch logs for Step Functions executions.
- CloudWatch logs for the Normalizer Lambda.
- Clear Step Functions state names:
  - `Normalizing`
- Execution uploads should include S3 artifact URIs.
- Errors should be visible at the failed state level.
- The Lambda response should include `ticket` number, uploads URI, and status.

## Acceptance Criteria

- The state machine contains a Normalizer Lambda task state.
- The Normalizer Lambda task is the first stage in the pipeline.
- The Normalizer workload runs as Lambda, not AWS Batch.
- PDF and CSV contents are not passed inline through Step Functions state.
- The Normalizer Lambda receives:
  - uploads S3 URI
- The Normalizer Lambda role has read access to the input bucket.
- The Normalizer Lambda role has write access to the input bucket.
- Step Functions has permission to invoke the Normalizer Lambda.
- Normalizer Lambda logs are available in CloudWatch.
- Terraform plan succeeds.
- Terraform apply succeeds in the target environment.
- A test execution can be started with a sample payload.
- The test execution produces:
  - `<pdf file name>.csv` at the expected S3 URI

## Out of Scope
- Frontend integration.
- API changes for starting pipeline executions.
- EventBridge or S3-triggered automatic execution.

The application repository provides the Normalizer Lambda handler and package artifact, which is located in the input S3 bucket at `/lambdas/normalizer.zip`.

## Clarifications and Decisions

- **Lambda Runtime and Handler:** `python3.12` runtime with handler `lambda_function.lambda_handler` (configurable via variables).
- **uploads Path:** The definitive path is `s3://<input-bucket>/<ticket-number>/uploads`.
- **Intermediate Storage:** The `input-bucket` is used for all intermediate pipeline artifacts.
- **Workflow Input Structure:** Explicit `ticket` field in the execution input JSON along with `uploads`, `inputCsv`, `classifiedCsv`, and `piiReportJson`.
- **Lambda Networking:** The Normalizer Lambda runs in the default Lambda service network (not VPC-attached).
- **Logging:** Step Functions uses standard CloudWatch logging (`/aws/vendedlogs/states/...`) with logging level `ALL` and execution data included.
