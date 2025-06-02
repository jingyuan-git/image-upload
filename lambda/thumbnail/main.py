import json
import os
import boto3
from PIL import Image
import io

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    s3 = boto3.client('s3')
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    # Download image from S3
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        image_content = response['Body'].read()
        image = Image.open(io.BytesIO(image_content))
        
        # Create thumbnail
        image.thumbnail((128, 128))
        
        # Save thumbnail to bytes
        buffer = io.BytesIO()
        image.save(buffer, format=image.format)
        buffer.seek(0)
        
        # Upload thumbnail to S3
        thumbnail_key = f"thumbnails/{os.path.basename(key)}"
        s3.upload_fileobj(buffer, bucket, thumbnail_key)
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "status": "ok",
                "thumbnail_key": thumbnail_key
            })
        }
        
    except Exception as e:
        print(f"Error processing image: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e)
            })
        }