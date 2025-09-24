variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name to assign to the AWS Key Pair"
  type        = string
  default     = "all-in-one-key"
}

variable "public_key_path" {
  description = "Path to your SSH public key (must exist before apply)"
  type        = string
  default     = "~/.ssh/cloudshell-key.pub"
}

variable "my_ip_cidr" {
  description = "CIDR block allowed for SSH access (e.g., your IP/32)"
  type        = string
  default     = "0.0.0.0/0"
}
