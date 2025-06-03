# S3 Bucket
module "s3_bucket" {
  source = "./s3"
}

# IAM Role & Instance Profile
module "iam" {
  source = "./iam"
}

# 查找现有的 Work VPC
data "aws_vpc" "work_vpc" {
  filter {
    name   = "tag:Name"
    values = ["Work VPC"]  # 替换为你的 VPC 实际名称
  }
}

# Network (VPC, Subnet, Security Group)
module "network" {
  source = "./network"
  work_vpc_id = data.aws_vpc.work_vpc.id
}

module "rds" {
  source                 = "./rds"
  db_user                = var.db_user
  db_password            = var.db_password
  vpc_security_group_ids = [module.network.rds_security_group_id, module.network.security_group_web_sg_id]
  subnet_ids             = module.network.private_subnet_rds_ids
  db_subnet_group_name   = module.network.db_subnet_group_name
}

# EC2 Instance
module "ec2" {
  source                = "./ec2"
  instance_type         = var.instance_type
  key_name              = var.key_name
  subnet_id             = module.network.private_subnet_web_id
  subnet_ids             = [module.network.private_subnet_web_id, module.network.private_subnet_web2_id]
  vpc_security_group_ids = [module.network.security_group_web_sg_id]
  iam_instance_profile = "Work-Role"
  google_api_key = var.google_api_key
  s3_bucket      = module.s3_bucket.bucket_name
  db_host        = regex("(.*):\\d+$", module.rds.rds_endpoint)[0]
  db_user        = var.db_user
  db_password    = var.db_password
  target_group_arn = module.network.web_target_group_arn
}

# Lambda: Annotation
module "lambda_annotation" {
  source = "./lambda/annotation"
  s3_bucket = module.s3_bucket.bucket_name
  s3_bucket_arn = module.s3_bucket.bucket_arn
  db_host        = regex("(.*):\\d+$", module.rds.rds_endpoint)[0]
  db_user        = var.db_user
  db_password    = var.db_password
  google_api_key = var.google_api_key
  lambda_subnet_ids = [module.network.private_subnet_web_id, module.network.private_subnet_web2_id]
  lambda_security_group_id = module.network.lambda_security_group_id
}

# Lambda: Thumbnail
module "lambda_thumbnail" {
  source = "./lambda/thumbnail"
  s3_bucket = module.s3_bucket.bucket_name
  s3_bucket_arn = module.s3_bucket.bucket_arn
  lambda_subnet_ids = [module.network.private_subnet_web_id, module.network.private_subnet_web2_id]
  lambda_security_group_id = module.network.lambda_security_group_id
}

# S3 Bucket Notification for Lambda triggers
resource "aws_s3_bucket_notification" "image_upload_notification" {
  bucket = module.s3_bucket.bucket_id

  lambda_function {
    lambda_function_arn = module.lambda_annotation.lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "thumbnails/"
  }

  lambda_function {
    lambda_function_arn = module.lambda_thumbnail.lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "images/"
  }

  depends_on = [
    module.lambda_annotation.lambda_permission,
    module.lambda_thumbnail.lambda_permission
  ]
}