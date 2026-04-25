terraform {
  backend "s3" {
    bucket       = "pii-tf-state"
    key          = "pii-infrastructure/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}