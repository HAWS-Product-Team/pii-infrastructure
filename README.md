# pii-infrastructure
Infrastructure for Personal Inflation Index

What this infrastructure uses:
- terraform with shared state to an s3 bucket
- AWS Amplify for continuous deployment
- a personal access token for GitHub so Amplify can access the application repository

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
NOTE: if you're using a different AWS profile than your default, you'll need to set `AWS_PROFILE` before running Terraform
or AWS CLI.

For example:
```bash
aws sts get-caller-identity
```

If that returns a different account ID or user, you'll need to either set the environment variable
AWS_PROFILE or change your default profile in `~/.aws/config`.
For example:
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
  - Administration: Read and write (needed for webhook/deploy key management)  <-- write permission on this makes me nervous.
  - Contents: Read-only (Amplify needs to read your source)
  - Metadata: Read-only (typically required by GitHub API access patterns)

## Problem: Error: Error acquiring the state lock happens when running terraform commands. And your certain that you
are the only one running terraform at the moment.
### Solution: 
Assuming no one else is running terraform while you ran the command (including yourself as you may be running
it in another terminal), a lock can be left behind if you
recently crashed terraform or canceled (ctl-c) a terraform operation. 
Here is how to clear the lock:
```bash
terraform force-unlock 0146952e-ce9c-261c-67fa-3ce34a5e642f
```
As always, you'll need to have AWS_PROFILE set or have the correct default profile in your ~/.aws/config file.

CAUTION: Never delete terraform.tfstate in S3 to “fix” this or you'll have clean up your infrastructure from 
the AWS console.