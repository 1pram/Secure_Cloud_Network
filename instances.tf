# One private workstation per department, SSH via bastion only
# Each instance uses its own key pair and its own department security group

# IT workstation
resource "aws_instance" "NOC_ws" {
  ami                         = data.aws_ssm_parameter.amzn2.value
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.NOC_private.id
  associate_public_ip_address = false
  key_name                    = aws_key_pair.noc_key.key_name
  vpc_security_group_ids      = [aws_security_group.noc_private_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.NOC_ws_profile.name

  tags = {
    Name       = "NOC-ws"
    Department = "NOC"
  }
}

# HR workstation
resource "aws_instance" "hr_ws" {
  ami                         = data.aws_ssm_parameter.amzn2.value
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.hr_private.id
  associate_public_ip_address = false
  key_name                    = aws_key_pair.hr_key.key_name
  vpc_security_group_ids      = [aws_security_group.hr_private_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.hr_ws_profile.name

  tags = {
    Name       = "hr-ws"
    Department = "HR"
  }
}

# Accounting workstation
resource "aws_instance" "acct_ws" {
  ami                         = data.aws_ssm_parameter.amzn2.value
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.acct_private.id
  associate_public_ip_address = false
  key_name                    = aws_key_pair.acct_key.key_name
  vpc_security_group_ids      = [aws_security_group.acct_private_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.acct_ws_profile.name

  tags = {
    Name       = "acct-ws"
    Department = "Accounting"
  }
}
