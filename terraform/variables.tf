variable "key_name" {
  description = "Name of the EC2 key pair in AWS (not the .pem file)."
  type        = string
  default     = "murali26jul2025"
}

variable "private_key_path" {
  description = "Local path to the private key (.pem) used for SSH."
  type        = string
  default     = "/home/ubuntu/.ssh/murali26jul2025.pem"
}
