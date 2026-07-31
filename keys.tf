# One key pair per department, replacing the single shared master key
# Generate the pairs locally before applying (see docs/deployment.md)

resource "aws_key_pair" "noc_key" {
  key_name   = "noc-key"
  public_key = file(var.noc_public_key_path)
  tags       = { Department = "NOC" }
}

resource "aws_key_pair" "hr_key" {
  key_name   = "hr-key"
  public_key = file(var.hr_public_key_path)
  tags       = { Department = "HR" }
}

resource "aws_key_pair" "acct_key" {
  key_name   = "acct-key"
  public_key = file(var.acct_public_key_path)
  tags       = { Department = "Accounting" }
}
