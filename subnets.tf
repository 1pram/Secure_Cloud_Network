locals {
  az = "${var.aws_region}a"
}

# Public subnet (bastion)
resource "aws_subnet" "public_bastion" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = true
  tags                    = { Name = "public-bastion" }
}

# Private subnets (one per department)
resource "aws_subnet" "NOC_private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "NOC-private" }
}

resource "aws_subnet" "hr_private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "hr-private" }
}

resource "aws_subnet" "acct_private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "acct-private" }
}

# Route tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_bastion.id
  route_table_id = aws_route_table.public_rt.id
}

# Private route table (no NAT to save cost)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "private-rt" }
}

resource "aws_route_table_association" "NOC_assoc" {
  subnet_id      = aws_subnet.NOC_private.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "hr_assoc" {
  subnet_id      = aws_subnet.hr_private.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "acct_assoc" {
  subnet_id      = aws_subnet.acct_private.id
  route_table_id = aws_route_table.private_rt.id
}