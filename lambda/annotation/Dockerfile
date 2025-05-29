FROM python:3.12-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 复制并安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -t /app

# 复制 Lambda 代码
COPY main.py /app/

# 设置输出命令
CMD ["sh", "-c", "cp -r /app/* /out/"]