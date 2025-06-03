import json
import base64
import os
import time
import pymysql
import boto3
import urllib.request
from datetime import datetime

# 配置
GOOGLE_API_KEY = os.environ['GOOGLE_API_KEY']
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
DB_NAME = os.environ['DB_NAME']

# 统一响应
def build_response(data, status_code=200):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(data)
    }

# 数据库连接
def get_db_connection():
    try:
        connection = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            cursorclass=pymysql.cursors.DictCursor,
            autocommit=True
        )
        return connection
    except pymysql.Error as e:
        print(f"Error connecting to database: {e}")
        return None

# 保存 Caption
def save_caption_to_db(image_key, caption):
    connection = get_db_connection()
    if connection is None:
        return False, "Failed to connect to database"

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO captions (image_key, caption) VALUES (%s, %s)",
                (image_key, caption)
            )
        connection.close()
        return True, "Caption saved successfully"
    except Exception as e:
        connection.close()
        return False, f"Database error: {str(e)}"

def generate_image_caption(image_data):
    try:
        start_time = time.time()
        print("Encoding image data...")
        encoded_image = base64.b64encode(image_data).decode("utf-8")
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GOOGLE_API_KEY}"

        payload = {
            "contents": [{
                "parts": [
                    {"text": "Caption this image."},
                    {
                        "inline_data": {
                            "mime_type": "image/jpeg",
                            "data": encoded_image
                        }
                    }
                ]
            }]
        }

        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            url,
            data=data,
            headers={"Content-Type": "application/json"}
        )

        print("Sending request to Google Gemini API...")
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                result = json.loads(response.read().decode('utf-8'))
                print(f"API call completed in {time.time() - start_time:.2f} seconds.")
                if 'candidates' in result and result['candidates']:
                    return result['candidates'][0]['content']['parts'][0]['text']
                else:
                    return "No caption generated."
            else:
                error_text = response.read().decode('utf-8')
                print(f"API Error: {response.status} - {error_text}")
                return f"API Error: {response.status} - {error_text}"
    except Exception as e:
        print(f"Error in generate_image_caption: {str(e)}")
        return f"Error: {str(e)}"

# 处理 S3 事件记录
def process_s3_record(record):
    try:
        print("Processing S3 record...")
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        print(f"Bucket: {bucket}, Key: {key}")

        s3_client = boto3.client('s3')
        print("Fetching object from S3...")
        response = s3_client.get_object(Bucket=bucket, Key=key)
        image_data = response['Body'].read()
        print("Object fetched successfully.")

        print("Generating caption...")
        caption = generate_image_caption(image_data)
        print(f"Caption generated: {caption}")

        print("Saving caption to database...")
        success, message = save_caption_to_db(key, caption)
        print(f"Database save result: {message}")

        return {'image_key': key, 'caption': caption, 'success': success, 'message': message}
    except Exception as e:
        print(f"Error processing S3 record: {e}")
        print(f"Record contents: {json.dumps(record)}")
        return {'success': False, 'message': str(e)}

# 处理 API 请求
def handle_api_request(body):
    if body.get('action') == 'get_captions':
        captions, message = get_captions_from_db()
        if captions is not None:
            return build_response({'captions': captions, 'message': message})
        else:
            return build_response({'error': message}, 500)

    image_data_base64 = body.get('image_data')
    image_key = body.get('image_key', f"image_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg")

    if not image_data_base64:
        return build_response({'error': 'No image data provided'}, 400)

    try:
        image_data = base64.b64decode(image_data_base64)
    except Exception as e:
        return build_response({'error': f'Invalid base64 image data: {str(e)}'}, 400)

    caption = generate_image_caption(image_data)
    success, message = save_caption_to_db(image_key, caption)

    if success:
        return build_response({'image_key': image_key, 'caption': caption, 'message': message})
    else:
        return build_response({'error': message}, 500)

# 从数据库获取所有 captions
def get_captions_from_db():
    connection = get_db_connection()
    if connection is None:
        return None, "Failed to connect to database"

    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT * FROM captions ORDER BY uploaded_at DESC")
            result = cursor.fetchall()
        connection.close()
        return result, "Success"
    except Exception as e:
        connection.close()
        return None, f"Database error: {str(e)}"

# Lambda 主处理函数
def lambda_handler(event, context):
    try:
        print(f"Received event: {json.dumps(event)}")

        if 'Records' in event and event['Records']:
            results = [process_s3_record(record) for record in event['Records']]
            return build_response({'results': results})

        else:
            body = event.get('body')
            if body:
                if isinstance(body, str):
                    body = json.loads(body)
            else:
                body = event
            return handle_api_request(body)

    except Exception as e:
        print(f"Lambda execution error: {e}")
        return build_response({'error': f'Internal server error: {str(e)}'}, 500)