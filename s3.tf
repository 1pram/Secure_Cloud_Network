# HR departmental bucket
resource "aws_s3_bucket" "hr_bucket" {
  bucket = var.hr_bucket_name
  tags = {
    Department = "HR"
    Purpose    = "HRDocs"
  }
}

resource "aws_s3_bucket_public_access_block" "hr_block_public" {
  bucket                  = aws_s3_bucket.hr_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hr_sse" {
  bucket = aws_s3_bucket.hr_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Accounting departmental bucket
resource "aws_s3_bucket" "acct_bucket" {
  bucket = var.acct_bucket_name
  tags = {
    Department = "Accounting"
    Purpose    = "AcctDocs"
  }
}

resource "aws_s3_bucket_public_access_block" "acct_block_public" {
  bucket                  = aws_s3_bucket.acct_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "acct_sse" {
  bucket = aws_s3_bucket.acct_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}