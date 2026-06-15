# pii-infrastructure
Infrastructure for Personal Inflation Index

What this infrastructure uses:
- terraform with shared state to an s3 bucket
- AWS Amplify for continuous deployment
- to run the terraform plan, you'll need a personal access token for GitHub so Amplify can access the application repository

What this infrastructure does:
Creates the infrastructure for the Personal Inflation Index application.  The application is in a separate repo.

## First-time user setup

### 1) Prerequisites
Install these tools first:

- AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Terraform: https://developer.hashicorp.com/terraform/install

### 2) Create your AWS access key (before running setup script)
You need an IAM user access key so `aws configure` can create your local CLI profile.

1. In AWS Console, go to **IAM** → **Users**.
2. Create or open your IAM user (avoid using root account keys).
3. Open **Security credentials**.
4. Under **Access keys**, choose **Create access key**.
5. Save both values securely:
   - Access key ID
   - Secret access key (shown only once)

### 3) Run the repo setup script
From the repo root:
bash ./setup_account_profile.sh

### What `setup_account_profile.sh` does
The script performs first-time local setup for this repo:

1. Verifies `aws` CLI is installed.
2. Verifies `terraform` is installed.
3. Checks for AWS profile `pii-infrastructure` (or your override).
4. If the profile is missing, runs `aws configure --profile <profile>` interactively so you can enter:
    - AWS Access Key ID
    - AWS Secret Access Key
    - Default region
    - Output format
5. Exports:
    - `AWS_PROFILE=<profile>`
    - `AWS_REGION=us-east-1`
6. Verifies credentials with `aws sts get-caller-identity`.
7. Runs `terraform init -reconfigure`.

If all steps pass, your local environment is ready for Terraform commands in this repo.
NOTE: if you wish to use a different AWS profile than your default, you'll need to set `AWS_PROFILE` before running Terraform
or AWS CLI.

For example:
```bash
aws sts get-caller-identity
```

If that returns a different account ID or user, you'll need to either set the environment variable
AWS_PROFILE or change your default profile in `~/.aws/config`.
For example, in my case, I have a profile called `pii-infrastructure` that has my access key and secret key, and it's 
not the default profile.  So to use that profile, I run:
```bash
AWS_PROFILE=pii-infrastructure aws sts get-caller-identity

AWS_PROFILE=pii-infrastructure terraform plan
```

# Troubleshooting
## Problem: Access denied when running a terraform command.
If you haven't before ran setup_account_profile.sh, run it to setup your local environment so that:
- AWS CLI is configured for your account and username used for PII
See instructions above.

If you have run setup_account_profile.sh, then you may have a different AWS profile than the default.
### Solution:  set ```AWS_PROFILE=pii-infrastructure``` before running terraform plan.

## Problem: var.amplify_github_token GitHub token used by Amplify to access the application repository
### Solution: Copy/paste your GitHub token into the prompt, or put it in a *local* file ```.github/amplify.tfvars```
If you don't have a GitHub token and don't know the steps to make one, see the steps to doing this in the 
Discored reference channel.
The token for *Amplify* should have the following permissions:
- Repository access: you need to grant access to the repository that contains the application code. 
- Repository permissions:
  - Administration: Read and write (needed for webhook/deploy key management)
  - Contents: Read-only (Amplify needs to read your source)
  - Metadata: Read-only (typically required by GitHub API access patterns)

## Problem: Error: Error acquiring the state lock happens when running terraform commands.
And you're certain that you are the only one running terraform at the moment.
### Solution1:
Check that you're running the command with the correct AWS_PROFILE.  If you are, move to solution2.
### Solution2: 
Assuming no one else is running terraform while you ran the command (including yourself as you may be running
it in another terminal), a lock can be left behind if you
recently crashed terraform or canceled (ctl-c) a terraform operation. 
Here is how to clear the lock:
```bash
terraform force-unlock <insert lock ID from error message>
```
As always, you'll need to have AWS_PROFILE set or have the correct default profile in your ~/.aws/config file.

CAUTION: Never delete terraform.tfstate in S3 to “fix” this or you'll have clean up your infrastructure from 
the AWS console.

## Problem: Error: Error refreshing state: Unable to access object "dev/terraform.tfstate" in S3 bucket "pii-tf-state": operation error S3: HeadObject, https response error StatusCode: 403 Forbidden
### Solution:
Check that you're running the command with the correct AWS_PROFILE.

## Problem: Error: Backend initialization required, please run "terraform init"
### Solution: terraform init -reconfigure
If the backend state location changed because you switched from "dev" to "prod" this error will
happen which is normal.  Typically you want to do:
`terraform init -migrate-state`
and you can decide if you want update the state file to what is in AWS or use what's in the statefile. Terraform 
will ask you which you want to do in an interactive manner.

## Problem:  Error: Backend configuration changed
Something has happened to get my local terraform unhappy with the remote state.
When I run plan I get the first problem. When I run init I get the second problem.

## Problem: Upon running `terraform apply` I get errors that the state and reality in AWS do not match.
### Solution: use `terraform import <state object> <aws name>` to import the state from AWS into Terraform
Sometimes you'll be required to remove the existing state with `terraform rm <state object>`
Copy and pasting the errors into AI will allow it to generate the imports you need to run.
After the state is imported, you may need to run `terraform apply` again to apply the changes.  
Sometimes during apply, more errors will crop up and you need to import more state.
I don't know the root cause of this situation.  We have two devops people and we are supporting two environments, 
so it's hard to know what got us in this situation. 

## Problem: Error: reading IAM Policy (tf-state-access):...1 validation error detected: Value at 'policyArn' failed to satisfy constraint: Member must have length greater than or equal to 20
This occurred when doing a:
terraform import aws_iam_policy.tf_state_access tf-state-access
### Solution: AWS requires an ARN when referring to IAM policies, not just the short name 'tf-state-access'
The error Member must have length greater than or equal to 20 indicates that Terraform is trying to use the short name tf-state-access as the ARN, but AWS requires the full ARN for IAM policies.
This is the format: arn:aws:iam::<ACCOUNT_ID>:policy/<POLICY_NAME>
you can find it in your AWS Console URL, or by running:
`aws sts get-caller-identity --query Account --output text`
Then the format of the command is:
`terraform import aws_iam_policy.tf_state_access arn:aws:iam::226778503410:policy/tf-state-access`
#### General Rule for IAM Imports
For IAM Roles and IAM Policies, you almost always need to use the full ARN for the import ID, not just the name.

#### Summary of Import IDs
- IAM Policy: Use the ARN (arn:aws:iam::...:policy/...)
- IAM Role: Use the Name (role-name)
- IAM User: Use the Name (user-name)
- S3 Bucket: Use the Bucket Name (bucket-name)
- ECR Repository: Use the Repository Name (repo-name)
- CloudWatch Log Group: Use the Log Group Name (/aws/...)

## Problem: Error: Failed to load plugin schemas
I tried to run `terraform plan` after changing to a different shared state file.
The error you're seeing is a classic symptom of a provider version mismatch or corrupted provider cache after changing your state file. The null provider plugin is failing to start, likely because:
1. The provider version in your terraform.lock.hcl doesn't match what's in your .terraform/providers directory
2. The provider binary is corrupted or incompatible
3. There's a mismatch between the provider version expected by the state and the one installed

### Solution: clean up the corrupted provider cache
# Remove the corrupted provider cache
`rm -rf .terraform/providers`

# Re-initialize with the correct providers
`terraform init -reconfigure`
The -reconfigure flag forces Terraform to re-download and re-verify all providers.
