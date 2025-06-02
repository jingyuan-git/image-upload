#!/bin/bash

# 设置日志文件
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "$(date): Starting user data script execution..."

sudo yum update -y
echo "$(date): System update completed"

sudo yum install python3-pip -y
echo "$(date): Python3-pip installation completed"

sudo pip3 install flask mysql-connector-python google-generativeai boto3 werkzeug
echo "$(date): Python packages installation completed"

sudo yum install -y mariadb105
echo "$(date): MariaDB client installation completed"

# 写入你的 Flask 应用代码到 /home/ec2-user/app.py
echo "$(date): Writing Flask application code..."
cat > /home/ec2-user/app.py << 'EOPY'
${app_code}
EOPY
echo "$(date): Flask application code written successfully"

# 创建 templates 文件夹
mkdir -p /home/ec2-user/templates

# 将 templates 文件夹中的文件写入到 EC2 实例
${templates_dir}

# 设置环境变量
export GOOGLE_API_KEY="${google_api_key}"
export S3_BUCKET="${s3_bucket}"
export DB_HOST="${db_host}"
export DB_USER="${db_user}"
export DB_PASSWORD="${db_password}"
echo "$(date): Environment variables set"

# 初始化RDS数据库和表
echo "$(date): Starting database initialization..."
SQL_COMMANDS=$(cat <<EOSQL
DROP DATABASE IF EXISTS image_caption_db;
CREATE DATABASE image_caption_db;
USE image_caption_db;
CREATE TABLE captions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    image_key VARCHAR(255) NOT NULL,
    caption TEXT NOT NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOSQL
)

echo "$(date): Creating database and table..."
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "$SQL_COMMANDS"
if [ $? -eq 0 ]; then
    echo "$(date): Database and table created successfully!"
else
    echo "$(date): Error: Failed to create database and table. Please check the connection details and try again."
    exit 1
fi

# 启动 Flask 应用（后台运行）
echo "$(date): Starting Flask application..."
cd /home/ec2-user
nohup python3 app.py > flask.log 2>&1 &
echo "$(date): Flask application started in background"

echo "$(date): User data script execution completed successfully"