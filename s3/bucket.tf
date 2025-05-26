variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

resource "aws_s3_bucket" "image_upload" {
  bucket = "image-upload-bucket-${var.aws_region}-${var.environment}"
}


resource "aws_s3_bucket_acl" "image_upload_acl" {
  bucket = aws_s3_bucket.image_upload.id
  acl    = "private"
}