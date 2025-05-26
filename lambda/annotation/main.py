import os
import boto3
import requests

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    # 解析S3事件
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    # 下载图片到/tmp
    download_path = f'/tmp/{os.path.basename(key)}'
    s3.download_file(bucket, key, download_path)
    # 调用Gemini API（伪代码）
    with open(download_path, 'rb') as f:
        image_data = f.read()
    response = requests.post(
        "https://gemini-api.example.com/annotate",
        files={"image": image_data}
    )
    description = response.json().get("description", "")
    # 写入RDS（伪代码，需配置RDS连接）
    # import psycopg2
    # conn = psycopg2.connect(...)
    # cur = conn.cursor()
    # cur.execute("INSERT INTO images (key, description) VALUES (%s, %s)", (key, description))
    # conn.commit()
    return {"status": "ok", "description": description}