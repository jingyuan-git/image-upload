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

variable "lambda_subnet_ids" {
  description = "List of subnet IDs for Lambda function VPC configuration"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda function VPC configuration"
  type        = string
}

data "aws_iam_role" "existing_lambda_role" {
  name = "LabRole" # 替换为已有角色的名称
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}"
  output_path = "${path.module}/lambda.zip"
}
resource "aws_lambda_function" "annotation" {
  function_name    = "annotation-function"
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  role             = data.aws_iam_role.existing_lambda_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 120

  environment {
    variables = {
      GOOGLE_API_KEY = var.google_api_key
      DB_HOST       = var.db_host
      DB_USER       = var.db_user
      DB_PASSWORD   = var.db_password
      DB_NAME       = "image_caption_db"
    }
  }

  # 配置 VPC
  vpc_config {
    subnet_ids         = var.lambda_subnet_ids         # 子网 ID 列表
    security_group_ids = [var.lambda_security_group_id] # Lambda 的安全组 ID
  }
}

# # 使用 null_resource 运行 Docker 构建和打包
# resource "null_resource" "lambda_package" {
#   triggers = {
#     dockerfile_hash = filemd5("${path.module}/Dockerfile")
#     main_py_hash    = filemd5("${path.module}/main.py")
#     requirements_hash = filemd5("${path.module}/requirements.txt")
#     timestamp = timestamp()
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       cd ${path.module}
      
#       # 构建 Docker 镜像
#       docker build -t lambda-builder .
      
#       # 创建临时目录
#       rm -rf ./temp_build
#       mkdir -p ./temp_build
      
#       # 运行容器并复制文件到临时目录
#       docker run --rm -v $(pwd)/temp_build:/out lambda-builder
      
#       # 创建 zip 包
#       cd ./temp_build
#       zip -r ../lambda_function.zip .
      
#       # 清理临时目录
#       cd ..
#       rm -rf ./temp_build
#     EOT
    
#     working_dir = path.module
#   }
# }

# # Lambda 函数
# resource "aws_lambda_function" "annotation" {
#   function_name    = "annotation-function"
#   handler          = "main.lambda_handler"
#   runtime          = "python3.12"
#   role             = data.aws_iam_role.existing_lambda_role.arn
#   filename         = "${path.module}/lambda_function.zip"
#   timeout          = 60
#   memory_size      = 512

#   environment {
#     variables = {
#       GOOGLE_API_KEY = var.google_api_key
#       DB_HOST       = var.db_host
#       DB_USER       = var.db_user
#       DB_PASSWORD   = var.db_password
#       DB_NAME       = "image_caption_db"
#     }
#   }

#   depends_on = [null_resource.lambda_package]
# }

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