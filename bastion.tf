# Region-aware Amazon Linux 2 AMI via SSM public parameter
data "aws_ssm_parameter" "amzn2" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.amzn2.value
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_bastion.id
  associate_public_ip_address = true
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name

  tags = { Name = "bastion" }
}