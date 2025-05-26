variable "s3_bucket" {
  description = "S3 bucket name"
  type        = string
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/"
  output_path = "${path.module}/thumbnail_lambda.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_thumbnail_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_lambda_function" "thumbnail" {
  function_name    = "thumbnail-generator"
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      # 可根据需要添加环境变量
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnail.function_name
  principal     = "s3.amazonaws.com"
  # source_arn 可以在主模块里用
}

output "lambda_arn" {
  value = aws_lambda_function.thumbnail.arn
}

output "lambda_permission" {
  value = aws_lambda_permission.allow_s3.id
}