provider "aws" {
  region = var.aws_region
}

# S3 Bucket
module "s3_bucket" {
  source = "./s3"
}

# IAM Role & Instance Profile
module "iam" {
  source = "./iam"
}

# Network (VPC, Subnet, Security Group)
module "network" {
  source = "./network"
}

# EC2 Instance
module "ec2" {
  source = "./ec2"
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = module.network.subnet_id
  vpc_security_group_ids = [module.network.security_group_id]
  iam_instance_profile   = module.iam.instance_profile_name
}

# Lambda: Annotation
module "lambda_annotation" {
  source = "./lambda/annotation"
  s3_bucket = module.s3_bucket.bucket_name
  # 其他变量
}

# Lambda: Thumbnail
module "lambda_thumbnail" {
  source = "./lambda/thumbnail"
  s3_bucket = module.s3_bucket.bucket_name
  # 其他变量
}

# S3 Bucket Notification for Lambda triggers
resource "aws_s3_bucket_notification" "image_upload_notification" {
  bucket = module.s3_bucket.bucket_id

  lambda_function {
    lambda_function_arn = module.lambda_annotation.lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = module.lambda_thumbnail.lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".jpg"
  }

  depends_on = [
    module.lambda_annotation.lambda_permission,
    module.lambda_thumbnail.lambda_permission
  ]
}