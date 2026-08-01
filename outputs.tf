output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of bastion host (for EC2 Instance Connect)"
  value       = aws_instance.bastion.id
}

output "NOC_private_ip" {
  description = "Private IP of NOC workstation"
  value       = aws_instance.NOC_ws.private_ip
}

output "hr_private_ip" {
  description = "Private IP of HR workstation"
  value       = aws_instance.hr_ws.private_ip
}

output "acct_private_ip" {
  description = "Private IP of Accounting workstation"
  value       = aws_instance.acct_ws.private_ip
}

output "noc_operator_role_arn" {
  description = "Role ARN for NOC operators to assume before connecting"
  value       = aws_iam_role.noc_operator.arn
}

output "hr_operator_role_arn" {
  description = "Role ARN for HR operators to assume before connecting"
  value       = aws_iam_role.hr_operator.arn
}

output "acct_operator_role_arn" {
  description = "Role ARN for Accounting operators to assume before connecting"
  value       = aws_iam_role.acct_operator.arn
}
