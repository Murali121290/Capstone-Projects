variable "aws_region" { default = "us-east-1" }
variable "ami_id" { default = "ami-0a91cd140a1fc148a" } # Ubuntu 20.04 (change if needed)
variable "instance_type" { default = "t3.medium" }
variable "key_name" { default = "all-in-one-key" }
variable "public_key_path" {
  default = "~/.ssh/cloudshell-key.pub"
}
variable "my_ip_cidr" { default = "0.0.0.0/0" }
