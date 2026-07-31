# Bastion: SSH only from your admin IP
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from admin IP only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bastion-sg" }
}

# One security group per department, replacing the shared private_ssh_sg
# No rule permits department-to-department traffic (deny by default)

# NOC private instances: SSH allowed only from bastion SG
resource "aws_security_group" "noc_private_sg" {
  name        = "noc-private-sg"
  description = "Allow SSH from bastion only - NOC department"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion SG"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "noc-private-sg", Department = "NOC" }
}

# HR private instances: SSH allowed only from bastion SG
resource "aws_security_group" "hr_private_sg" {
  name        = "hr-private-sg"
  description = "Allow SSH from bastion only - HR department"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion SG"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hr-private-sg", Department = "HR" }
}

# Accounting private instances: SSH allowed only from bastion SG
resource "aws_security_group" "acct_private_sg" {
  name        = "acct-private-sg"
  description = "Allow SSH from bastion only - Accounting department"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion SG"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "acct-private-sg", Department = "Accounting" }
}
