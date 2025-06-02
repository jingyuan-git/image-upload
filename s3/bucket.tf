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

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "image_upload" {
  bucket = "image-upload-${random_id.suffix.hex}"
}


# resource "aws_s3_bucket_acl" "image_upload_acl" {
#   bucket = aws_s3_bucket.image_upload.id
#   acl    = "private"
# }

# resource "aws_s3_bucket_policy" "private_access" {
#   bucket = aws_s3_bucket.image_upload.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Sid       = "DenyPublicReadWrite",
#         Effect    = "Deny",
#         Principal = "*",
#         Action    = ["s3:GetObject", "s3:PutObject"],
#         Resource  = "${aws_s3_bucket.image_upload.arn}/*",
#         Condition = {
#           Bool = {
#             "aws:SecureTransport" : "false"
#           }
#         }
#       }
#     ]
#   })
# }