output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
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