output "instance_public_ips" {
  value = aws_instance.app[*].public_ip
}
