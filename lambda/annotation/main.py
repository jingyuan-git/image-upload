import json
import base64
import pymysql
# import requests  # 移除 requests
import urllib.request
import urllib.parse
from datetime import datetime
import os

# 配置
GOOGLE_API_KEY = os.environ['GOOGLE_API_KEY']
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
DB_NAME = os.environ['DB_NAME']

def get_db_connection():
    """建立 MySQL RDS 数据库连接"""
    try:
        connection = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            cursorclass=pymysql.cursors.DictCursor,  # 返回字典格式的结果
            autocommit=True
        )
        return connection
    except pymysql.Error as e:
        print(f"Error connecting to database: {e}")
        return None

def generate_image_caption(image_data):
    """使用 Gemini REST API 生成图像标题"""
    try:
        # 准备请求数据
        encoded_image = base64.b64encode(image_data).decode("utf-8")
        
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GOOGLE_API_KEY}"
        
        payload = {
            "contents": [{
                "parts": [
                    {
                        "text": "Caption this image."
                    },
                    {
                        "inline_data": {
                            "mime_type": "image/jpeg",
                            "data": encoded_image
                        }
                    }
                ]
            }]
        }
        
        # 使用 urllib 替换 requests
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            url, 
            data=data,
            headers={
                "Content-Type": "application/json"
            }
        )
        
        # 设置超时时间为 10 秒
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                result = json.loads(response.read().decode('utf-8'))
                if 'candidates' in result and len(result['candidates']) > 0:
                    return result['candidates'][0]['content']['parts'][0]['text']
                else:
                    return "No caption generated."
            else:
                error_text = response.read().decode('utf-8')
                return f"API Error: {response.status} - {error_text}"
            
    except Exception as e:
        return f"Error: {str(e)}"
 
def save_caption_to_db(image_key, caption):
    """将图像标题保存到数据库"""
    connection = get_db_connection()
    if connection is None:
        return False, "Failed to connect to database"
    
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO captions (image_key, caption) VALUES (%s, %s)",
                (image_key, caption)
            )
        # 由于设置了 autocommit=True，不需要手动 commit
        connection.close()
        return True, "Caption saved successfully"
    except Exception as e:
        if connection:
            connection.close()
        return False, f"Database error: {str(e)}"

def get_captions_from_db():
    """从数据库获取所有标题（可选功能）"""
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
        if connection:
            connection.close()
        return None, f"Database error: {str(e)}"

def lambda_handler(event, context):
    """Lambda 主处理函数"""
    try:
        print(f"Received event: {json.dumps(event)}")
        
        # 处理 S3 事件（当图片上传到 S3 时触发）
        if 'Records' in event and event['Records']:
            for record in event['Records']:
                if 's3' in record:
                    bucket = record['s3']['bucket']['name']
                    key = record['s3']['object']['key']
                    
                    print(f"Processing S3 object: {key} from bucket: {bucket}")
                    
                    # 从 S3 下载图像
                    import boto3
                    s3_client = boto3.client('s3')
                    
                    try:
                        response = s3_client.get_object(Bucket=bucket, Key=key)
                        image_data = response['Body'].read()
                    except Exception as e:
                        print(f"Error downloading from S3: {e}")
                        continue
                    
                    # 生成标题
                    caption = generate_image_caption(image_data)
                    
                    # 保存到数据库
                    success, message = save_caption_to_db(key, caption)
                    
                    print(f"Caption for {key}: {caption}")
                    print(f"Database save result: {message}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'S3 events processed successfully'})
            }
        
        # 处理直接调用（API Gateway 或直接 invoke）
        else:
            # 尝试解析 body
            if 'body' in event:
                if isinstance(event['body'], str):
                    body = json.loads(event['body'])
                else:
                    body = event['body']
            else:
                body = event
            
            # 检查是否是查询请求
            if body.get('action') == 'get_captions':
                captions, message = get_captions_from_db()
                if captions is not None:
                    return {
                        'statusCode': 200,
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        },
                        'body': json.dumps({
                            'captions': captions,
                            'message': message
                        })
                    }
                else:
                    return {
                        'statusCode': 500,
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        },
                        'body': json.dumps({'error': message})
                    }
            
            # 处理图像标题生成请求
            image_data_base64 = body.get('image_data')
            image_key = body.get('image_key', f"image_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg")
            
            if not image_data_base64:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': 'No image data provided'
                    })
                }
            
            # 解码图像数据
            try:
                image_data = base64.b64decode(image_data_base64)
            except Exception as e:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': f'Invalid base64 image data: {str(e)}'
                    })
                }
            
            # 生成图像标题
            caption = generate_image_caption(image_data)
            
            # 保存到数据库
            success, message = save_caption_to_db(image_key, caption)
            
            if success:
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'image_key': image_key,
                        'caption': caption,
                        'message': message
                    })
                }
            else:
                return {
                    'statusCode': 500,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': message
                    })
                }
    
    except Exception as e:
        print(f"Lambda execution error: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f'Internal server error: {str(e)}'
            })
        }