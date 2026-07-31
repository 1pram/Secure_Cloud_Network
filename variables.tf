variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "admin_ip" {
  description = "Your public IPv4 in CIDR form for SSH to bastion (e.g., 203.0.113.25/32)"
  type        = string
}

variable "noc_public_key_path" {
  description = "Path to the NOC department SSH public key (.pub)"
  type        = string
  default     = "keys/noc-key.pub"
}

variable "hr_public_key_path" {
  description = "Path to the HR department SSH public key (.pub)"
  type        = string
  default     = "keys/hr-key.pub"
}

variable "acct_public_key_path" {
  description = "Path to the Accounting department SSH public key (.pub)"
  type        = string
  default     = "keys/acct-key.pub"
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

variable "operator_principal_arn" {
  description = "IAM principal ARN allowed to assume the operator roles. Defaults to the calling identity."
  type        = string
  default     = null
}
