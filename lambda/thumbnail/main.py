import os
import boto3
from PIL import Image

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    download_path = f'/tmp/{os.path.basename(key)}'
    thumbnail_path = f'/tmp/thumbnail-{os.path.basename(key)}'
    s3.download_file(bucket, key, download_path)
    # 生成缩略图
    with Image.open(download_path) as img:
        img.thumbnail((128, 128))
        img.save(thumbnail_path)
    # 上传到 thumbnails/ 目录
    thumbnail_key = f"thumbnails/{os.path.basename(key)}"
    s3.upload_file(thumbnail_path, bucket, thumbnail_key)
    return {"status": "ok", "thumbnail_key": thumbnail_key}