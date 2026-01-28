data "aws_caller_identity" "current" {}

# Bastion instance role/profile
resource "aws_iam_role" "bastion_role" {
  name = "BastionInstanceRole"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [{
      Effect : "Allow",
      Principal : { Service : "ec2.amazonaws.com" },
      Action : "sts:AssumeRole"
    }]
  })
  tags = { Purpose = "Bastion" }
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "BastionInstanceProfile"
  role = aws_iam_role.bastion_role.name
}

# IT Workstation: read-only access to IT CloudWatch Logs
resource "aws_iam_role" "NOC_ws_role" {
  name = "NOCWorkstationRole"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [{
      Effect : "Allow",
      Principal : { Service : "ec2.amazonaws.com" },
      Action : "sts:AssumeRole"
    }]
  })
  tags = { Department = "NOC", RoleType = "Workstation" }
}

resource "aws_iam_policy" "NOC_logs_readonly" {
  name        = "NOCLogsReadOnly"
  description = "Read-only to NOC CloudWatch log groups"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "DescribeLogs",
        Effect : "Allow",
        Action : ["logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:GetLogEvents", "logs:FilterLogEvents"],
        Resource : "*"
      },
      {
        Sid : "ReadNOCGroups",
        Effect : "Allow",
        Action : ["logs:GetLogEvents", "logs:FilterLogEvents", "logs:DescribeLogStreams"],
        Resource : [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${var.NOC_log_group_prefix}*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${var.NOC_log_group_prefix}*:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "NOC_ws_logs_ro_attach" {
  role       = aws_iam_role.NOC_ws_role.name
  policy_arn = aws_iam_policy.NOC_logs_readonly.arn
}

resource "aws_iam_instance_profile" "NOC_ws_profile" {
  name = "NOCWorkstationProfile"
  role = aws_iam_role.NOC_ws_role.name
}

# HR Workstation: exclusive access to HR bucket prefix
resource "aws_iam_role" "hr_ws_role" {
  name = "HRWorkstationRole"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [{
      Effect : "Allow",
      Principal : { Service : "ec2.amazonaws.com" },
      Action : "sts:AssumeRole"
    }]
  })
  tags = { Department = "HR", RoleType = "Workstation" }
}

resource "aws_iam_policy" "hr_bucket_rw" {
  name        = "HRBucketRW"
  description = "HR workstation can list hr/ prefix and RW objects under hr/ in HR bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "ListHRPrefixOnly",
        Effect : "Allow",
        Action : ["s3:ListBucket"],
        Resource : aws_s3_bucket.hr_bucket.arn,
        Condition : { "StringLike" : { "s3:prefix" : ["hr/*"] } }
      },
      {
        Sid : "RWHRPrefix",
        Effect : "Allow",
        Action : ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject"],
        Resource : "${aws_s3_bucket.hr_bucket.arn}/hr/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "hr_ws_bucket_attach" {
  role       = aws_iam_role.hr_ws_role.name
  policy_arn = aws_iam_policy.hr_bucket_rw.arn
}

resource "aws_iam_instance_profile" "hr_ws_profile" {
  name = "HRWorkstationProfile"
  role = aws_iam_role.hr_ws_role.name
}

# Accounting Workstation: access to Accounting bucket prefix
resource "aws_iam_role" "acct_ws_role" {
  name = "AccountingWorkstationRole"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [{
      Effect : "Allow",
      Principal : { Service : "ec2.amazonaws.com" },
      Action : "sts:AssumeRole"
    }]
  })
  tags = { Department = "Accounting", RoleType = "Workstation" }
}

resource "aws_iam_policy" "acct_bucket_rw" {
  name        = "AccountingBucketRW"
  description = "Accounting workstation can list acct/ prefix and RW objects under acct/ in Accounting bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "ListAcctPrefixOnly",
        Effect : "Allow",
        Action : ["s3:ListBucket"],
        Resource : aws_s3_bucket.acct_bucket.arn,
        Condition : { "StringLike" : { "s3:prefix" : ["acct/*"] } }
      },
      {
        Sid : "RWAcctPrefix",
        Effect : "Allow",
        Action : ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject"],
        Resource : "${aws_s3_bucket.acct_bucket.arn}/acct/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "acct_ws_bucket_attach" {
  role       = aws_iam_role.acct_ws_role.name
  policy_arn = aws_iam_policy.acct_bucket_rw.arn
}

resource "aws_iam_instance_profile" "acct_ws_profile" {
  name = "AccountingWorkstationProfile"
  role = aws_iam_role.acct_ws_role.name
}