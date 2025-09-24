variable "aws_region" {
  description = "AWS region to deploy into"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"
}

variable "key_name" {
  description = "Key pair name for SSH access"
  default     = "all-in-one-key"
}

variable "public_key_path" {
  description = "Path to your SSH public key"
  default     = "~/.ssh/cloudshell-key.pub"
}

variable "my_ip_cidr" {
  description = "Your IP/CIDR to allow SSH access"
  default     = "0.0.0.0/0"
}
