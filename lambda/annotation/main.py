import json
import base64
import mysql.connector
import requests
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
        connection = mysql.connector.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            autocommit=True
        )
        return connection
    except mysql.connector.Error as err:
        print(f"Error connecting to database: {err}")
        return None

def generate_image_caption(image_data):
    """使用 Gemini REST API 生成图像标题"""
    try:
        # 准备请求数据
        encoded_image = base64.b64encode(image_data).decode("utf-8")
        
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-pro-exp-02-05:generateContent?key={GOOGLE_API_KEY}"
        
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
        
        headers = {
            "Content-Type": "application/json"
        }
        
        response = requests.post(url, json=payload, headers=headers)
        
        if response.status_code == 200:
            result = response.json()
            if 'candidates' in result and len(result['candidates']) > 0:
                return result['candidates'][0]['content']['parts'][0]['text']
            else:
                return "No caption generated."
        else:
            return f"API Error: {response.status_code} - {response.text}"
            
    except Exception as e:
        return f"Error: {str(e)}"

def save_caption_to_db(image_key, caption):
    """将图像标题保存到数据库"""
    connection = get_db_connection()
    if connection is None:
        return False, "Failed to connect to database"
    
    try:
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO captions (image_key, caption) VALUES (%s, %s)",
            (image_key, caption)
        )
        connection.commit()
        cursor.close()
        connection.close()
        return True, "Caption saved successfully"
    except Exception as e:
        if connection:
            connection.close()
        return False, f"Database error: {str(e)}"

def lambda_handler(event, context):
    """Lambda 主处理函数"""
    try:
        # 解析事件数据
        body = json.loads(event.get('body', '{}'))
        
        # 获取图像数据和文件名
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