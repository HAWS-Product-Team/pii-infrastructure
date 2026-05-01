# Data Pipeline Infrastructure (AWS Batch POC)

This module provisions the infrastructure required for the PII data pipeline POC.

## Components

- **ECR Repository**: Stores the application container image.
- **S3 Buckets**: Dedicated buckets for input and output data.
- **AWS Batch**: 
  - **Compute Environment**: Managed EC2 Spot environment using Graviton (ARM64) instances.
  - **Job Queue**: Prioritized queue for batch jobs.
  - **Job Definition**: Configured for ARM64 with logging and S3 access.
- **IAM Roles**: Least-privilege roles for Batch service, EC2 instances, and job runtime.
- **Networking**: Optional creation of VPC/Subnets or reuse of existing ones.

## Assumptions

1. **CloudWatch Retention**: The requirement specified a 2-day retention, but AWS CloudWatch only supports specific values. 3 days was chosen as the nearest valid value (1 day was also an option, but 3 provides slightly more buffer for debugging).
2. **Instance Types**: To ensure broad Graviton eligibility as requested, a list of families `c6g, c7g, c8g, m6g, m7g, m8g` was used. This avoids pinning to specific sizes while ensuring ARM64 architecture.
3. **Egress**: The Batch security group allows all outbound traffic to ensure the job can download models from Hugging Face and interact with AWS services.
4. **Networking**: When providing `existing_vpc_id` and `existing_subnet_ids`, it is assumed that the subnets have a path to the internet (via IGW or NAT Gateway) to satisfy the outbound internet requirement.
5. **Job Architecture**: The job definition explicitly specifies `ARM64` architecture to match the Graviton compute environment.
