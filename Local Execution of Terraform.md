# Terraform + AWS Setup Guide

This guide walks you through setting up Terraform to manage infrastructure in our shared AWS account from your local machine.  This is a bootstrap until we get the infrastructure automated 
to deploy when changed (CD of infrastructure).  

---

## 1. Install the AWS CLI

The AWS CLI lets you interact with AWS from your terminal and is used by Terraform to authenticate.

**macOS (Homebrew):**
```bash
brew install awscli
```

**Windows (MSI installer):**
Download from: https://aws.amazon.com/cli/

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Verify installation:**
```bash
aws --version
```

---

## 2. Install Terraform

**macOS (Homebrew):**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Windows (Chocolatey):**
```powershell
choco install terraform
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update && sudo apt-get install terraform
```

**Verify installation:**
```bash
terraform --version
```

---

## 3. Set Up AWS Credentials

Since you're an administrator on the account, you have a couple of options.

### Option A: Create Access Keys (simplest for local dev)

1. Log into the AWS Console
2. Go to **IAM → Users → [Your User] → Security credentials**
3. Click **Create access key**
4. Choose "Command Line Interface (CLI)" as the use case
5. Save the Access Key ID and Secret Access Key securely

### Option B: Use IAM Identity Center (SSO)

If the account uses IAM Identity Center, run:
```bash
aws configure sso
```
Follow the prompts to authenticate via your browser.

---

## 4. Configure AWS CLI

### For Access Keys (Option A):

Run the configure command:
```bash
aws configure
```

You'll be prompted for:
```
AWS Access Key ID: [paste your access key]
AWS Secret Access Key: [paste your secret key]
Default region name: us-east-1          # or your preferred region
Default output format: json
```

This creates `~/.aws/credentials` and `~/.aws/config` files.

### Verify it works:
```bash
aws sts get-caller-identity
```

You should see output like:
```json
{
    "UserId": "AIDAEXAMPLEID",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

## 5. Environment Variables (Alternative/Override)

Instead of (or in addition to) the config files, you can use environment variables. These take precedence over the config files.

**bash/zsh (~/.bashrc or ~/.zshrc):**
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**PowerShell:**
```powershell
$env:AWS_ACCESS_KEY_ID="your-access-key-id"
$env:AWS_SECRET_ACCESS_KEY="your-secret-access-key"
$env:AWS_DEFAULT_REGION="us-east-1"
```

**When to use environment variables:**
- Temporary credentials or testing
- CI/CD pipelines
- Switching between multiple accounts quickly

---

## 6. Create Your First Terraform Project

Create a project directory:
```bash
mkdir my-terraform-project
cd my-terraform-project
```

Create a `main.tf` file:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"  # Change to your preferred region
}

# Example: Create an S3 bucket
resource "aws_s3_bucket" "example" {
  bucket = "my-unique-bucket-name-12345"  # Must be globally unique

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

---

## 7. Terraform Workflow

### Initialize the project:
```bash
terraform init
```
This downloads the AWS provider plugin.

### Preview changes:
```bash
terraform plan
```
Review what Terraform will create/modify/destroy.

### Apply changes:
```bash
terraform apply
```
Type `yes` to confirm and create the infrastructure.

### View current state:
```bash
terraform show
```

### Destroy infrastructure (when done testing):
```bash
terraform destroy
```

---

## 8. Project Structure Best Practices

For anything beyond simple experiments, organize your files:

```
my-project/
├── main.tf          # Primary resources
├── variables.tf     # Input variable declarations
├── outputs.tf       # Output values
├── terraform.tfvars # Variable values (don't commit secrets!)
└── .gitignore       # Ignore sensitive files
```

**Example .gitignore:**
```
# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
crash.log

# Credentials
.aws/
```

---

## 9. Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| "No valid credential sources found" | Run `aws configure` or check env vars |
| "Access Denied" | Check IAM permissions, verify correct account |
| "Error acquiring state lock" | Another terraform process running, or stale lock |
| Provider version conflicts | Run `terraform init -upgrade` |

### Useful debug commands:
```bash
# Check current AWS identity
aws sts get-caller-identity

# Enable Terraform debug logging
export TF_LOG=DEBUG
terraform plan

# Disable debug logging
unset TF_LOG
```

---

## Summary Checklist

- [ ] AWS CLI installed and working (`aws --version`)
- [ ] Terraform installed (`terraform --version`)
- [ ] AWS credentials configured (`aws sts get-caller-identity` works)
- [ ] Created project directory with `main.tf`
- [ ] Ran `terraform init` successfully
- [ ] Ran `terraform plan` to preview changes

You're ready to start building infrastructure! Let me know if you run into any issues.
