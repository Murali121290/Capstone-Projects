terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "us-east-1"
}

# VPC lookup
data "aws_vpc" "default" {
  default = true
}

# Security Group
resource "aws_security_group" "ec2_sg" {
  ...
}

# EC2 instance
resource "aws_instance" "dev_server" {
  ami           = "ami-08c40ec9ead489470"
  instance_type = "t3.medium"
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    ...
  EOF

  tags = {
    Name        = "Dev-Server-Jenkins-SonarQube-Minikube"
    Environment = "Dev"
  }
}

# Output
output "public_ip" {
  value = aws_instance.dev_server.public_ip
}
