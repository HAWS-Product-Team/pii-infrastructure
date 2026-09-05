# Data Pipeline Infrastructure

This module provisions the infrastructure required for the PII data pipeline. AWS Step Functions is used to operate 
the stages of the pipeline: Normalizer (via AWS Lambda), Classifier (via AWS Batch), and PII-Calculator (via AWS Lambda).

## Components

- **ECR Repository**: Stores the application container image.
- **S3 Buckets**: Dedicated buckets for input and output data.
- **AWS Step Functions**: Orchestrates and operates the stages of the pipeline: Normalizer (via AWS Lambda), 
Classifier (via AWS Batch), and PII-Calculator (via AWS Lambda).
  - **AWS Lambda (Normalizer)**: Runs the Normalizer stage to parse and convert uploaded PDFs to CSVs.
  - **AWS Batch**: 
    - **Compute Environment**: Managed Fargate/Fargate Spot environment.
    - **Job Queue**: Prioritized queue for batch jobs.
    - **Job Definition**: Configured for Fargate ARM64 with logging and S3 access.
  - **AWS Lambda (PII-Calculator)**: Runs the PII-Calculator stage of the pipeline.
- **IAM Roles**: Least-privilege roles for Batch service, ECS execution, Lambda functions, and Step Functions runtime.
- **Networking**: Optional creation of VPC/Subnets or reuse of existing ones.

## Operations Manual

### 1. Container Image Management

The pipeline runs on **Fargate ARM64 (Graviton-equivalent)**. You must build your container image for the 
`linux/arm64` platform.

#### Build and Push to ECR

Replace `<AWS_REGION>`, `<AWS_ACCOUNT_ID>`, and `<REPO_NAME>` with values from terraform outputs.

```bash
# 1. Authenticate Docker to ECR
aws ecr get-login-password --region <AWS_REGION> | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com

# 2. Build the image for ARM64
# Use buildx for cross-platform builds if not on an ARM machine
docker buildx build --platform linux/arm64 -t <REPO_NAME>:latest --push .

# Alternatively, if building locally without push:
docker build --platform linux/arm64 -t <REPO_URL>:latest .
docker push <REPO_URL>:latest
```

### 2. Triggering a Batch Job

You can trigger a job using the AWS CLI. You need to provide the input and output S3 URIs as job parameters, which are passed as positional command-line arguments to the container entrypoint.

#### Command Template

```bash
aws batch submit-job \
  --job-name job-from-aws-cli \
  --job-queue pii-batch-queue-dev \
  --job-definition pii-batch-jobdef-fargate-dev \
  --parameters input_s3_uri=s3://pii-data-pipeline-input-dev/123456789/anonymized.csv,output_s3_uri=s3://pii-data-pipeline-input-dev/123456789/classified.csv
```

### 3. Inputs and Outputs
These are passed as parameters that substitute into the container command line as positional arguments:

- **1st Positional Argument (`input_s3_uri`)**: Full S3 path to the input CSV file to be processed. The job role has read access to the input bucket.
- **2nd Positional Argument (`output_s3_uri`)**: Full S3 path where the classified CSV results should be stored. The job role has write access to the intermediate/input bucket.
- **Logs**:
    - All container logs (stdout/stderr) are sent to CloudWatch Logs under the log group provided in the outputs.

### Troubleshooting

| Issue | Potential Cause                | Resolution                                                                                   |
|-------|--------------------------------|----------------------------------------------------------------------------------------------|
| Job stuck in `RUNNABLE` | No compute resources available | Check if `max_vcpus` is > 0 and if the Fargate Spot market has capacity.                     |
| `Exec format error` | Wrong image architecture       | Ensure the image was built for `linux/arm64`. Check build steps.                             |
| `Access Denied` to S3 | IAM permissions                | Verify the `input_s3_uri` and `output_s3_uri` are within the buckets created by this module. |
| `Access Denied` to S3 | typo in uri                    | Verify the input and outputs are correct s3 locations.                                       |
| Job fails immediately | Missing parameters             | Ensure `input_s3_uri` and `output_s3_uri` are passed as parameters (`--parameters input_s3_uri=...,output_s3_uri=...`) to provide the required positional arguments. |
| Cannot download model | No internet access             | Ensure the subnets have a route to an IGW.                                                   |

#### Lambda functions
When system testing at the lambda function level, these problems may occur.

##### Problem: getting a `Runtime.ImportModuleError: Unable to import module 'lambda_function': No module named 'lambda_function'`
###### Solution: Ensure the lambda function is configured to use the correct runtime and handler. In this case
the handler should be `piicalculator.lambda_handler.handler` set in the terraform plan for `resource "aws_lambda_function"`

##### Problem: getting a `PIICalculation failed: Error reading CSV: Forbidden`
INFO]	2026-08-25T02:35:25.517Z	5fafd2b4-c97c-4d79-91e7-eccc15a22ef5	Received event: {'ticket': '123456789', 'input-s3-uri': 's3://pii-data-pipeline-input-dev/123456789/classified.csv', 'output-s3-uri': 's3://pii-data-pipeline-output-dev/123456789/pii-report.json'}
Reading CSV from: s3://pii-data-pipeline-input-dev/123456789/classified.csv
[INFO]	2026-08-25T02:35:33.563Z	5fafd2b4-c97c-4d79-91e7-eccc15a22ef5	Found credentials in environment variables.
[ERROR]	2026-08-25T02:35:35.602Z	5fafd2b4-c97c-4d79-91e7-eccc15a22ef5	PIICalculation failed: Error reading CSV: Forbidden
[ERROR] PIICalculatorError: Error reading CSV: Forbidden
Traceback (most recent call last):
File "/var/task/piicalculator/lambda_handler.py", line 56, in handler
pii_calculator(input_uri, output_uri)
File "/var/task/piicalculator/calculator.py", line 41, in pii_calculator
raise PIICalculatorError(f"Error reading CSV: {e}")
###### Solution: The input file was missing from the S3 bucket. Using aws cli ensure the file is there or put a file 
in place for testing.


## Assumptions

1. **CloudWatch Retention**: The requirement specified a 2-day retention, but AWS CloudWatch only supports specific values. 3 days was chosen as the nearest valid value (1 day was also an option, but 3 provides slightly more buffer for debugging).
2. **Fargate Spot**: To maximize cost savings, Fargate Spot is enabled by default (`use_fargate_spot = true`).
3. **Egress**: The Batch security group is restricted to outbound traffic on ports 443 (HTTPS), 53 (DNS), and 123 (NTP) to ensure the job can interact with AWS services and fetch necessary data while maintaining a strong security posture.
4. **Networking**: When providing `existing_vpc_id` and `existing_subnet_ids`, the module verifies that the subnets have a path to the internet (via IGW) to satisfy the outbound internet requirement. Since we use public subnets with locked-down security groups, NAT Gateways are not required, saving costs.
5. **Job Architecture**: The job definition explicitly specifies `ARM64` architecture.

# Tips
## Check Fargate Spot Availability:
Fargate capacity is managed by AWS, but you can check service health if jobs are stuck.