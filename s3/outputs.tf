output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.image_upload.bucket
}

output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.image_upload.id
}

output "bucket_arn" {
  value = aws_s3_bucket.image_upload.arn
}