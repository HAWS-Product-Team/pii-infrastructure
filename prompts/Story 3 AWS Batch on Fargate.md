# Story 3 — Agent Execution Contract
## Title
AWS Batch on Fargate for Processing User Data (Spot)

## Goal
This is a hard migration from AWS Batch EC2 Spot to AWS Batch Fargate Spot.

The module should no longer maintain an EC2 Batch compute path. EC2-specific Batch instance roles, instance profiles, allocation strategy, and instance type settings should be removed from the active implementation.

The only retained Batch capacity switch is `use_fargate_spot`, which controls whether compute resources use `FARGATE_SPOT` or `FARGATE`.
This change aims to simplify compute management while maintaining cost-efficiency through Spot instances.

---

## Scope (In)
Update/Modify Terraform-managed AWS resources for:
- AWS Batch Compute Environment:
  - Transition from `EC2` to `FARGATE` type.
  - Enable `FARGATE_SPOT` capacity provider.
- AWS Batch Job Definition:
  - Update to support Fargate requirements.
  - Specify `FARGATE` platform requirements (vCPU, Memory, Fargate Platform Version).
  - Ensure compatibility with ARM64 architecture (Graviton-equivalent).
- IAM Roles:
  - Ensure Execution Role and Job Role are correctly configured for Fargate.
- Networking:
  - Ensure Fargate tasks are launched in the appropriate subnets with correct security groups.

## Scope (Out)
- No changes to ECR repository structure.
- No changes to S3 bucket structure or lifecycle policies.
- No changes to CloudWatch Logs group (though retention might be reviewed).
- No changes to application source code (must remain ARM64 compatible).

---

## Implementation Location
The changes will be applied to the existing child module:
- `terraform/datapipeline/`

---

## Implementation Clarifications

- Add `use_fargate_spot` (bool, default = true). This is the only Batch capacity switch.
- Compute resources must use:
  - `type = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"`
- Add `fargate_platform_version` (string, default = "LATEST").
- Use `jsonencode()` for `aws_batch_job_definition.container_properties`.
- `aws_batch_job_definition` must include:
  - `platform_capabilities = ["FARGATE"]`
  - `fargate_platform_configuration { platform_version = var.fargate_platform_version }`
- Container properties must include:
  - `runtimePlatform.operatingSystemFamily = "LINUX"`
  - `runtimePlatform.cpuArchitecture = "ARM64"`
  - distinct `executionRoleArn`
  - distinct `jobRoleArn`
  - `networkConfiguration.assignPublicIp`
- Create a distinct ECS task execution role and attach:
  - `arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`
- CloudWatch Logs and ECR image pull permissions belong to the execution role.
- S3 application permissions belong to the job role.
- Remove EC2 Batch instance role/profile resources and outputs if unused.
- Update README and outputs to reflect Fargate.

## Required Inputs

Add:
- `use_fargate_spot` (bool, default = true)
- `fargate_platform_version` (string, default = "LATEST")

Keep:
- `batch_max_vcpus`
- `job_vcpu`
- `job_memory_mb`

`job_vcpu` and `job_memory_mb` must form a supported AWS Fargate CPU/memory combination. Defaults remain:
- `job_vcpu = 2`
- `job_memory_mb = 4096`
Terraform variable validation should prevent unsupported Fargate CPU/memory combinations where practical.

Validation must allow only supported AWS Fargate Linux CPU/memory pairs:
- 2 vCPU: 4096–16384 MB in 1024 MB increments
- 4 vCPU: 8192–30720 MB in 1024 MB increments
- 8 vCPU: 16384–61440 MB in 4096 MB increments
- 16 vCPU: 32768–122880 MB in 8192 MB increments

Remove EC2 Batch-only resources from the active Fargate implementation, including:
- EC2 Batch instance role
- EC2 instance profile
- EC2 allocation strategy usage
- EC2 instance type settings
- min/desired vCPU settings for EC2 compute environments
- `batch_allocation_strategy`
- `batch_min_vcpus`
- `batch_desired_vcpus`
- EC2 instance family/generation/architecture variables

---

## Naming Contract
Maintain consistency with Story 2:
- Compute environment: `<app>-batch-ce-fargate-<env>`
- Job queue: `<app>-batch-queue-<env>` (Reuse or update if necessary)
- Job definition: `<app>-batch-jobdef-fargate-<env>`

---

## Resource Requirements

### 1) AWS Batch Compute Environment
- **Type**: `FARGATE`
- **Compute Resources**:
  - `type = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"`
  - `max_vcpus` = `var.batch_max_vcpus`
  - `subnets` = `local.subnet_ids`
  - `security_group_ids` = `[aws_security_group.batch_sg.id]`

### 2) AWS Batch Job Definition

- `platform_capabilities = ["FARGATE"]`
- Terraform-level `fargate_platform_configuration` with `platform_version = var.fargate_platform_version`

The `aws_batch_job_definition` must include:

fargate_platform_configuration {
  platform_version = var.fargate_platform_version
}

- Container properties JSON containing:
  "runtimePlatform": {
  "operatingSystemFamily": "LINUX",
  "cpuArchitecture": "ARM64"
}
  - `executionRoleArn`
  - `jobRoleArn`
---
## Agent Delivery Checklist
- [ ] `terraform fmt` clean
- [ ] `terraform validate` passes
- [ ] No EC2 instance roles or profiles remaining in the Fargate path
- [ ] ARM64 architecture is explicitly set in the job definition
- [ ] Fargate Spot is used for cost savings
- [ ] Networking configuration for Fargate tasks is correct (subnets, security groups, public IP)

---

## Networking Contract (Deterministic)
The batch execution environment will need outgoing public internet access but cannot be accessed by the public internet.
If `existing_vpc_id` and `existing_subnet_ids` are provided:
- Reuse them.
- Do not create new VPC/subnets.
- Ensure Batch Fargate tasks have an outbound internet access path.
- If user supplies existing VPC/subnets without egress, fail fast with a clear error

For existing subnets, Terraform must use AWS route table data sources to verify each supplied subnet has an effective
route table with at least one IPv4 default route (`0.0.0.0/0`) whose target is either:
- Internet Gateway (`gateway_id` starts with `igw-`)
- NAT Gateway (`nat_gateway_id` is set)

Fail during plan/apply using a Terraform precondition if any supplied subnet lacks this route.
Every subnet in `existing_subnet_ids` must have outbound internet access, because AWS Batch may place jobs in any supplied subnet.
---

## IAM Contract

- Batch Service Role:
  - Keep AWS Batch service role for managed compute environments.

- Execution Role:
  - Attach AWS managed policy `arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy` to the execution role.

- Execution Role:
  - Must be assumable by `ecs-tasks.amazonaws.com`.
  - Must include `AmazonECSTaskExecutionRolePolicy` or equivalent ECR + CloudWatch Logs permissions.
  - Used as `executionRoleArn`.

- Job Role:
  - Must be assumable by `ecs-tasks.amazonaws.com`.
  - Must retain S3 input/output permissions from Story 2.
  - Used as `jobRoleArn`.

- EC2 Batch instance role/profile:
  - Must not be used by the Fargate compute environment.
  - Should be removed if no longer needed by the module.

---

Create a distinct ECS task execution role for `executionRoleArn`.

The execution role:
- is assumable by `ecs-tasks.amazonaws.com`
- has `AmazonECSTaskExecutionRolePolicy` or equivalent permissions
- is used for ECR image pull and CloudWatch Logs

The job role:
- is assumable by `ecs-tasks.amazonaws.com`
- retains application S3 permissions
- is used as `jobRoleArn`

---

## Acceptance Criteria (Pass/Fail)
1. Batch compute environment is created with type `FARGATE` and compute resources use `FARGATE_SPOT` when `use_fargate_spot = true`, otherwise `FARGATE`.
2. Job definition has `platformCapabilities` set to `FARGATE`.
3. Job definition specifies `ARM64` runtime platform.
4. Job definition includes a valid `executionRoleArn` and `jobRoleArn`.
5. Batch jobs can be successfully submitted to the Fargate queue.
6. Batch jobs running on Fargate Spot can access S3, and Hugging Face (outbound internet).
7. Container logs are visible in CloudWatch Logs.
8. Terraform plan shows the replacement of EC2 compute environment with Fargate.

---

## Agent Delivery Checklist
- [ ] `terraform fmt` clean
- [ ] `terraform validate` passes
- [ ] No EC2 instance roles or profiles remaining in the Fargate path
- [ ] ARM64 architecture is explicitly set in the job definition
- [ ] Fargate Spot is used for cost savings
- [ ] Networking configuration for Fargate tasks is correct (subnets, security groups, public IP)
---
Implementation must account for AWS Batch replacement ordering:
- create the new Fargate compute environment
- update the job queue to reference the new compute environment
- remove the old EC2 compute environment and EC2 IAM resources from state/config

Use lifecycle/create-before-destroy where needed to avoid job queue referencing a deleted compute environment.

Documentation:
- Update `terraform/datapipeline/README.md` to describe AWS Batch Fargate/Fargate Spot instead of EC2 Spot.
- Remove EC2 instance troubleshooting and replace it with Fargate-specific troubleshooting.

Outputs:
- Remove EC2 instance role/profile outputs if no longer applicable.
- Add `batch_execution_role_arn`.
- Preserve existing externally useful outputs where possible.
