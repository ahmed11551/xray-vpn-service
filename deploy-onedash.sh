#!/bin/bash

# Скрипт развертывания на сервере OneDash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
}

# Обновление системы
update_system() {
    log "Обновление системы..."
    apt update && apt upgrade -y
    apt install -y git curl wget jq python3 python3-pip postgresql-client redis-tools unzip
    log "Система обновлена"
}

# Установка Docker
install_docker() {
    log "Установка Docker..."
    
    if command -v docker >/dev/null 2>&1; then
        log "Docker уже установлен"
    else
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        log "Docker установлен"
    fi
    
    # Установка Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        log "Docker Compose уже установлен"
    else
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log "Docker Compose установлен"
    fi
}

# Установка Xray
install_xray() {
    log "Установка Xray..."
    
    if command -v xray >/dev/null 2>&1; then
        log "Xray уже установлен"
    else
        wget -O xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
        unzip xray.zip
        mv xray /usr/local/bin/
        chmod +x /usr/local/bin/xray
        rm xray.zip geoip.dat geosite.dat
        log "Xray установлен"
    fi
}

# Настройка файрвола
setup_firewall() {
    log "Настройка файрвола..."
    
    # Установка UFW если не установлен
    if ! command -v ufw >/dev/null 2>&1; then
        apt install -y ufw
    fi
    
    # Настройка правил
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    ufw allow 8080/tcp  # API
    ufw allow 8000/tcp  # Xray Manager
    ufw allow 8001/tcp  # Telegram Bot
    ufw allow 8002/tcp  # Payment Service
    ufw allow 3000/tcp  # Grafana
    ufw allow 9090/tcp  # Prometheus
    
    # Включение UFW
    ufw --force enable
    log "Файрвол настроен"
}

# Создание структуры проекта
create_project_structure() {
    log "Создание структуры проекта..."
    
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
    
    log "Структура проекта создана"
}

# Создание .env файла
create_env_file() {
    log "Создание .env файла..."
    
    cat > /opt/xray-service/.env << 'EOF'
# Database
DATABASE_URL=postgresql://xray_user:xray_password@postgres:5432/xray_service
DB_PASSWORD=xray_password

# Redis
REDIS_URL=redis://redis:6379

# Telegram Bot
BOT_TOKEN=your_bot_token_here
WEBHOOK_URL=https://89.188.113.58
WEBHOOK_SECRET=your_webhook_secret_here
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
SECRET_KEY=your_secret_key_here
JWT_SECRET_KEY=your_jwt_secret_key
EOF
    
    log ".env файл создан"
}

# Создание Docker Compose файла
create_docker_compose() {
    log "Создание Docker Compose файла..."
    
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
      - YOOKASSA_SHOP_ID=${YOOKASSA_SHOP_ID}
      - YOOKASSA_SECRET_KEY=${YOOKASSA_SECRET_KEY}
    depends_on:
      - postgres
    restart: unless-stopped

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
    
    log "Docker Compose файл создан"
}

# Создание базовых сервисов
create_services() {
    log "Создание базовых сервисов..."
    
    # Xray Manager
    mkdir -p /opt/xray-service/services/xray-manager/app
    cat > /opt/xray-service/services/xray-manager/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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
    return {"status": "ok"}

@app.get("/api/v1/servers")
async def get_servers():
    return {"servers": []}

@app.post("/api/v1/configs/generate")
async def generate_config():
    return {"config": "vless://test@89.188.113.58:443?security=reality&sni=vk.com&fp=chrome&pbk=test&sid=test&type=tcp&flow=xtls-rprx-vision#test"}
EOF

    cat > /opt/xray-service/services/xray-manager/requirements.txt << 'EOF'
fastapi
uvicorn
sqlalchemy
psycopg2-binary
redis
pydantic
EOF

    cat > /opt/xray-service/services/xray-manager/Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    # Telegram Bot
    mkdir -p /opt/xray-service/services/telegram-bot/app
    cat > /opt/xray-service/services/telegram-bot/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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
    return {"status": "ok"}

@app.post("/webhook/")
async def webhook():
    return {"status": "ok"}
EOF

    cat > /opt/xray-service/services/telegram-bot/requirements.txt << 'EOF'
fastapi
uvicorn
aiogram
aiohttp
python-dotenv
EOF

    cat > /opt/xray-service/services/telegram-bot/Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
EOF

    # Payment Service
    mkdir -p /opt/xray-service/services/payment-service/app
    cat > /opt/xray-service/services/payment-service/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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
    return {"status": "ok"}

@app.get("/api/v1/stats/payments")
async def get_payments_stats():
    return {"payments": []}

@app.post("/api/v1/payments/create")
async def create_payment():
    return {"payment_id": "test_payment_123"}
EOF

    cat > /opt/xray-service/services/payment-service/requirements.txt << 'EOF'
fastapi
uvicorn
sqlalchemy
psycopg2-binary
pydantic
EOF

    cat > /opt/xray-service/services/payment-service/Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8002"]
EOF

    log "Базовые сервисы созданы"
}

# Создание скрипта генерации ключей
create_key_generator() {
    log "Создание скрипта генерации ключей..."
    
    cat > /opt/xray-service/scripts/generate-reality-keys.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import os
import secrets

def generate_reality_keys():
    try:
        # Генерация приватного и публичного ключей
        result = subprocess.run(
            ["/usr/local/bin/xray", "x25519"],
            capture_output=True,
            text=True,
            check=True
        )
        
        output_lines = result.stdout.strip().split('\n')
        private_key = output_lines[0].split(': ')[1]
        public_key = output_lines[1].split(': ')[1]
        
        # Генерация Short ID
        short_id = secrets.token_hex(8)
        
        print(f"Generated Reality Private Key: {private_key}")
        print(f"Generated Reality Public Key: {public_key}")
        print(f"Generated Reality Short ID: {short_id}")
        
        # Обновление .env файла
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
    log "Скрипт генерации ключей создан"
}

# Запуск сервисов
start_services() {
    log "Запуск сервисов..."
    
    cd /opt/xray-service
    
    # Генерация ключей
    python3 scripts/generate-reality-keys.py
    
    # Запуск Docker Compose
    docker-compose up -d
    
    # Ожидание запуска
    sleep 30
    
    log "Сервисы запущены"
}

# Проверка статуса
check_status() {
    log "Проверка статуса сервисов..."
    
    cd /opt/xray-service
    docker-compose ps
    
    # Проверка health check'ов
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
            log "✅ $name - OK"
        else
            error "❌ $name - FAIL"
        fi
    done
}

# Основная функция
main() {
    log "🚀 Развертывание Xray VLESS + Reality сервиса на OneDash..."
    
    # Проверка прав
    check_root
    
    # Подготовка системы
    update_system
    install_docker
    install_xray
    setup_firewall
    
    # Создание проекта
    create_project_structure
    create_env_file
    create_docker_compose
    create_services
    create_key_generator
    
    # Запуск сервисов
    start_services
    check_status
    
    log "🎉 Сервис успешно развернут на OneDash!"
    
    info "Доступные сервисы:"
    info "• Xray Manager: http://89.188.113.58:8080"
    info "• Telegram Bot: http://89.188.113.58:8001"
    info "• Payment Service: http://89.188.113.58:8002"
    info "• Grafana: http://89.188.113.58:3000"
    info "• Prometheus: http://89.188.113.58:9090"
    
    info "Следующие шаги:"
    info "1. Настройте платежные системы"
    info "2. Создайте Telegram Bot"
    info "3. Протестируйте все функции"
    info "4. Запустите рекламную кампанию"
    
    warn "Не забудьте отредактировать .env файл с вашими настройками!"
}

# Запуск скрипта
main "$@"
