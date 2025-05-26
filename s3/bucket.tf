resource "aws_s3_bucket" "image_upload" {
  bucket = "your-unique-bucket-name"
  acl    = "private"
}