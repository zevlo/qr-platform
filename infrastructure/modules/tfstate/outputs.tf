output "bucket_name" {
  value = aws_s3_bucket.this.id
}

output "ddb_table" {
  value = aws_dynamodb_table.locks.name
}
