variable "s3_bucket_arn" {
  description = "S3 bucket ARN"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket name"
  type        = string
}

variable "lambda_subnet_ids" {
  description = "List of subnet IDs for Lambda function VPC configuration"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda function VPC configuration"
  type        = string
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/"
  output_path = "${path.module}/thumbnail_lambda.zip"
}

data "aws_iam_role" "existing_lambda_role" {
  name = "LabRole" # 替换为已有角色的名称
}

resource "aws_lambda_function" "thumbnail" {
  function_name    = "thumbnail-generator"
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  role             = data.aws_iam_role.existing_lambda_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      # 可根据需要添加环境变量
    }
  }

  vpc_config {
    subnet_ids         = var.lambda_subnet_ids         # 子网 ID 列表
    security_group_ids = [var.lambda_security_group_id] # Lambda 的安全组 ID
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnail.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_bucket_arn
}

output "lambda_arn" {
  value = aws_lambda_function.thumbnail.arn
}

output "lambda_permission" {
  value = aws_lambda_permission.allow_s3.id
}