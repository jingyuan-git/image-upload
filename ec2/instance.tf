resource "local_file" "app_py" {
  filename = "${path.module}/app.py"
  content  = templatefile("${path.module}/app.py.tpl", {
    google_api_key = var.google_api_key,
    s3_bucket      = var.s3_bucket,
    s3_region      = "us-east-1",
    db_host        = var.db_host,
    db_name        = "image_caption_db",
    db_user        = var.db_user,
    db_password    = var.db_password
  })
}

# resource "aws_s3_object" "templates" {
#   for_each = fileset("${path.module}/templates", "**/*") # 遍历 templates 文件夹中的所有文件

#   bucket = var.s3_bucket
#   key    = each.value                                   # S3 中的对象键
#   source = "${path.module}/templates/${each.value}"    # 本地文件路径
# } 

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "target_tracking_cpu" {
  name                   = "target-tracking-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.web.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 25.0  # Target value for Average CPU utilization
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "web-launch-template"
  image_id      = "ami-0953476d60561c955" # Replace with your AMI ID
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = var.subnet_id
    security_groups             = var.vpc_security_group_ids
  }

  # Base64-encode the user_data
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    google_api_key = var.google_api_key
    s3_bucket      = var.s3_bucket
    db_host        = var.db_host
    db_user        = var.db_user
    db_password    = var.db_password
    app_code       = replace(local_file.app_py.content, "$", "\\$")
    templates_dir  = join("\n", [
      for file in fileset("${path.module}/templates", "**/*") :
      "cat <<EOF > /home/ec2-user/templates/${file}\n${file("${path.module}/templates/${file}")}\nEOF"
    ])
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Image-Upload-Web"
    }
  }
}

resource "aws_autoscaling_group" "web" {
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  min_size         = 1
  max_size         = 3
  desired_capacity = 1
  vpc_zone_identifier = var.subnet_ids # Replace with a list of subnets for multiple AZs

  target_group_arns = [var.target_group_arn]

  default_instance_warmup = 60

  tag {
    key                 = "Name"
    value               = "Image-Upload-Web"
    propagate_at_launch = true
  }
}

# resource "aws_instance" "web" {
#   ami                    = "ami-0953476d60561c955"
#   instance_type          = var.instance_type
#   key_name               = var.key_name
#   subnet_id              = var.subnet_id
#   vpc_security_group_ids = var.vpc_security_group_ids
#   # iam_instance_profile   = var.iam_instance_profile
#   tags                   = { Name = "Image-Upload-Web" }

#   user_data = templatefile("${path.module}/user_data.sh", {
#     google_api_key = var.google_api_key
#     s3_bucket      = var.s3_bucket
#     db_host        = var.db_host
#     db_user        = var.db_user
#     db_password    = var.db_password
#     app_code       = replace(local_file.app_py.content, "$", "\\$")
#     templates_dir  = join("\n", [
#       for file in fileset("${path.module}/templates", "**/*") :
#       "cat <<EOF > /home/ec2-user/templates/${file}\n${file("${path.module}/templates/${file}")}\nEOF"
#     ])
#   })
# }

# resource "aws_lb_target_group_attachment" "web" {
#   target_group_arn = var.target_group_arn
#   target_id        = aws_instance.web.id
#   port             = 80
# }