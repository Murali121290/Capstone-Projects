provider "aws" {
  region = "us-east-1"
}

# Key pair (you should already have an SSH key in AWS)
variable "key_name" {
  default = "my-keypair" # replace with your actual key pair name
}

# Security group to allow SSH and HTTP
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow SSH and HTTP"
  vpc_id      = "vpc-xxxxxxxx" # replace with your VPC ID

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "example" {
  ami                    = "ami-08c40ec9ead489470" # Amazon Linux 2023 in us-east-1
  instance_type          = "t3.medium"
  key_name               = var.key_name
  security_groups        = [aws_security_group.ec2_sg.name]

  tags = {
    Name = "My-T3-Medium-Instance"
  }
}
