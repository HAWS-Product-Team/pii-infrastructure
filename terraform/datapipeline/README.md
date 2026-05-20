# Data Pipeline Infrastructure

This module provisions the infrastructure required for the PII data pipeline.

## Components

- **ECR Repository**: Stores the application container image.
- **S3 Buckets**: Dedicated buckets for input and output data.
- **AWS Batch**: 
  - **Compute Environment**: Managed Fargate/Fargate Spot environment.
  - **Job Queue**: Prioritized queue for batch jobs.
  - **Job Definition**: Configured for Fargate ARM64 with logging and S3 access.
- **IAM Roles**: Least-privilege roles for Batch service, ECS execution, and job runtime.
- **Networking**: Optional creation of VPC/Subnets or reuse of existing ones.

## Operations Manual

### 1. Container Image Management

The pipeline runs on **Fargate ARM64 (Graviton-equivalent)**. You must build your container image for the `linux/arm64` platform.

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

You can trigger a job using the AWS CLI. You need to provide the input and output S3 URIs as environment variable overrides.

#### Command Template

```bash
aws batch submit-job \
    --job-name pii-processing-job-$(date +%Y%m%d%H%M%S) \
    --job-queue <JOB_QUEUE_NAME> \
    --job-definition <JOB_DEFINITION_NAME> \
    --container-overrides '{
        "environment": [
            {"name": "INPUT_S3_URI", "value": "s3://<INPUT_BUCKET>/data/input.csv"},
            {"name": "OUTPUT_S3_URI", "value": "s3://<OUTPUT_BUCKET>/results/output.json"}
        ]
    }'
```

### 3. Inputs and Outputs

- **Inputs**:
    - `INPUT_S3_URI`: Full S3 path to the file to be processed. The job role has read access to the input bucket.
- **Outputs**:
    - `OUTPUT_S3_URI`: Full S3 path where results should be stored. The job role has write access to the output bucket.
- **Logs**:
    - All container logs (stdout/stderr) are sent to CloudWatch Logs under the log group provided in the outputs.

### 4. Troubleshooting

| Issue | Potential Cause | Resolution |
|-------|-----------------|------------|
| Job stuck in `RUNNABLE` | No compute resources available | Check if `max_vcpus` is > 0 and if the Fargate Spot market has capacity. |
| `Exec format error` | Wrong image architecture | Ensure the image was built for `linux/arm64`. Check build steps. |
| `Access Denied` to S3 | IAM permissions | Verify the `INPUT_S3_URI` and `OUTPUT_S3_URI` are within the buckets created by this module. |
| Job fails immediately | Missing env vars | Ensure `INPUT_S3_URI` and `OUTPUT_S3_URI` are passed in `container-overrides`. |
| Cannot download model | No internet access | Ensure the subnets have a route to an IGW or NAT Gateway. |

## Assumptions

1. **CloudWatch Retention**: The requirement specified a 2-day retention, but AWS CloudWatch only supports specific values. 3 days was chosen as the nearest valid value (1 day was also an option, but 3 provides slightly more buffer for debugging).
2. **Fargate Spot**: To maximize cost savings, Fargate Spot is enabled by default (`use_fargate_spot = true`).
3. **Egress**: The Batch security group allows all outbound traffic to ensure the job can download models from Hugging Face and interact with AWS services.
4. **Networking**: When providing `existing_vpc_id` and `existing_subnet_ids`, the module verifies that the subnets have a path to the internet (via IGW or NAT Gateway) to satisfy the outbound internet requirement.
5. **Job Architecture**: The job definition explicitly specifies `ARM64` architecture.

# Tips
## Check Fargate Spot Availability:
Fargate capacity is managed by AWS, but you can check service health if jobs are stuck.