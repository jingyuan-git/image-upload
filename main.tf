# S3 Bucket
module "s3_bucket" {
  source = "./s3"
}

# IAM Role & Instance Profile
# module "iam" {
#   source = "./iam"
# }

# Network (VPC, Subnet, Security Group)
module "network" {
  source = "./network"
  work_vpc_id = var.work_vpc_id
}

module "rds" {
  source                 = "./rds"
  db_user                = var.db_user
  db_password            = var.db_password
  vpc_security_group_ids = [module.network.security_group_id]
  subnet_ids             = module.network.private_subnet_rds_ids
  db_subnet_group_name   = module.network.db_subnet_group_name
}

# EC2 Instance
module "ec2" {
  source                = "./ec2"
  instance_type         = var.instance_type
  key_name              = var.key_name
  subnet_id             = module.network.private_subnet_web_id
  vpc_security_group_ids = [module.network.security_group_id]
  iam_instance_profile  = "EC2InstanceProfile"

  # google_api_key = var.google_api_key
  s3_bucket      = module.s3_bucket.bucket_name
  db_host        = module.rds.rds_endpoint
  db_user        = var.db_user
  db_password    = var.db_password
}

# Lambda: Annotation
module "lambda_annotation" {
  source = "./lambda/annotation"
  s3_bucket = module.s3_bucket.bucket_name
  s3_bucket_arn = module.s3_bucket.bucket_arn
}

# Lambda: Thumbnail
module "lambda_thumbnail" {
  source = "./lambda/thumbnail"
  s3_bucket = module.s3_bucket.bucket_name
  s3_bucket_arn = module.s3_bucket.bucket_arn
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