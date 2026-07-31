# Human operators for EC2 Instance Connect access to the bastion
# Assumable roles, not users: no long-lived operator credentials exist

# Who is allowed to assume the operator roles. Defaults to the calling
# identity so the lab works out of the box; override to scope more tightly.
data "aws_caller_identity" "current" {}

locals {
  operator_principal = coalesce(var.operator_principal_arn, data.aws_caller_identity.current.arn)
}

# EIC policy: push a short-lived SSH key to the bastion only, as ec2-user
resource "aws_iam_policy" "bastion_eic_connect" {
  name        = "BastionEICConnect"
  description = "Push an ephemeral SSH key to the bastion via EC2 Instance Connect"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "SendKeyToBastionOnly",
        Effect : "Allow",
        Action : "ec2-instance-connect:SendSSHPublicKey",
        Resource : aws_instance.bastion.arn,
        Condition : { "StringEquals" : { "ec2:osuser" : "ec2-user" } }
      },
      {
        Sid : "DescribeForConnect",
        Effect : "Allow",
        Action : "ec2:DescribeInstances",
        Resource : "*"
      }
    ]
  })
}

# Trust policy: the operator principal may assume these roles via STS
data "aws_iam_policy_document" "operator_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [local.operator_principal]
    }
  }
}

# One role per department. Separation past the bastion is by key pair; these
# roles exist so each perimeter entry is an assumed-role session with a name.
resource "aws_iam_role" "noc_operator" {
  name               = "noc-operator"
  assume_role_policy = data.aws_iam_policy_document.operator_assume.json
  tags               = { Department = "NOC", Purpose = "BastionOperator" }
}

resource "aws_iam_role" "hr_operator" {
  name               = "hr-operator"
  assume_role_policy = data.aws_iam_policy_document.operator_assume.json
  tags               = { Department = "HR", Purpose = "BastionOperator" }
}

resource "aws_iam_role" "acct_operator" {
  name               = "acct-operator"
  assume_role_policy = data.aws_iam_policy_document.operator_assume.json
  tags               = { Department = "Accounting", Purpose = "BastionOperator" }
}

# All three roles carry the same EIC grant; the bastion is the shared entry
resource "aws_iam_role_policy_attachment" "noc_eic" {
  role       = aws_iam_role.noc_operator.name
  policy_arn = aws_iam_policy.bastion_eic_connect.arn
}

resource "aws_iam_role_policy_attachment" "hr_eic" {
  role       = aws_iam_role.hr_operator.name
  policy_arn = aws_iam_policy.bastion_eic_connect.arn
}

resource "aws_iam_role_policy_attachment" "acct_eic" {
  role       = aws_iam_role.acct_operator.name
  policy_arn = aws_iam_policy.bastion_eic_connect.arn
}
