variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "admin_ip" {
  description = "Your public IPv4 in CIDR form for SSH to bastion (e.g., 203.0.113.25/32)"
  type        = string
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name to use for SSH"
  type        = string
}

variable "hr_bucket_name" {
  description = "HR department S3 bucket name (must be globally unique)"
  type        = string
}

variable "acct_bucket_name" {
  description = "Accounting department S3 bucket name (must be globally unique)"
  type        = string
}

variable "NOC_log_group_prefix" {
  description = "Prefix for NOC CloudWatch log groups"
  type        = string
  default     = "/dept/NOC/"
}
