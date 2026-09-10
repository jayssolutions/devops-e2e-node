variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_security_group" { type = string }
variable "target_group_arn" { type = string }
variable "instance_type" { type = string }
variable "instance_count" { type = number }
variable "admin_cidr" { type = string }

variable "public_key" {
  type      = string
  sensitive = true
}
