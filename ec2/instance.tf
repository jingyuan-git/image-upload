resource "aws_instance" "web" {
  ami                    = "ami-0953476d60561c955"
instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  tags                   = { Name = "Image-Upload-Web" }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install python3-pip -y
    pip3 install flask mysql-connector-python google-generativeai boto3 werkzeug
    yum install -y mariadb105

    # 写入你的 Flask 应用代码到 /home/ec2-user/app.py
    cat > /home/ec2-user/app.py << 'EOPY'
${replace(file("${path.module}/app.py"), "$", "\\$")}
EOPY

    # 可选：设置环境变量（推荐用安全方式管理敏感信息）
    export GOOGLE_API_KEY="你的Gemini_API_Key"
    export S3_BUCKET="你的S3桶名"
    export DB_HOST="你的RDS地址"
    export DB_USER="你的RDS用户名"
    export DB_PASSWORD="你的RDS密码"

    # 启动 Flask 应用（后台运行）
    cd /home/ec2-user
    nohup python3 app.py > flask.log 2>&1 &
  EOF
}