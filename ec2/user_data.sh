#!/bin/bash

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

sudo yum update -y
sudo yum install python3-pip -y
sudo pip3 install flask mysql-connector-python google-generativeai boto3 werkzeug

sudo yum install -y mariadb105
echo "$(date): installation completed"

echo "$(date): Writing Flask application code..."
cat > /home/ec2-user/app.py << 'EOPY'
${app_code}
EOPY
echo "$(date): Flask application code written successfully"

mkdir -p /home/ec2-user/templates

${templates_dir}

export GOOGLE_API_KEY="${google_api_key}"
export S3_BUCKET="${s3_bucket}"
export DB_HOST="${db_host}"
export DB_USER="${db_user}"
export DB_PASSWORD="${db_password}"
echo "$(date): Starting database initialization..."

# Check if the database exists
DB_EXISTS=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "SHOW DATABASES LIKE 'image_caption_db';" | grep "image_caption_db")

if [ -n "$DB_EXISTS" ]; then
    echo "$(date): Database 'image_caption_db' already exists. Skipping creation."
else
    echo "$(date): Database 'image_caption_db' does not exist. Creating database and table..."
    SQL_COMMANDS=$(cat <<EOSQL
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

    mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "$SQL_COMMANDS"
    if [ $? -eq 0 ]; then
        echo "$(date): Database and table created successfully!"
    else
        echo "$(date): Error: Failed to create database and table. Please check the connection details and try again."
        exit 1
    fi
fi

echo "$(date): Starting Flask application..."
cd /home/ec2-user
nohup python3 app.py > flask.log 2>&1 &
echo "$(date): Flask application started in background"

echo "$(date): User data script execution completed successfully"