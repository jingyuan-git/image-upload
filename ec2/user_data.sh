#!/bin/bash
sudo yum update -y
sudo yum install python3-pip -y
sudo pip3 install flask mysql-connector-python google-generativeai boto3 werkzeug
sudo yum install -y mariadb105

# 写入你的 Flask 应用代码到 /home/ec2-user/app.py
cat > /home/ec2-user/app.py << 'EOPY'
${app_code}
EOPY

# 设置环境变量
export GOOGLE_API_KEY="${google_api_key}"
export S3_BUCKET="${s3_bucket}"
export DB_HOST="${db_host}"
export DB_USER="${db_user}"
export DB_PASSWORD="${db_password}"

# 初始化RDS数据库和表
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
echo "Creating database and table..."
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "$SQL_COMMANDS"
if [ $? -eq 0 ]; then
    echo "Database and table created successfully!"
else
    echo "Error: Failed to create database and table. Please check the connection details and try again."
    exit 1
fi

# 启动 Flask 应用（后台运行）
cd /home/ec2-user
nohup python3 app.py > flask.log 2>&1 &