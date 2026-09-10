data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 1. Generate SSH Private Key (ED25519 for AL2023 compatibility)
resource "tls_private_key" "ansible" {
  algorithm = "ED25519"
}

# 2. Upload OpenSSH Public Key to AWS EC2 Key Pair
resource "aws_key_pair" "node_app" {
  key_name   = "${var.project_name}-key"
  public_key = trimspace(tls_private_key.ansible.public_key_openssh)
}

# 3. Save Private Key locally with 0600 permissions for Ansible
resource "local_file" "ansible_private_key" {
  content         = tls_private_key.ansible.private_key_openssh
  filename        = "${path.module}/id_ed25519"
  file_permission = "0600"
}

resource "aws_security_group" "app" {
  name   = "${var.project_name}-app-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "Application traffic from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.alb_security_group]
  }

  ingress {
    description = "SSH for Ansible"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  count                       = var.instance_count
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.node_app.key_name
  subnet_id                   = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-app-${count.index + 1}"
    Role = "application"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = var.instance_count
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.app[count.index].id
  port             = 3000
}

# Generates ansible_inventory.ini dynamically without requiring template files
resource "local_file" "ansible_inventory" {
  content = format(
    "[app_servers]\n%s\n\n[app_servers:vars]\nansible_user=ec2-user\nansible_ssh_private_key_file=./id_ed25519\nansible_ssh_common_args='-o StrictHostKeyChecking=no'",
    join("\n", aws_instance.app[*].public_ip)
  )
  filename = "${path.module}/ansible_inventory.ini"
}