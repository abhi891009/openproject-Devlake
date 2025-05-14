terraform {
  backend "s3" {
    bucket         = "Abhi100_bucket121"
    key            = "Terraform_state_file/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = false
  }
}
