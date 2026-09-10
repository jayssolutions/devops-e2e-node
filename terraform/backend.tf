terraform {
  backend "s3" {
    bucket         = "devops-e2e-node"
    key            = "devops-e3e-node.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
