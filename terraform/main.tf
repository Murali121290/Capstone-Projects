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

# Lookup default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "dev_server_sg"
  description = "Allow SSH, HTTP, Jenkins, and SonarQube"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-server-sg"
  }
}

# EC2 instance
resource "aws_instance" "dev_server" {
  ami           = "ami-08c40ec9ead489470" # Amazon Linux 2023 us-east-1
  instance_type = "t3.medium"
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    set -xe

    # Update system
    dnf update -y

    # Install basic tools
    dnf install -y docker git curl wget unzip java-11-openjdk

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # Install Jenkins
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.repo -o /etc/yum.repos.d/jenkins.repo
    dnf install -y jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Run SonarQube (Docker)
    docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community

    # Install Minikube
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    install minikube-linux-amd64 /usr/local/bin/minikube

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  EOF

  tags = {
    Name        = "Dev-Server-Jenkins-SonarQube-Minikube"
    Environment = "Dev"
  }
}
