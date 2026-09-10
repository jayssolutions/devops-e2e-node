output "instance_public_ips" {
  description = "Public IP addresses of application instances"
  value       = aws_instance.app[*].public_ip
}