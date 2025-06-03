import boto3  # AWS S3 SDK
import mysql.connector  # MySQL database connector
from flask import Flask, request, render_template, jsonify  # Web framework
from werkzeug.utils import secure_filename  # Secure filename handling
import google.generativeai as genai  # Gemini API for image captioning
import base64  # Encoding image data for API processing
from io import BytesIO  # Handling in-memory file objects
import json
import time
from datetime import datetime

def log_with_timestamp(message):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {message}")

GOOGLE_API_KEY = "${google_api_key}"
genai.configure(api_key=GOOGLE_API_KEY)

model = genai.GenerativeModel(model_name="gemini-2.0-pro-exp-02-05")

def generate_image_caption(image_data):
    try:
        encoded_image = base64.b64encode(image_data).decode("utf-8")
        response = model.generate_content(
            [
                {"mime_type": "image/jpeg", "data": encoded_image},
                "Caption this image.",
            ]
        )
        return response.text if response.text else "No caption generated."
    except Exception as e:
        return f"Error: {str(e)}"

lambda_client = boto3.client('lambda', region_name='us-east-1')

def generate_image_caption_via_lambda(image_data, image_key):
    try:
        print("Preparing payload for Lambda function...")
        payload = {
            'body': json.dumps({
                'image_data': base64.b64encode(image_data).decode('utf-8'),
                'image_key': image_key
            })
        }
        
        print(f"Invoking Lambda function 'annotation-function' with image_key: {image_key}")
        response = lambda_client.invoke(
            FunctionName='annotation-function',
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        
        print("Lambda function invoked successfully. Parsing response...")
        # 解析响应
        response_payload = json.loads(response['Payload'].read())
        print(f"Lambda response payload: {response_payload}")
        
        if response_payload.get('statusCode') == 200:
            body = json.loads(response_payload['body'])
            caption = body.get('caption', 'No caption generated')
            print(f"Caption generated successfully: {caption}")
            return caption
        else:
            body = json.loads(response_payload['body'])
            error_message = body.get('error', 'Unknown error')
            print(f"Error from Lambda function: {error_message}")
            return f"Error: {error_message}"
    
    except Exception as e:
        print(f"Lambda invocation error: {str(e)}")
        return f"Lambda invocation error: {str(e)}"


# Flask app setup
app = Flask(__name__)

# AWS S3 Configuration, dynamically set by Terraform
S3_BUCKET = "${s3_bucket}"
S3_REGION = "${s3_region}"

def get_s3_client():
    """Returns a new S3 client that automatically refreshes credentials if using an IAM role."""
    return boto3.client("s3", region_name=S3_REGION)

# Database Configuration, dynamically set by Terraform
DB_HOST = "${db_host}"
DB_NAME = "${db_name}"
DB_USER = "${db_user}"
DB_PASSWORD = "${db_password}"

def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASSWORD
        )
        return connection
    except mysql.connector.Error as err:
        print("Error connecting to database:", err)
        return None

# Allowed file types for upload
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif"}

def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route("/")
def upload_form():
    return render_template("index.html")

@app.route("/upload", methods=["GET", "POST"])
def upload_image():
    if request.method == "POST":
        if "file" not in request.files:
            return render_template("upload.html", error="No file selected")

        file = request.files["file"]

        if file.filename == "":
            return render_template("upload.html", error="No file selected")

        if not allowed_file(file.filename):
            return render_template("upload.html", error="Invalid file type")

        filename = secure_filename(file.filename)
        file_data = file.read()  # Read file as binary

        # Upload file to S3
        try:
            s3 = get_s3_client()  # Get a fresh S3 client
            s3.upload_fileobj(BytesIO(file_data), S3_BUCKET, f"images/{filename}")
        except Exception as e:
            return render_template("upload.html", error=f"S3 Upload Error: {str(e)}")

        # Query the database for the caption using image_key,
        # assuming that the Lambda function (triggered by the S3 event) writes it into the DB.
        caption = "Caption processing pending..."
        connection = get_db_connection()
        if connection:
            try:
                print("Database connection established.")
                cursor = connection.cursor()

                # Debug: Print all rows in the captions table
                print("Fetching all rows from the captions table for debugging...")
                cursor.execute("SELECT image_key, caption FROM captions")
                all_rows = cursor.fetchall()
                print("Current rows in the database:")
                for row in all_rows:
                    print(f"image_key: {row[0]}, caption: {row[1]}")

                # Query for the specific image_key
                print(f"Querying caption for image_key: {filename}")
                query = "SELECT caption FROM captions WHERE image_key = %s"
                timeout = 15  # Maximum wait time in seconds
                start_time = time.time()

                while True:
                    connection1 = get_db_connection()
                    cursor = connection1.cursor()
                    query = f"SELECT caption FROM captions WHERE image_key = 'thumbnails/{filename}'"
                    log_with_timestamp(f"Executing query: {query}")
                    cursor.execute(query)
                    row = cursor.fetchone()
                    if row is not None:
                        caption = row[0]
                        log_with_timestamp(f"Caption found: {caption}")
                        connection1.close()
                        break  # Exit the loop if caption is found

                    # Check if timeout has been reached
                    if time.time() - start_time > timeout:
                        log_with_timestamp("Timeout reached while waiting for caption.")
                        caption = "Caption processing timed out. Please check back later."
                        break

                    log_with_timestamp("Caption not found yet. Retrying in 1 second...")
                    time.sleep(1)  # Wait for 1 second before retrying
                    connection1.close()
                connection.close()
                print("Database connection closed.")
            except Exception as e:
                caption = f"Error querying caption: {str(e)}"
                print("Error querying caption:", str(e))
        else:
            caption = "Database Error: Unable to connect to the database."
            print("Failed to establish database connection.")

        # Prepare image for frontend display using Base64 encoding
        encoded_image = base64.b64encode(file_data).decode("utf-8")
        file_url = f"https://{S3_BUCKET}.s3.{S3_REGION}.amazonaws.com/images/{filename}"

        print("file_url:", file_url, "caption:", caption)
        
        return render_template("upload.html", image_data=encoded_image, file_url=file_url, caption=caption)

    return render_template("upload.html")
 
def generate_thumbnail_via_lambda(image_key):
    try:
        print("Preparing payload for Thumbnail Generator Lambda function...")
        # 只需传递 S3 的 image_key
        payload = {
            'body': json.dumps({
                'image_key': image_key
            })
        }

        print(f"Invoking Lambda function 'thumbnail-generator' with image_key: {image_key}")
        response = lambda_client.invoke(
            FunctionName='thumbnail-generator',
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )

        print("Thumbnail Lambda function invoked successfully. Parsing response...")
        response_payload = json.loads(response['Payload'].read())
        print(f"Thumbnail Lambda response payload: {response_payload}")

        if response_payload.get('statusCode') == 200:
            body = json.loads(response_payload['body'])
            thumbnail_key = body.get('thumbnail_key', None)
            print(f"Thumbnail generated successfully: {thumbnail_key}")
            return thumbnail_key
        else:
            body = json.loads(response_payload['body'])
            error_message = body.get('error', 'Unknown error')
            print(f"Error from Thumbnail Lambda function: {error_message}")
            return f"Error: {error_message}"

    except Exception as e:
        print(f"Thumbnail Lambda invocation error: {str(e)}")
        return f"Thumbnail Lambda invocation error: {str(e)}"


@app.route("/gallery")
def gallery():
    try:
        connection = get_db_connection()
        if connection is None:
            return render_template("gallery.html", error="Database Error: Unable to connect to the database.")
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT image_key, caption FROM captions ORDER BY uploaded_at DESC")
        results = cursor.fetchall()
        connection.close()

        images_with_captions = [
            {
                "url": get_s3_client().generate_presigned_url(
                    "get_object",
                    Params={"Bucket": S3_BUCKET, "Key": f"{row['image_key']}"},
                    ExpiresIn=3600,  # URL expires in 1 hour
                ),
                "caption": row["caption"],
            }
            for row in results
        ]

        return render_template("gallery.html", images=images_with_captions)

    except Exception as e:
        return render_template("gallery.html", error=f"Database Error: {str(e)}")

if __name__ == "__main__":
#    app.run(debug=True, host="0.0.0.0", port=5000)
    app.run(debug=True, host="0.0.0.0", port=80)