# Story 2 — Agent Execution Contract
## Title
Data Pipeline Infrastructure for Processing User Data (AWS Batch POC)

## Goal
Provision Terraform infrastructure for a CPU-only AWS Batch POC that runs a containerized Python inference job which:
1. pulls model artifacts from Hugging Face at runtime,
2. reads one CSV input object from S3,
3. writes one JSON output object to S3,
4. emits stdout/stderr to CloudWatch Logs.

---

## Scope (In)
Create Terraform-managed AWS resources for:
- ECR repository (application image)
- S3 input and output buckets
- CloudWatch Log Group
- AWS Batch:
  - managed EC2 compute environment (Spot, CPU-only)
  - job queue
  - job definition
- IAM roles/policies required for Batch + job runtime
- Networking required for outbound internet access

## Scope (Out)
- Application source code/container build pipeline
- Event orchestration (no SQS/API Gateway in this story)
- Cross-account setup
- Multi-region deployment
- Production hardening beyond explicit requirements

---

## Implementation Location
This is a child module invoked from root main.tf.
- `terraform/datapipeline/` 

Agent must keep Story 2 changes isolated and clearly named.

---

## Required Inputs (Terraform Variables)
- `app_name` (string) with a default of "pii"
- `environment` (string) with a default of "dev"
- `aws_region` (string) with a default of "us-east-1"

Networking:
- `existing_vpc_id` (string, nullable, default = null)
- `existing_subnet_ids` (list(string), nullable, default = null)

Batch sizing:
- `batch_min_vcpus` (number, default = 0)
- `batch_desired_vcpus` (number, default = 0)
- `batch_max_vcpus` (number, default = 16)

Batch instance types (default fixed for this story):
- `batch_instance_types` default:
  - `["c7g.large", "c6g.large", "m7g.large", "m6g.large"]`

Job runtime defaults:
- `job_vcpu` (number, default = 2)
- `job_memory_mb` (number, default = 4096)
- `job_timeout_seconds` (number, default = 1800)
- `job_retry_attempts` (number, default = 1)

Data paths:
- `input_key_prefix` (string, default = "input/")
- `output_key_prefix` (string, default = "output/")

---

## Naming Contract (Must Follow)
- ECR repo: `<app>-ecr-<env>`
- Compute environment: `<app>-batch-ce-<env>`
- Job queue: `<app>-batch-queue-<env>`
- Job definition: `<app>-batch-jobdef-<env>`
- Log group: `/aws/batch/<app>/<env>`

---

## Resource Requirements

### 1) ECR
Must create exactly one repository for the app image.
- Enable scan on push: **true**
- Lifecycle policy: keep latest 20 images (POC-friendly)

Output:
- repository URL

---

### 2) S3
Create exactly two buckets:

- `\<app>-data-pipeline-input-\<env>`
- `\<app>-data-pipeline-output-\<env>`

Where:
- `app = pii`
- `env = dev` (for this story)

So for current defaults:
- `pii-data-pipeline-input-dev`
- `pii-data-pipeline-output-dev`

#### A Prefix Layout (Required)

##### Input bucket (ephemeral)
```plain text
Input:  s3://pii-data-pipeline/input/tenant=<tenant_id>/job=<job_id>/input.csv
Output: s3://pii-data-pipeline/output/tenant=<tenant_id>/job=<job_id>/result.json

##### Optional error artifact (recommended)
```plain text
s3://<output-bucket>/output/tenant=<tenant_id>/job=<job_id>/error.json
```

#### C Naming Rules for Path Tokens

- `tenant_id`: lowercase alphanumeric + hyphen, max 64 chars  
  Regex: `^[a-z0-9-]{1,64}$`
- `job_id`: UUIDv4 string (preferred) or equivalent unique ID  
  Regex (UUIDv4): `^[a-f0-9-]{36}$`
- `input.csv` is fixed filename for Story 2
- `result.json` is fixed filename for Story 2

#### D Object Contract

##### Input CSV object
- Exactly one CSV per job path
- Content-Type: `text/csv`
- Required URI passed to job: `INPUT_S3_URI`

##### Output JSON object
- Exactly one result JSON per job path
- Content-Type: `application/json`
- Required URI passed to job: `OUTPUT_S3_URI`

#### E Lifecycle & Deletion Policy

##### Input bucket
- job deletes processed input object on success

##### Output bucket
- job deletes output object on success

#### F IAM Scope (Least Privilege)

Job role must allow:

- `s3:GetObject` on:
  - `arn:aws:s3:::<input-bucket>/input/*`
- `s3:DeleteObject` on:
  - `arn:aws:s3:::<input-bucket>/input/*`
- `s3:PutObject` on:
  - `arn:aws:s3:::<output-bucket>/output/*`

Optional (if app needs listing):
- `s3:ListBucket` on both buckets with prefix constraints:
  - `input/`
  - `output/`

No bucket deletion permissions.

#### G Encryption & Public Access

For both buckets:
- SSE-S3 enabled (`AES256`)
- Block all public access = true
- ACLs disabled / bucket-owner enforced (POC-safe default)

#### H Terraform Variables to Add

- `input_prefix` default: `"input/"`
- `output_prefix` default: `"output/"`
- `input_retention_days` default: `2`
- `output_retention_days` default: `14` (or `null` to disable lifecycle)

#### I Example URIs

```plain text
INPUT_S3_URI=s3://pii-data-pipeline-input-dev/input/tenant=acme/job=550e8400-e29b-41d4-a716-446655440000/input.csv
OUTPUT_S3_URI=s3://pii-data-pipeline-output-dev/output/tenant=acme/job=550e8400-e29b-41d4-a716-446655440000/result.json
```

---

### 3) CloudWatch Logs
Must create one log group:
- name `/aws/batch/<app>/<env>`
- retention = **2 days**

Job definition must route container logs here.

Output:
- log group name

### 4) AWS Batch
#### Compute environment (managed EC2)
- Type: managed EC2
- Allocation: Spot capacity
- **CPU-only** instance types (no GPU families)
- Allowed instance types default to:
  - `c7g.large`, `c6g.large`, `m7g.large`, `m6g.large`
- Internet egress is mandatory

#### Job queue
- Enabled = true
- Attached to compute environment

#### Job definition
- Container image from created ECR repository
- Container image must be ARM64-compatible (or multi-arch).
- No GPU requirements
- Resource requirements:
  - VCPU = `job_vcpu`
  - MEMORY = `job_memory_mb`
- Logging to created CloudWatch Log Group
- Support passing runtime values as environment variables:
  - `INPUT_S3_URI`
  - `OUTPUT_S3_URI`
  - `MODEL_ID`
- Timeout = `job_timeout_seconds`
- Retry attempts = `job_retry_attempts`

Outputs:
- job queue name
- job definition name

---

## Networking Contract (Deterministic)
If `existing_vpc_id` and `existing_subnet_ids` are provided:
- Reuse them.
- Do not create new VPC/subnets.
- Ensure Batch instances have outbound internet access path.
- If user supplies existing VPC/subnets without egress, fail fast with a clear error

If not provided:
- Create minimal VPC networking for POC:
  - VPC
  - 2 public subnets across 2 AZs
  - Internet Gateway
  - Route table with default route to IGW
  - Security group allowing all egress
- Use this networking for Batch compute resources.

Reason: simplest reliable path for Hugging Face + AWS service access in POC.

Outputs:
- vpc id
- subnet ids
- security group id used by compute resources

---

## IAM Contract (Minimum Needed)
Create least-privilege roles/policies for:
1. Batch service role
2. EC2 instance profile role for ECS/BATCH host
3. Job role (container runtime permissions)

Job role must include:
- S3 read on input bucket/prefix
- S3 write on output bucket/prefix
- S3 delete object permissions for cleanup (input/output buckets)
- CloudWatch Logs write permissions required by runtime/log driver if needed
- ECR pull permissions (if execution path requires role-based pull in this setup)

Avoid wildcard `*` where practical; scope to created resources.

Outputs:
- relevant IAM role ARNs (service role, instance role/profile, job role)

---

## Non-Functional Constraints
- Terraform must be readable, minimal, and POC-appropriate.
- Use variables for environment-dependent values.
- No unnecessary services.
- Document assumptions inline (README or comments in story folder).

---

## Acceptance Criteria (Pass/Fail)
1. ECR repo exists and returns usable repo URL.
2. Input/output S3 buckets exist; IAM permissions allow required read/write (and object cleanup).
3. CloudWatch Log Group exists with 3-day retention.
4. Batch compute environment uses Spot CPU-only instances from approved types.
5. Job queue is enabled and connected to compute environment.
6. Job definition references ECR image and has CPU/memory/logging configured.
7. Batch job has outbound internet and can download model from Hugging Face.
8. Batch job can read CSV from input S3 URI and write JSON to output S3 URI.
9. Container logs are visible in CloudWatch Logs.
10. Terraform outputs include all required identifiers and ARNs.

---

## Required Outputs (Terraform)
At minimum:
- `ecr_repository_url`
- `input_bucket_name`
- `output_bucket_name`
- `cloudwatch_log_group_name`
- `batch_job_queue_name`
- `batch_job_definition_name`
- `vpc_id`
- `subnet_ids`
- `batch_service_role_arn`
- `batch_instance_role_arn` (or instance profile ARN)
- `batch_job_role_arn`

---

## Agent Delivery Checklist
- [ ] `terraform fmt` clean
- [ ] `terraform validate` passes
- [ ] plan shows only Story 2 resources
- [ ] names match naming contract exactly
- [ ] no GPU resource declarations
- [ ] job definition supports `INPUT_S3_URI`, `OUTPUT_S3_URI`, `MODEL_ID`
- [ ] outputs are complete
- [ ] assumptions documented
