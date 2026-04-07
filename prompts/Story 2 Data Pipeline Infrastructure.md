# Story 2 Data Pipeline infrastructure for processing user data
The data pipeline operates using AWS Batch. 100% of the data is stored in S3.
Build Terraform for an AWS Batch POC with the following requirements **exactly**:

## Objective
Provision infrastructure to run a containerized Python inference job on AWS Batch.

The job must:
- run on **CPU-only Spot instances**
- download a **Hugging Face model at runtime**
- read **one specific CSV file from S3**
- write **one specific JSON file to S3**
- send container logs to **CloudWatch Logs**
- have **outbound internet access** because the model is downloaded at runtime

## Resources to create

### 1) ECR
Create:
- one ECR repository for the application image

Requirements:
- output the repository URL
- apply a reasonable lifecycle policy if convenient
- enable image scanning if convenient

---

### 2) S3
Create:
- one S3 bucket for input
- one S3 bucket for output

Requirements:
- input bucket will store one known CSV file
- output bucket will store one JSON result file per run
- grant the Batch job permission to:
    - read the input object(s)
    - write the output object(s)
- enable encryption if convenient
- keep the setup simple and POC-friendly

---

### 3) CloudWatch Logs
Create:
- one CloudWatch Log Group for AWS Batch job logs

Requirements:
- set a log retention period of 2 days.
- configure the job definition so stdout/stderr goes there

---

### 4) AWS Batch
Create:
- one managed **EC2 compute environment**
- one Batch job queue
- one Batch job definition

Requirements for compute environment:
- **Spot instances** of the following types: c8g.large, c7g.large, m7g.large
- **CPU-only**
- no GPU instance types
- use the following instance type: g4.medium
- internet access from the compute instances
- create the minimum networking required
- if private subnets are used, include NAT or another solution that allows outbound internet access

Requirements for job queue:
- enabled
- attached to the compute environment

Requirements for job definition:
- reference the ECR image
- set CPU and memory appropriate for a CPU inference job
- configure CloudWatch Logs
- allow passing input/output S3 URIs as environment variables or parameters
- do not require GPU resources

---

## Networking requirements
The Batch job must be able to:
- reach **Hugging Face over the internet**
- access **S3**
- access **ECR**
- write **CloudWatch Logs**

Use the simplest networking design that satisfies this. For the POC, prioritize correctness and simplicity over optimization.

---

## IAM requirements
Create the minimum necessary IAM roles/policies for:
- AWS Batch service role
- ECS/EC2 instance profile or execution role as needed
- S3 read/write permissions for the job
- when the job is finished, the batch will delete the input/output S3 objects to keep data private
- ECR pull permissions
- CloudWatch Logs permissions

Use least privilege where practical.

---

## Outputs
Terraform should output at least:
- ECR repository URL
- input S3 bucket name
- output S3 bucket name
- CloudWatch log group name
- Batch job queue name
- Batch job definition name
- any VPC/subnet identifiers used
- any IAM role ARNs that are useful for job submission or debugging

---

## Naming
Use clear environment-based names such as:
- `<app>-ecr-<env>`
- `<app>-data-pipeline-input-<env>`
- `<app>-data-pipeline-output-<env>`
- `<app>-batch-ce-<env>`
- `<app>-batch-queue-<env>`
- `<app>-batch-jobdef-<env>`
- `/aws/batch/<app>/<env>`

---

## Implementation expectations
- Prefer clean, readable Terraform
- Put the data pipeline infrastructure in a separate terraform plan called `data-pipeline.tf`
- Use variables for environment-specific values
- Keep the design minimal and POC-appropriate
- Do not add unnecessary services
- Document any assumptions made

---

## Acceptance criteria
The Terraform is correct only if:
1. ECR repo exists and can host the image
2. S3 input/output buckets exist and permissions are correct
3. CloudWatch log group exists with retention set
4. Batch compute environment uses Spot CPU instances
5. Batch job queue and job definition are wired correctly
6. Job can reach the internet for Hugging Face downloads
7. Job can read input from S3 and write output JSON to S3
8. Logs appear in CloudWatch
9. Terraform outputs are complete and usable
