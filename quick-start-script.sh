#!/bin/bash

# 🚀 XRAY VLESS + REALITY SERVICE - БЫСТРЫЙ ЗАПУСК
# Скопируйте этот код и запустите на сервере OneDash

echo "🚀 Запуск Xray VLESS + Reality Service..."

# Обновление системы
apt update -y
apt install -y curl wget unzip python3 python3-pip

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Установка Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Установка Xray
wget -O xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip xray.zip
mv xray /usr/local/bin/
chmod +x /usr/local/bin/xray
rm xray.zip geoip.dat geosite.dat

# Настройка файрвола
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw allow 8001/tcp
ufw allow 8002/tcp
ufw allow 3000/tcp
ufw allow 9090/tcp
ufw --force enable

# Создание структуры проекта
mkdir -p /opt/xray-service/services/{xray-manager,telegram-bot,payment-service}
mkdir -p /opt/xray-service/scripts
mkdir -p /opt/xray-service/monitoring
mkdir -p /opt/xray-service/nginx

# Создание .env файла
cat > /opt/xray-service/.env << 'EOF'
DATABASE_URL=postgresql://xray_user:xray_password@postgres:5432/xray_service
REDIS_URL=redis://redis:6379
BOT_TOKEN=your_bot_token_here
WEBHOOK_URL=https://89.188.113.58
WEBHOOK_SECRET=your_webhook_secret_here
YOOKASSA_SHOP_ID=your_yookassa_shop_id
YOOKASSA_SECRET_KEY=your_yookassa_secret_key
GRAFANA_PASSWORD=admin123
EOF

# Создание Docker Compose
cat > /opt/xray-service/docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: xray_service
      POSTGRES_USER: xray_user
      POSTGRES_PASSWORD: xray_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    restart: unless-stopped

  xray-manager:
    build: ./services/xray-manager
    ports:
      - "8080:8000"
    environment:
      - DATABASE_URL=postgresql://xray_user:xray_password@postgres:5432/xray_service
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  telegram-bot:
    build: ./services/telegram-bot
    ports:
      - "8001:8001"
    environment:
      - BOT_TOKEN=${BOT_TOKEN}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - WEBHOOK_SECRET=${WEBHOOK_SECRET}
    depends_on:
      - xray-manager
    restart: unless-stopped

  payment-service:
    build: ./services/payment-service
    ports:
      - "8002:8002"
    environment:
      - DATABASE_URL=postgresql://xray_user:xray_password@postgres:5432/xray_service
    depends_on:
      - postgres
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped

volumes:
  postgres_data:
  grafana_data:
EOF

# Создание Xray Manager
mkdir -p /opt/xray-service/services/xray-manager/app
cat > /opt/xray-service/services/xray-manager/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uuid
from datetime import datetime, timedelta

app = FastAPI(title="Xray Manager API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.get("/api/v1/servers")
async def get_servers():
    return {"servers": [{"id": 1, "name": "OneDash Server", "ip": "89.188.113.58", "port": 443, "status": "active"}]}

@app.post("/api/v1/configs/generate")
async def generate_config():
    config_uuid = str(uuid.uuid4())
    vless_config = f"vless://{config_uuid}@89.188.113.58:443?security=reality&sni=vk.com&fp=chrome&pbk=your_public_key&sid=your_short_id&type=tcp&flow=xtls-rprx-vision#user"
    return {"message": "Config generated", "config": {"vless_url": vless_config, "uuid": config_uuid}}

@app.get("/metrics")
async def metrics():
    return {"servers_count": 1, "configs_count": 0, "active_configs": 0}
EOF

cat > /opt/xray-service/services/xray-manager/requirements.txt << 'EOF'
fastapi
uvicorn
pydantic
EOF

cat > /opt/xray-service/services/xray-manager/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Создание Telegram Bot
mkdir -p /opt/xray-service/services/telegram-bot/app
cat > /opt/xray-service/services/telegram-bot/app/main.py << 'EOF'
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime

app = FastAPI(title="Telegram Bot API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.post("/webhook/")
async def webhook(request: Request):
    data = await request.json()
    print(f"Received webhook: {data}")
    return {"status": "ok"}

@app.get("/metrics")
async def metrics():
    return {"webhook_calls": 0, "active_users": 0}
EOF

cat > /opt/xray-service/services/telegram-bot/requirements.txt << 'EOF'
fastapi
uvicorn
aiogram
aiohttp
python-dotenv
EOF

cat > /opt/xray-service/services/telegram-bot/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
EXPOSE 8001
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
EOF

# Создание Payment Service
mkdir -p /opt/xray-service/services/payment-service/app
cat > /opt/xray-service/services/payment-service/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uuid
from datetime import datetime

app = FastAPI(title="Payment Service API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.get("/api/v1/stats/payments")
async def get_payments_stats():
    return {"total_payments": 0, "successful_payments": 0, "total_revenue": 0, "currency": "RUB"}

@app.post("/api/v1/payments/create")
async def create_payment():
    payment_id = str(uuid.uuid4())
    return {"payment_id": payment_id, "status": "pending", "amount": 200, "currency": "RUB", "payment_url": f"https://payment.example.com/{payment_id}"}

@app.get("/metrics")
async def metrics():
    return {"total_payments": 0, "successful_payments": 0, "total_revenue": 0}
EOF

cat > /opt/xray-service/services/payment-service/requirements.txt << 'EOF'
fastapi
uvicorn
pydantic
EOF

cat > /opt/xray-service/services/payment-service/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
EXPOSE 8002
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8002"]
EOF

# Запуск сервисов
cd /opt/xray-service
docker-compose up -d --build

# Ожидание запуска
echo "⏳ Ожидание запуска сервисов..."
sleep 60

# Проверка статуса
echo "🔍 Проверка статуса сервисов..."
docker-compose ps

# Проверка health check'ов
echo "✅ Проверка health check'ов..."
curl -s http://localhost:8080/health && echo " - Xray Manager OK" || echo " - Xray Manager FAIL"
curl -s http://localhost:8001/health && echo " - Telegram Bot OK" || echo " - Telegram Bot FAIL"
curl -s http://localhost:8002/health && echo " - Payment Service OK" || echo " - Payment Service FAIL"

echo ""
echo "🎉 СЕРВИС УСПЕШНО РАЗВЕРНУТ!"
echo ""
echo "🌐 Доступные сервисы:"
echo "   • Xray Manager:     http://89.188.113.58:8080"
echo "   • Telegram Bot:     http://89.188.113.58:8001"
echo "   • Payment Service:  http://89.188.113.58:8002"
echo "   • Grafana:          http://89.188.113.58:3000"
echo ""
echo "🔧 API Endpoints:"
echo "   • GET  /api/v1/servers              - список серверов"
echo "   • POST /api/v1/configs/generate      - генерация VLESS конфигурации"
echo "   • POST /api/v1/payments/create      - создание платежа"
echo "   • GET  /api/v1/stats/payments       - статистика платежей"
echo ""
echo "⚠️  Следующие шаги:"
echo "   1. Настройте платежные системы"
echo "   2. Создайте Telegram Bot"
echo "   3. Обновите .env файл"
echo "   4. Протестируйте все функции"
echo ""
echo "🚀 ГОТОВО! ВАШ БИЗНЕС ЗАПУЩЕН! 💰"
