variable "aws_region" {
  type    = string
  default = "us-east-1"
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
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDa+1ZCsHFgWb7WRP5QLdPQdcEgJAU9It6Bkj9nd/Al+ELekthC7VfI5tiK4UqeI5ovGG3zLZrWJ72ZjkbNdR5rvwePUaRnFO5lrxvKJ112nTBJEO4ovL/E5fmnatuvQqbLYC2/OLDLt4Ebeuw4DwZIuk8R04yzyb4ZENM91jZIRlKc2EEYb1FWLaDDI/+87QbVvlcHitqZNQIH8LjAavzAHCTd3p/Xa59YDADoPfhCK/ZqVyD45EmjLLKt5VlNaSOn/lwI0OjK3Msv9Os9tBbSPfZWNkOEbEJAXbQIUiN1mnstzt/gcwtP9ZoqOk9lPsxdQMHnVEEVRxSUDX996Cd5kcxc8qfGMyOZQ8j8TeaDx61yCL9xGJKqkhWqzO6wChGAnG5aA9azcdm4GO6P+GHFrUhLx6s37ERXgLZcASz46t4haVAEbeX5pX5VQopOfw+lrtD+6E1dlwUo3GgBODGsobhXDJjHjoX98+E11eXcr2AsPQFo6RUsVx+GsKxUjCc= jagad@Jagan-DeLL"
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
