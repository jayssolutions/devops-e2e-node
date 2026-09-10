terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "jays-devops-tf-state-bucket"
    key            = "devops-e2e-node/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile = true
    encrypt        = true
  }
}