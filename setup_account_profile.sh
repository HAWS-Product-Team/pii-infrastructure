#!/usr/bin/env bash
set -euo pipefail

# First-time setup for this repo:
# - Ensures aws + terraform are installed
# - Ensures AWS profile exists (creates it interactively if missing)
# - Verifies caller identity
# - Runs terraform backend init
#
# Usage:
#   ./setup_account_profile.sh
#
# Optional:
#   AWS_PROFILE_NAME=your-profile ./setup_account_profile.sh

AWS_PROFILE_NAME="pii-infrastructure"
AWS_REGION="us-east-1"

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI not found."
  echo "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "Error: terraform not found."
  echo "Install Terraform: https://developer.hashicorp.com/terraform/install"
  exit 1
fi

if ! aws configure list-profiles | grep -Fxq "$AWS_PROFILE_NAME"; then
  echo "AWS profile '$AWS_PROFILE_NAME' not found."
  echo "Creating it now with aws configure..."
  aws configure --profile "$AWS_PROFILE_NAME"

  if ! aws configure list-profiles | grep -Fxq "$AWS_PROFILE_NAME"; then
    echo "Error: failed to create AWS profile '$AWS_PROFILE_NAME'."
    exit 1
  fi
fi

export AWS_PROFILE="$AWS_PROFILE_NAME"
export AWS_REGION

echo "Using AWS_PROFILE=$AWS_PROFILE"
echo "Using AWS_REGION=$AWS_REGION"

echo "Verifying caller identity..."
aws sts get-caller-identity --no-cli-pager

echo "Initializing Terraform backend..."
terraform init -reconfigure

echo "You're ready to make and break infrastructure. Happy hunting!"
echo "If you've already set your aws default user profile, you'll need to set AWS_PROFILE to the correct profile name."
echo "So next time you create a shell, set that environment variable if running the following doesn't return the right account and username."
echo "aws sts get-caller-identity --no-cli-pager"