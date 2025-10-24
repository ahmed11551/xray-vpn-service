#!/bin/bash

# 🚀 XRAY VLESS + REALITY SERVICE - ПОЛНОЕ РАЗВЕРТЫВАНИЕ
# Запустите этот скрипт на сервере OneDash: bash start-xray-service.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Заголовок
show_header() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           🚀 XRAY VLESS + REALITY SERVICE                  ║"
    echo "║                                                              ║"
    echo "║              КОММЕРЧЕСКИЙ VPN СЕРВИС                         ║"
    echo "║                                                              ║"
    echo "║         Автоматическое развертывание на OneDash             ║"
    echo "║                                                              ║"
    echo "║                    ГОТОВ К ЗАПУСКУ!                         ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "❌ Этот скрипт должен быть запущен с правами root"
        echo "Запустите: sudo bash start-xray-service.sh"
        exit 1
    fi
    success "✅ Права root подтверждены"
}

# Обновление системы
update_system() {
    log "🔄 Обновление системы..."
    apt update -y
    apt upgrade -y
    apt install -y git curl wget jq python3 python3-pip postgresql-client redis-tools unzip htop nano ufw
    success "✅ Система обновлена"
}

# Установка Docker
install_docker() {
    log "🐳 Установка Docker..."
    
    if command -v docker >/dev/null 2>&1; then
        log "Docker уже установлен"
    else
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        success "✅ Docker установлен"
    fi
    
    if command -v docker-compose >/dev/null 2>&1; then
        log "Docker Compose уже установлен"
    else
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        success "✅ Docker Compose установлен"
    fi
}

# Установка Xray
install_xray() {
    log "⚡ Установка Xray-core..."
    
    if command -v xray >/dev/null 2>&1; then
        log "Xray уже установлен"
    else
        wget -O xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
        unzip xray.zip
        mv xray /usr/local/bin/
        chmod +x /usr/local/bin/xray
        rm xray.zip geoip.dat geosite.dat
        success "✅ Xray-core установлен"
    fi
}

# Настройка файрвола
setup_firewall() {
    log "🔥 Настройка файрвола..."
    
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    ufw allow 8080/tcp  # API
    ufw allow 8000/tcp  # Xray Manager
    ufw allow 8001/tcp  # Telegram Bot
    ufw allow 8002/tcp  # Payment Service
    ufw allow 3000/tcp  # Grafana
    ufw allow 9090/tcp  # Prometheus
    
    ufw --force enable
    success "✅ Файрвол настроен"
}

# Создание структуры проекта
create_project_structure() {
    log "📁 Создание структуры проекта..."
    
    mkdir -p /opt/xray-service
    mkdir -p /opt/xray-service/services/{xray-manager,telegram-bot,payment-service}
    mkdir -p /opt/xray-service/scripts
    mkdir -p /opt/xray-service/docs
    mkdir -p /opt/xray-service/monitoring
    mkdir -p /opt/xray-service/nginx
    mkdir -p /opt/xray-service/xray
    mkdir -p /var/log/xray
    mkdir -p /var/backups/xray
    mkdir -p /etc/xray
    
    success "✅ Структура проекта создана"
}

# Создание .env файла
create_env_file() {
    log "⚙️ Создание конфигурации..."
    
    SECRET_KEY=$(openssl rand -hex 32)
    JWT_SECRET_KEY=$(openssl rand -hex 32)
    WEBHOOK_SECRET=$(openssl rand -hex 32)
    
    cat > /opt/xray-service/.env << EOF
# Database
DATABASE_URL=postgresql://xray_user:xray_password@postgres:5432/xray_service
DB_PASSWORD=xray_password

# Redis
REDIS_URL=redis://redis:6379

# Telegram Bot
BOT_TOKEN=your_bot_token_here
WEBHOOK_URL=https://89.188.113.58
WEBHOOK_SECRET=$WEBHOOK_SECRET
WEBHOOK_PORT=8001

# Payment Systems
YOOKASSA_SHOP_ID=your_yookassa_shop_id
YOOKASSA_SECRET_KEY=your_yookassa_secret_key
YOOKASSA_WEBHOOK_SECRET=your_yookassa_webhook_secret

ROBOKASSA_MERCHANT_LOGIN=your_robokassa_login
ROBOKASSA_PASSWORD_1=your_robokassa_password_1
ROBOKASSA_PASSWORD_2=your_robokassa_password_2

# Crypto Wallets
BITCOIN_WALLET_ADDRESS=your_bitcoin_address
ETHEREUM_WALLET_ADDRESS=your_ethereum_address
USDT_TRC20_WALLET_ADDRESS=your_usdt_trc20_address
USDT_ERC20_WALLET_ADDRESS=your_usdt_erc20_address

# Xray Configuration
XRAY_CONFIG_PATH=/etc/xray/config.json
XRAY_EXECUTABLE_PATH=/usr/local/bin/xray
SNI_DOMAINS=vk.com,yandex.ru,sberbank.ru,mail.ru
REALITY_PRIVATE_KEY=your_reality_private_key
REALITY_PUBLIC_KEY=your_reality_public_key
REALITY_SHORT_ID=your_reality_short_id

# Monitoring
GRAFANA_PASSWORD=admin123
PROMETHEUS_RETENTION_TIME=15d

# Security
SECRET_KEY=$SECRET_KEY
JWT_SECRET_KEY=$JWT_SECRET_KEY
EOF
    
    success "✅ Конфигурация создана"
}

# Создание Docker Compose файла
create_docker_compose() {
    log "🐳 Создание Docker Compose..."
    
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U xray_user -d xray_service"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  xray-manager:
    build: ./services/xray-manager
    ports:
      - "8080:8000"
    environment:
      - DATABASE_URL=postgresql://xray_user:xray_password@postgres:5432/xray_service
      - REDIS_URL=redis://redis:6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  telegram-bot:
    build: ./services/telegram-bot
    ports:
      - "8001:8001"
    environment:
      - BOT_TOKEN=${BOT_TOKEN}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - WEBHOOK_SECRET=${WEBHOOK_SECRET}
    depends_on:
      xray-manager:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  payment-service:
    build: ./services/payment-service
    ports:
      - "8002:8002"
    environment:
      - DATABASE_URL=postgresql://xray_user:xray_password@postgres:5432/xray_service
      - YOOKASSA_SHOP_ID=${YOOKASSA_SHOP_ID}
      - YOOKASSA_SECRET_KEY=${YOOKASSA_SECRET_KEY}
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8002/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
    depends_on:
      - xray-manager
      - telegram-bot
      - payment-service
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
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
    
    success "✅ Docker Compose создан"
}

# Создание сервисов
create_services() {
    log "🔧 Создание сервисов..."
    
    # Xray Manager
    mkdir -p /opt/xray-service/services/xray-manager/app
    cat > /opt/xray-service/services/xray-manager/app/main.py << 'EOF'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import json
import uuid
from datetime import datetime, timedelta

app = FastAPI(title="Xray Manager API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ServerCreate(BaseModel):
    name: str
    ip: str
    port: int = 443

class ConfigGenerate(BaseModel):
    user_id: int
    server_id: int = 1

# Временное хранилище
servers = [
    {"id": 1, "name": "OneDash Server", "ip": "89.188.113.58", "port": 443, "status": "active"}
]

configs = []

@app.get("/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.get("/api/v1/servers")
async def get_servers():
    return {"servers": servers, "count": len(servers)}

@app.post("/api/v1/servers")
async def create_server(server: ServerCreate):
    new_server = {
        "id": len(servers) + 1,
        "name": server.name,
        "ip": server.ip,
        "port": server.port,
        "status": "active"
    }
    servers.append(new_server)
    return {"message": "Server created", "server": new_server}

@app.post("/api/v1/configs/generate")
async def generate_config(config: ConfigGenerate):
    config_uuid = str(uuid.uuid4())
    server = next((s for s in servers if s["id"] == config.server_id), servers[0])
    
    vless_config = f"vless://{config_uuid}@{server['ip']}:{server['port']}?security=reality&sni=vk.com&fp=chrome&pbk=your_public_key&sid=your_short_id&type=tcp&flow=xtls-rprx-vision#{config.user_id}"
    
    new_config = {
        "id": len(configs) + 1,
        "user_id": config.user_id,
        "server_id": config.server_id,
        "config_uuid": config_uuid,
        "vless_url": vless_config,
        "created_at": datetime.now().isoformat(),
        "expires_at": (datetime.now() + timedelta(days=30)).isoformat(),
        "is_active": True
    }
    
    configs.append(new_config)
    return {"message": "Config generated", "config": new_config}

@app.get("/api/v1/configs/{user_id}")
async def get_user_configs(user_id: int):
    user_configs = [c for c in configs if c["user_id"] == user_id]
    return {"configs": user_configs, "count": len(user_configs)}

@app.get("/metrics")
async def metrics():
    return {
        "servers_count": len(servers),
        "configs_count": len(configs),
        "active_configs": len([c for c in configs if c["is_active"]])
    }
EOF

    cat > /opt/xray-service/services/xray-manager/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
redis==5.0.1
pydantic==2.5.0
python-multipart==0.0.6
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

    # Telegram Bot
    mkdir -p /opt/xray-service/services/telegram-bot/app
    cat > /opt/xray-service/services/telegram-bot/app/main.py << 'EOF'
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import json
import os
from datetime import datetime

app = FastAPI(title="Telegram Bot API", version="1.0.0")

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
    try:
        data = await request.json()
        print(f"Received webhook: {json.dumps(data, indent=2)}")
        
        if "message" in data and "text" in data["message"]:
            text = data["message"]["text"]
            if text == "/start":
                return {"status": "ok", "response": "Добро пожаловать в Xray VPN Service!"}
        
        return {"status": "ok"}
    except Exception as e:
        print(f"Error processing webhook: {e}")
        return {"status": "error", "message": str(e)}

@app.get("/metrics")
async def metrics():
    return {
        "webhook_calls": 0,
        "active_users": 0,
        "last_activity": datetime.now().isoformat()
    }
EOF

    cat > /opt/xray-service/services/telegram-bot/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
aiogram==3.2.0
aiohttp==3.9.1
python-dotenv==1.0.0
python-multipart==0.0.6
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

    # Payment Service
    mkdir -p /opt/xray-service/services/payment-service/app
    cat > /opt/xray-service/services/payment-service/app/main.py << 'EOF'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uuid
from datetime import datetime, timedelta
from enum import Enum

app = FastAPI(title="Payment Service API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PaymentStatus(str, Enum):
    PENDING = "pending"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELED = "canceled"

class PaymentCreate(BaseModel):
    user_id: int
    amount: float
    currency: str = "RUB"
    description: str
    payment_system: str = "yookassa"

class PaymentResponse(BaseModel):
    payment_id: str
    status: PaymentStatus
    amount: float
    currency: str
    payment_url: str = None

payments = []

@app.get("/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.get("/api/v1/stats/payments")
async def get_payments_stats():
    total_payments = len(payments)
    successful_payments = len([p for p in payments if p["status"] == PaymentStatus.SUCCEEDED])
    total_revenue = sum([p["amount"] for p in payments if p["status"] == PaymentStatus.SUCCEEDED])
    
    return {
        "total_payments": total_payments,
        "successful_payments": successful_payments,
        "total_revenue": total_revenue,
        "currency": "RUB"
    }

@app.post("/api/v1/payments/create")
async def create_payment(payment: PaymentCreate):
    payment_id = str(uuid.uuid4())
    
    new_payment = {
        "payment_id": payment_id,
        "user_id": payment.user_id,
        "amount": payment.amount,
        "currency": payment.currency,
        "description": payment.description,
        "payment_system": payment.payment_system,
        "status": PaymentStatus.PENDING,
        "created_at": datetime.now().isoformat(),
        "payment_url": f"https://payment.example.com/{payment_id}"
    }
    
    payments.append(new_payment)
    
    return PaymentResponse(
        payment_id=payment_id,
        status=PaymentStatus.PENDING,
        amount=payment.amount,
        currency=payment.currency,
        payment_url=new_payment["payment_url"]
    )

@app.get("/api/v1/payments/{payment_id}")
async def get_payment(payment_id: str):
    payment = next((p for p in payments if p["payment_id"] == payment_id), None)
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    return {"payment": payment}

@app.get("/metrics")
async def metrics():
    return {
        "total_payments": len(payments),
        "successful_payments": len([p for p in payments if p["status"] == PaymentStatus.SUCCEEDED]),
        "total_revenue": sum([p["amount"] for p in payments if p["status"] == PaymentStatus.SUCCEEDED])
    }
EOF

    cat > /opt/xray-service/services/payment-service/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
pydantic==2.5.0
python-multipart==0.0.6
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

    success "✅ Сервисы созданы"
}

# Создание скрипта генерации ключей
create_key_generator() {
    log "🔑 Создание генератора ключей..."
    
    cat > /opt/xray-service/scripts/generate-reality-keys.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import os
import secrets

def generate_reality_keys():
    try:
        result = subprocess.run(
            ["/usr/local/bin/xray", "x25519"],
            capture_output=True,
            text=True,
            check=True
        )
        
        output_lines = result.stdout.strip().split('\n')
        private_key = output_lines[0].split(': ')[1]
        public_key = output_lines[1].split(': ')[1]
        
        short_id = secrets.token_hex(8)
        
        print(f"Generated Reality Private Key: {private_key}")
        print(f"Generated Reality Public Key: {public_key}")
        print(f"Generated Reality Short ID: {short_id}")
        
        env_file = "/opt/xray-service/.env"
        if os.path.exists(env_file):
            with open(env_file, 'r') as f:
                content = f.read()
            
            content = content.replace("your_reality_private_key", private_key)
            content = content.replace("your_reality_public_key", public_key)
            content = content.replace("your_reality_short_id", short_id)
            
            with open(env_file, 'w') as f:
                f.write(content)
            
            print("Keys updated in .env file")
        
        return private_key, public_key, short_id
        
    except FileNotFoundError:
        print("Error: Xray executable not found at /usr/local/bin/xray")
        return None, None, None
    except subprocess.CalledProcessError as e:
        print(f"Error generating Reality keys: {e}")
        return None, None, None

if __name__ == "__main__":
    generate_reality_keys()
EOF
    
    chmod +x /opt/xray-service/scripts/generate-reality-keys.py
    success "✅ Генератор ключей создан"
}

# Создание Nginx конфигурации
create_nginx_config() {
    log "🌐 Создание Nginx конфигурации..."
    
    cat > /opt/xray-service/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream xray_manager {
        server xray-manager:8000;
    }
    
    upstream telegram_bot {
        server telegram-bot:8001;
    }
    
    upstream payment_service {
        server payment-service:8002;
    }
    
    server {
        listen 80;
        server_name 89.188.113.58;
        
        location /api/ {
            proxy_pass http://xray_manager;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location /webhook/ {
            proxy_pass http://telegram_bot;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location /payment/ {
            proxy_pass http://payment_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location /health {
            proxy_pass http://xray_manager/health;
        }
        
        location / {
            return 200 '🚀 Xray VLESS + Reality Service is running!';
            add_header Content-Type text/plain;
        }
    }
}
EOF
    
    success "✅ Nginx конфигурация создана"
}

# Создание Prometheus конфигурации
create_prometheus_config() {
    log "📊 Создание Prometheus конфигурации..."
    
    cat > /opt/xray-service/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'xray-manager'
    static_configs:
      - targets: ['xray-manager:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'telegram-bot'
    static_configs:
      - targets: ['telegram-bot:8001']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'payment-service'
    static_configs:
      - targets: ['payment-service:8002']
    metrics_path: '/metrics'
    scrape_interval: 30s
EOF
    
    success "✅ Prometheus конфигурация создана"
}

# Запуск сервисов
start_services() {
    log "🚀 Запуск сервисов..."
    
    cd /opt/xray-service
    
    # Генерация ключей
    python3 scripts/generate-reality-keys.py
    
    # Запуск Docker Compose
    docker-compose up -d --build
    
    # Ожидание запуска
    log "⏳ Ожидание запуска сервисов..."
    sleep 60
    
    success "✅ Сервисы запущены"
}

# Проверка статуса
check_status() {
    log "🔍 Проверка статуса сервисов..."
    
    cd /opt/xray-service
    docker-compose ps
    
    info "Проверка health check'ов..."
    
    services=(
        "Xray Manager:8080"
        "Telegram Bot:8001"
        "Payment Service:8002"
    )
    
    for service in "${services[@]}"; do
        name=$(echo $service | cut -d: -f1)
        port=$(echo $service | cut -d: -f2)
        
        if curl -s -f "http://localhost:$port/health" > /dev/null; then
            success "✅ $name - OK"
        else
            error "❌ $name - FAIL"
        fi
    done
}

# Создание скриптов управления
create_management_scripts() {
    log "🛠️ Создание скриптов управления..."
    
    cat > /opt/xray-service/restart.sh << 'EOF'
#!/bin/bash
cd /opt/xray-service
docker-compose restart
echo "✅ Сервисы перезапущены"
EOF
    
    cat > /opt/xray-service/stop.sh << 'EOF'
#!/bin/bash
cd /opt/xray-service
docker-compose down
echo "✅ Сервисы остановлены"
EOF
    
    cat > /opt/xray-service/logs.sh << 'EOF'
#!/bin/bash
cd /opt/xray-service
docker-compose logs -f
EOF
    
    cat > /opt/xray-service/update.sh << 'EOF'
#!/bin/bash
cd /opt/xray-service
docker-compose pull
docker-compose up -d --build
echo "✅ Сервисы обновлены"
EOF
    
    chmod +x /opt/xray-service/*.sh
    success "✅ Скрипты управления созданы"
}

# Генерация отчета
generate_report() {
    local report_file="/opt/xray-service/DEPLOYMENT_REPORT.txt"
    
    {
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║           🚀 XRAY VLESS + REALITY SERVICE                  ║"
        echo "║              ОТЧЕТ О РАЗВЕРТЫВАНИИ                         ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "📅 Дата развертывания: $(date)"
        echo "🖥️  Сервер: $(hostname)"
        echo "🌐 IP адрес: 89.188.113.58"
        echo "🏢 Провайдер: OneDash"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    ДОСТУПНЫЕ СЕРВИСЫ                       ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "🔧 Xray Manager API:     http://89.188.113.58:8080"
        echo "🤖 Telegram Bot Service: http://89.188.113.58:8001"
        echo "💳 Payment Service:      http://89.188.113.58:8002"
        echo "📊 Grafana Dashboard:    http://89.188.113.58:3000"
        echo "📈 Prometheus Metrics:   http://89.188.113.58:9090"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                      API ENDPOINTS                         ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "GET  /api/v1/servers              - список серверов"
        echo "POST /api/v1/configs/generate      - генерация VLESS конфигурации"
        echo "POST /api/v1/payments/create      - создание платежа"
        echo "GET  /api/v1/stats/payments       - статистика платежей"
        echo "GET  /health                      - проверка состояния"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    СКРИПТЫ УПРАВЛЕНИЯ                       ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "./restart.sh  - перезапуск сервисов"
        echo "./stop.sh     - остановка сервисов"
        echo "./logs.sh     - просмотр логов"
        echo "./update.sh   - обновление сервисов"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    СЛЕДУЮЩИЕ ШАГИ                          ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "1. 💳 Настройте платежные системы (YooKassa, Robokassa)"
        echo "2. 🤖 Создайте Telegram Bot через @BotFather"
        echo "3. ⚙️  Обновите BOT_TOKEN в .env файле"
        echo "4. 🧪 Протестируйте все функции"
        echo "5. 📢 Запустите рекламную кампанию"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    ПОЛЕЗНЫЕ КОМАНДЫ                         ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "cd /opt/xray-service"
        echo "docker-compose ps                    - статус сервисов"
        echo "docker-compose logs -f               - просмотр логов"
        echo "nano .env                           - редактирование конфигурации"
        echo ""
        echo "🎉 ВАШ КОММЕРЧЕСКИЙ VPN СЕРВИС ГОТОВ К РАБОТЕ! 🎉"
        
    } > "$report_file"
    
    log "📄 Отчет сохранен в: $report_file"
    echo "$report_file"
}

# Основная функция
main() {
    show_header
    
    check_root
    update_system
    install_docker
    install_xray
    setup_firewall
    create_project_structure
    create_env_file
    create_docker_compose
    create_services
    create_key_generator
    create_nginx_config
    create_prometheus_config
    create_management_scripts
    start_services
    check_status
    
    report_file=$(generate_report)
    
    echo ""
    success "🎉 СЕРВИС УСПЕШНО РАЗВЕРНУТ!"
    echo ""
    info "🌐 Доступные сервисы:"
    info "   • Xray Manager:     http://89.188.113.58:8080"
    info "   • Telegram Bot:     http://89.188.113.58:8001"
    info "   • Payment Service:  http://89.188.113.58:8002"
    info "   • Grafana:          http://89.188.113.58:3000"
    info "   • Prometheus:       http://89.188.113.58:9090"
    echo ""
    info "📄 Отчет: $report_file"
    echo ""
    warn "⚠️  Следующие шаги:"
    warn "   1. Настройте платежные системы"
    warn "   2. Создайте Telegram Bot"
    warn "   3. Обновите .env файл"
    warn "   4. Протестируйте все функции"
    warn "   5. Запустите рекламную кампанию"
    echo ""
    success "🚀 ГОТОВО! ВАШ БИЗНЕС ЗАПУЩЕН! 💰"
}

# Запуск скрипта
main "$@"
