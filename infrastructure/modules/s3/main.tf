# Pre-existing bucket created manually in Phase 0 (ACLs enabled for upstream's
# ACL='public-read' put_object call). Imported, not created.

resource "aws_s3_bucket" "qr_codes" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "qr_codes" {
  bucket = aws_s3_bucket.qr_codes.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "qr_codes" {
  depends_on = [aws_s3_bucket_ownership_controls.qr_codes]

  bucket = aws_s3_bucket.qr_codes.id
  acl    = "private"
}

# Inline policy attached to the api pod's IRSA role (see modules/iam-irsa).
resource "aws_iam_policy" "write" {
  name        = "${var.bucket_name}-write"
  description = "Allow PutObject / GetObject on ${var.bucket_name} for the api pod."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectAcl", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.qr_codes.arn,
          "${aws_s3_bucket.qr_codes.arn}/*",
        ]
      }
    ]
  })
}
