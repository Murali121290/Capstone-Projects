provider "aws" {
  region = var.aws_region
}

# ✅ Automatically fetch latest Ubuntu 20.04 AMI for this region
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}
resource "aws_instance" "all_in_one" {
  ami           = data.aws_ami.ubuntu.id   # ✅ use AMI from data source
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name
}

resource "aws_security_group" "all_in_one_sg" {
  name        = "all-in-one-sg"
  description = "Allow SSH, HTTP, Jenkins, SonarQube ports"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

resource "aws_instance" "all_in_one" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.all_in_one_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name

  user_data = file("${path.module}/userdata.sh")

  tags = {
    Name = "all-in-one-ci-cd"
  }
}

resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-role"

  assume_role_policy = data.aws_iam_policy_document.jenkins_assume.json
}

data "aws_iam_policy_document" "jenkins_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "jenkins_ecr_policy" {
  name = "jenkins-ecr-policy"
  role = aws_iam_role.jenkins_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["ecr:*","s3:*","ec2:Describe*","logs:*","cloudwatch:*"],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins_role.name
}

resource "aws_ecr_repository" "app_repo" {
  name = "vulnerable-flask-app"
}

output "instance_id" {
  value = aws_instance.all_in_one.id
}

output "instance_public_ip" {
  value = aws_instance.all_in_one.public_ip
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}
