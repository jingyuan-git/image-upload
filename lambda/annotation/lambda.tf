variable "s3_bucket_arn" {
  description = "S3 bucket ARN"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket name"
  type        = string
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}"
  output_path = "${path.module}/lambda.zip"
}

data "aws_iam_role" "existing_lambda_role" {
  name = "LabRole" # 替换为已有角色的名称
}

resource "aws_lambda_function" "annotation" {
  function_name    = "annotation-function"
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  role             = data.aws_iam_role.existing_lambda_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      # 可设置API KEY等
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