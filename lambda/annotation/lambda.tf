variable "s3_bucket_arn" {
  description = "S3 bucket ARN"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket name"
  type        = string
}

variable "google_api_key" {
  description = "Google API key for the Lambda function"
  type        = string
}

variable "db_host" {
  description = "Database host for the Lambda function"
  type        = string
}

variable "db_user" {
  description = "Database user for the Lambda function"
  type        = string
}

variable "db_password" {
  description = "Database password for the Lambda function"
  type        = string
}

data "aws_iam_role" "existing_lambda_role" {
  name = "LabRole" # 替换为已有角色的名称
}

# data "archive_file" "lambda_zip" {
#   type        = "zip"
#   source_dir  = "${path.module}"
#   output_path = "${path.module}/lambda.zip"
# }
# resource "aws_lambda_function" "annotation" {
#   function_name    = "annotation-function"
#   handler          = "main.lambda_handler"
#   runtime          = "python3.12"
#   role             = data.aws_iam_role.existing_lambda_role.arn
#   filename         = data.archive_file.lambda_zip.output_path
#   source_code_hash = data.archive_file.lambda_zip.output_base64sha256
#   timeout          = 30

#   environment {
#     variables = {
#       GOOGLE_API_KEY = var.google_api_key
#       DB_HOST       = var.db_host
#       DB_USER       = var.db_user
#       DB_PASSWORD   = var.db_password
#       DB_NAME       = "image_caption_db"
#     }
#   }
# }

resource "aws_lambda_function" "annotation" {
  function_name    = "annotation-function"
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  role             = data.aws_iam_role.existing_lambda_role.arn
  filename         = "${path.module}/lambda_function.zip"  # 直接指向已有的 zip 文件
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")  # 使用文件的哈希值
  timeout          = 30

  environment {
    variables = {
      GOOGLE_API_KEY = var.google_api_key
      DB_HOST       = var.db_host
      DB_USER       = var.db_user
      DB_PASSWORD   = var.db_password
      DB_NAME       = "image_caption_db"
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.annotation.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_bucket_arn
}

output "lambda_arn" {
  value = aws_lambda_function.annotation.arn
}

output "lambda_permission" {
  value = aws_lambda_permission.allow_s3.id
}