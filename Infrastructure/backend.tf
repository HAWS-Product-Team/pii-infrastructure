#When switching between dev and prod environments, update the key on line 6 to either 
# "dev/terraform.tfstate" or "pii-infrastructure/terraform.tfstate"

terraform {
  backend "s3" {
    bucket = "pii-tf-state"
    //    key          = "prod/terraform.tfstate"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}


