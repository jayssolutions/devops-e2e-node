variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "project_name" {
  type    = string
  default = "devops-e2e-node"
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "instance_count" {
  description = "Number of application EC2 instances"
  type        = number
  default     = 2
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH for Ansible"
  type        = string
  default     = "127.0.0.1/32"
}

variable "public_key" {
  description = "SSH public key content"
  type        = string
  sensitive   = true
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "assessment"
    ManagedBy   = "Terraform"
  }
}
