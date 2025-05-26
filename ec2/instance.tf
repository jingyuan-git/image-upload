resource "aws_instance" "web" {
  ami                    = "ami-0953476d60561c955"
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
  # iam_instance_profile   = var.iam_instance_profile
  tags                   = { Name = "Image-Upload-Web" }

  user_data = templatefile("${path.module}/user_data.sh", {
    google_api_key = var.google_api_key
    s3_bucket      = var.s3_bucket
    db_host        = var.db_host
    db_user        = var.db_user
    db_password    = var.db_password
    app_code       = replace(file("${path.module}/app.py"), "$", "\\$")
  })
}