output "bucket_name" {
  value = aws_s3_bucket.qr_codes.id
}

output "bucket_arn" {
  value = aws_s3_bucket.qr_codes.arn
}

output "write_policy_arn" {
  value = aws_iam_policy.write.arn
}
