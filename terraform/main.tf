# ─────────────────────────────────────────────────
# terraform/main.tf
# Provisions a single EC2 instance on AWS to host
# the Spring PetClinic Docker container.
# ─────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── Provider ──────────────────────────────────────
provider "aws" {
  region = var.aws_region
}

# ── Variables ─────────────────────────────────────
variable "aws_region" {
  description = "AWS region"
  default     = "eu-west-1"   # Ireland – closest to Tralee
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"    # Free-tier eligible
}

variable "key_name" {
  description = "Name of the AWS key pair for SSH access"
  default     = "petclinic-key"
}

# ── Security Group ────────────────────────────────
resource "aws_security_group" "petclinic_sg" {
  name        = "petclinic-sg"
  description = "Allow HTTP and SSH access"

  # SSH – restrict to your IP in production!
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application port
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "petclinic-sg"
    Project = "DevOps-Assignment"
  }
}

# ── EC2 Instance ──────────────────────────────────
resource "aws_instance" "petclinic" {
  # Amazon Linux 2023 AMI (eu-west-1) – check for latest in your region
  ami                    = "ami-0d64bb532e0502c46"
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.petclinic_sg.id]

  # Install Docker on first boot via user_data script
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name    = "petclinic-server"
    Project = "DevOps-Assignment"
  }
}

# ── Elastic IP ────────────────────────────────────
# Gives the instance a stable public IP that does
# not change when the instance is stopped/started.
resource "aws_eip" "petclinic_eip" {
  instance = aws_instance.petclinic.id
  domain   = "vpc"

  tags = {
    Name = "petclinic-eip"
  }
}

# ── Outputs ───────────────────────────────────────
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_eip.petclinic_eip.public_ip
}

output "instance_public_dns" {
  description = "Public DNS hostname of the EC2 instance"
  value       = aws_instance.petclinic.public_dns
}

output "app_url" {
  description = "URL to access the deployed application"
  value       = "http://${aws_eip.petclinic_eip.public_ip}:9090"
}
