# Story: Adjust Infrastructure to Orchestrate Classifier with AWS Batch and PIICalculation with Lambda

## Summary

As a platform engineer,  
I want the data pipeline infrastructure to use AWS Step Functions to orchestrate the existing classifier AWS Batch 
workload and the PIICalculation Lambda workload,  
so that the expensive inference container is used only for classification and the lightweight PIICalculation 
stage runs in Lambda after classification completes.

## Background

The data pipeline is moving to a staged batch pipeline architecture using S3 artifacts between stages.

The current pipeline elements are:
```text Classifier PIICalculation```

The intended execution flow is:
```text Classifier -> PIICalculation``` 

The classifier is a long-running inference workload and already has an ECR container image available and is 
using AWS Batch. The PIICalculation workload is short-running, typically completing in seconds, 
and should run as an AWS Lambda function rather than as an AWS Batch container.

Pipeline data should be passed between stages using S3 object URIs. CSV and JSON file contents should not be 
passed inline through Step Functions state.

## Existing Architecture
There are two s3 buckets:
- ```input-bucket``` where the initial data is uploaded by the user and artifacts the data pipeline works on for input data 
for each stage.  Each stage produces a CSV file that is used as input for the next stage.  The initial file is named
anonymized.csv.
- ```output-bucket``` for .json report generation that will be returned to the user
As each user is associated with a ticket number, the ticket number will stay the same for each operation of the pipeline.

s3.tf refers to these buckets as the following:
- <input-bucket> = "${var.app_name}-data-pipeline-input-${var.environment}"
- <output-bucket> = "${var.app_name}-data-pipeline-output-${var.environment}"

## Target Architecture

```text 
Step Functions State Machine | 
v s3://<input-bucket>/<ticket number>/anonymized.csv |
v Task 1: Submit Classifier AWS Batch Job | 
v s3://<input-bucket>/<ticket-number>classified.csv | 
v Task 2: Invoke PIICalculation Lambda | 
v s3://<output-bucket>/<ticket-number>/pii-report.json
```

## Proposed Workflow Input

The Step Functions execution should accept an input payload similar to:
```json 
{ "ticketnumber": "123456789", "inputCsv": "s3://pii-data-pipeline-input-dev/123456789/anonymized.csv", 
  "classifiedCsv": "s3://pii-data-pipeline-input-dev/123456789/classified.csv", 
  "piiReportJson": "s3://pii-data-pipeline-output-dev/123456789/pii-report.json" }
``` 

## Step Functions State Machine Behavior

The state machine should contain two primary task states:
```text ClassifyCsv -> CalculatePII -> Success```

## State 1: `ClassifyCsv`

`ClassifyCsv` submits the existing classifier AWS Batch job.

### Inputs
```jobId inputCsv classifiedCsv``` 

### Expected Behavior
1. read inputCsv from S3,
2. run classifier inference,
3. write classifiedCsv to S3,
4. complete successfully only after classifiedCsv is available

### AWS Batch Command Contract

The classifier AWS Batch job should receive input/output arguments equivalent to:
```bash 
inflation-classifier
--input-s3-uri s3://pii-data-pipeline-input-dev/123456789/anonymized.csv
--output-s3-uri s3://pii-data-pipeline-input-dev/123456789/classified/classified.csv
``` 

If the current classifier CLI does not yet support these exact flags, the infrastructure should still 
be designed around this target contract and use the current compatible command until the application contract is updated.

## State 2: `CalculatePII`

`CalculatePII` invokes the PIICalculation Lambda function after the classifier AWS Batch job succeeds.

### Inputs
`input-s3-uri`
`output-s3-uri`
`input-s3-uri` will point to a classified.csv in s3.  `output-s3-uri` will be where the report is generated which will
be called pii-report.json

### Expected Behavior
1. read classified.csv from S3 
2. compute PIICalculation 
3. write pii-report.json to S3 
4. return success after pii-report.json is written

### Lambda Event Contract

The PIICalculation Lambda should receive an event similar to:
```json 
{ "ticket": "123456789", "input-s3-uri": "s3://pii-work/jobs/123456789/classified/classified.csv", 
  "output-s3-uri": "s3://pii-output/jobs/123456789/pii-report.json",
}
```

The Lambda response should include enough information for Step Functions observability, for example:
```json 
{ "ticket": "123456789", "status": "SUCCEEDED", "input-s3-uri": "s3://pii-work/jobs/123456789/classified/classified.csv", 
  "output-s3-uri": "s3://pii-output/jobs/123456789/pii-report.json" }
``` 

## Infrastructure Scope

Update the Terraform module datapipeline to include:

- AWS Step Functions state machine for the two-stage pipeline.
- Task state to submit and wait for the classifier AWS Batch job.
- Task state to invoke the PIICalculation Lambda function.
- IAM role for Step Functions execution.
- Permissions for Step Functions to:
  - submit AWS Batch jobs
  - describe AWS Batch jobs
  - terminate AWS Batch jobs if needed
  - pass the classifier AWS Batch job role
  - invoke the PIICalculation Lambda function
  - write Step Functions logs to CloudWatch
- AWS Lambda function definition for PIICalculation.
- Lambda execution role for PIICalculation.
- CloudWatch log group for the PIICalculation Lambda.
- CloudWatch logging for Step Functions executions.
- Environment-specific variables for:
  - input bucket
  - work/intermediate bucket
  - output bucket
  - classifier AWS Batch job definition
  - classifier AWS Batch job queue
  - PIICalculation Lambda function name
  - PIICalculation Lambda timeout
  - PIICalculation Lambda memory size

## Existing Classifier Container

The classifier ECR container image already exists and should continue to be used by the classifier AWS Batch job.

This story should not require creating a new classifier image.

## IAM Requirements

## Step Functions Execution Role

The Step Functions execution role should be able to:

- Submit the classifier AWS Batch job.
- Describe the classifier AWS Batch job.
- Terminate the classifier AWS Batch job if needed.
- Pass the relevant AWS Batch job role.
- Invoke the PIICalculation Lambda function.
- Write Step Functions logs to CloudWatch.

## Classifier AWS Batch Job Role

The classifier job role should be able to:

- Read the input CSV from the input bucket.
- Write `classified.csv` to the input bucket.
- Write logs to CloudWatch.

Classifier doesn't need access to output bucket.

## PIICalculation Lambda Execution Role

The PIICalculation Lambda execution role should be able to:

- Read `classified.csv` from the input bucket.
- Write `pii-report.json` to the output bucket.
- Write logs to CloudWatch.

## Retry and Error Handling

The state machine should include retry behavior for transient infrastructure failures.

## Classifier Retry Policy

Because classification is an expensive, long-running inference step:

- Use limited retries.
- Retry AWS Batch service/transient failures.
- Do not blindly retry deterministic application errors.
- Use a timeout appropriate for observed classifier runtime.

Suggested policy:
```text 
max attempts: 1-2 backoff: exponential timeout: five to tens of minutes or longer based on observed classifier runtime
```

## PIICalculation Lambda Retry Policy

Because PIICalculation is fast and cheap:

- Retry transient Lambda/S3 failures.
- Use a short timeout.
- Fail clearly on validation errors.

Suggested policy:
```text 
max attempts: 2-3 backoff: exponential timeout: 1-5 minutes
``` 

## Failure Behavior

- If `Classify` fails, `CalculatePII` must not run.
- If `CalculatePII` fails, the classifier should not be rerun automatically as part of the same retry.
- The classified CSV should remain available in S3 after classifier success.
- Failed executions should preserve the S3 artifact URIs needed for manual retry or investigation.

## Observability Requirements

The infrastructure should provide:

- CloudWatch logs for Step Functions executions.
- CloudWatch logs for the classifier AWS Batch job.
- CloudWatch logs for the PIICalculation Lambda.
- Clear Step Functions state names:
  - `Classify`
  - `CalculatePII`
- Execution input and output should include S3 artifact URIs.
- Errors should be visible at the failed state level.
- The Lambda response should include `ticket` number, input URI, output URI, and status.

## Acceptance Criteria

- A Step Functions state machine exists for the data pipeline.
- The state machine contains a classifier AWS Batch task state.
- The state machine contains a PIICalculation Lambda task state.
- The classifier AWS Batch task runs before the PIICalculation Lambda task.
- The PIICalculation Lambda task runs only after the classifier AWS Batch job succeeds.
- The classifier uses the existing inference ECR container through AWS Batch.
- The PIICalculation workload runs as Lambda, not AWS Batch.
- The state machine passes S3 artifact URIs between stages.
- CSV and JSON contents are not passed inline through Step Functions state.
- The classifier job receives:
  - input CSV S3 URI
  - classified CSV output S3 URI
- The PIICalculation Lambda receives:
  - classified CSV input S3 URI
  - PII report JSON output S3 URI
- The classifier job role has read/write access to the input bucket.
- The PIICalculation Lambda role has read access to the input bucket.
- The PIICalculation Lambda role has write access to the output bucket.
- Step Functions has permission to submit and monitor the classifier AWS Batch job.
- Step Functions has permission to invoke the PIICalculation Lambda.
- Step Functions logs are enabled.
- AWS Batch job logs are available in CloudWatch.
- PIICalculation Lambda logs are available in CloudWatch.
- Failed classifier execution prevents PIICalculation from running.
- Failed PIICalculation execution does not require the classifier to be rerun by default.
- Terraform plan succeeds.
- Terraform apply succeeds in the target environment.
- A test execution can be started with a sample payload.
- The test execution produces:
  - `classified.csv` at the expected S3 URI
  - `pii-report.json` at the expected S3 URI

## Out of Scope

- Creating or modifying the classifier ECR container image.
- Creating normalizer infrastructure.
- Creating anonymizer infrastructure.
- Rewriting the classifier application logic.
- Frontend integration.
- API changes for starting pipeline executions.
- EventBridge or S3-triggered automatic execution, unless already part of the existing infrastructure approach.
- Moving the classifier from AWS Batch to Lambda.

The application repository should provide the PIICalculation Lambda handler and package artifact required by this infrastructure.
