#!/bin/bash

# Скрипт развертывания на Linux сервере

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
    apt install -y git curl wget jq python3 python3-pip postgresql-client redis-tools
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

# Создание пользователя для сервиса
create_service_user() {
    log "Создание пользователя для сервиса..."
    
    if id "xray-service" >/dev/null 2>&1; then
        log "Пользователь xray-service уже существует"
    else
        useradd -r -s /bin/false xray-service
        log "Пользователь xray-service создан"
    fi
}

# Создание директорий
create_directories() {
    log "Создание директорий..."
    
    mkdir -p /opt/xray-service
    mkdir -p /var/log/xray
    mkdir -p /var/backups/xray
    mkdir -p /etc/xray
    
    # Установка прав
    chown -R xray-service:xray-service /var/log/xray
    chown -R xray-service:xray-service /var/backups/xray
    chown -R xray-service:xray-service /etc/xray
    
    log "Директории созданы"
}

# Клонирование проекта
clone_project() {
    log "Клонирование проекта..."
    
    if [[ -d "/opt/xray-service/.git" ]]; then
        log "Проект уже клонирован, обновляем..."
        cd /opt/xray-service
        git pull
    else
        # Здесь нужно указать URL вашего репозитория
        read -p "Введите URL репозитория (или нажмите Enter для создания локальной копии): " REPO_URL
        
        if [[ -n "$REPO_URL" ]]; then
            git clone "$REPO_URL" /opt/xray-service
        else
            # Создание структуры проекта локально
            mkdir -p /opt/xray-service
            cd /opt/xray-service
            
            # Создание базовой структуры
            mkdir -p services/{xray-manager,telegram-bot,payment-service}
            mkdir -p scripts docs monitoring nginx xray
            
            log "Базовая структура проекта создана"
        fi
    fi
    
    cd /opt/xray-service
    chown -R xray-service:xray-service /opt/xray-service
    
    log "Проект готов"
}

# Настройка переменных окружения
setup_environment() {
    log "Настройка переменных окружения..."
    
    if [[ ! -f "/opt/xray-service/.env" ]]; then
        # Создание .env файла
        cat > /opt/xray-service/.env << 'EOF'
# Database
DATABASE_URL=postgresql://xray_user:xray_password@postgres:5432/xray_service
DB_PASSWORD=xray_password

# Redis
REDIS_URL=redis://redis:6379

# Telegram Bot
BOT_TOKEN=your_bot_token_here
WEBHOOK_URL=https://your-domain.com
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
GRAFANA_PASSWORD=your_grafana_password
PROMETHEUS_RETENTION_TIME=15d

# Security
SECRET_KEY=your_secret_key_here
JWT_SECRET_KEY=your_jwt_secret_key
EOF
        
        warn "Файл .env создан с дефолтными значениями"
        info "Необходимо отредактировать файл: nano /opt/xray-service/.env"
        read -p "Нажмите Enter после редактирования .env файла..."
    else
        log "Файл .env уже существует"
    fi
}

# Генерация ключей
generate_keys() {
    log "Генерация Reality ключей..."
    
    cd /opt/xray-service
    
    # Создание скрипта генерации ключей
    cat > scripts/generate-reality-keys.py << 'EOF'
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
    
    chmod +x scripts/generate-reality-keys.py
    python3 scripts/generate-reality-keys.py
    
    log "Ключи сгенерированы"
}

# Инициализация базы данных
init_database() {
    log "Инициализация базы данных..."
    
    cd /opt/xray-service
    
    # Создание скрипта инициализации БД
    cat > scripts/init-database.py << 'EOF'
#!/usr/bin/env python3
import os
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

# Загрузка переменных окружения
from dotenv import load_dotenv
load_dotenv()

def init_database():
    try:
        # Подключение к PostgreSQL
        conn = psycopg2.connect(
            host="localhost",
            port="5432",
            user="postgres",
            password="postgres"
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        # Создание базы данных
        cursor.execute("CREATE DATABASE xray_service;")
        print("Database 'xray_service' created")
        
        # Создание пользователя
        cursor.execute("CREATE USER xray_user WITH PASSWORD 'xray_password';")
        print("User 'xray_user' created")
        
        # Предоставление прав
        cursor.execute("GRANT ALL PRIVILEGES ON DATABASE xray_service TO xray_user;")
        print("Privileges granted")
        
        cursor.close()
        conn.close()
        
        print("Database initialization completed successfully")
        
    except psycopg2.errors.DuplicateDatabase:
        print("Database 'xray_service' already exists")
    except psycopg2.errors.DuplicateObject:
        print("User 'xray_user' already exists")
    except Exception as e:
        print(f"Error initializing database: {e}")

if __name__ == "__main__":
    init_database()
EOF
    
    chmod +x scripts/init-database.py
    
    # Установка PostgreSQL
    apt install -y postgresql postgresql-contrib
    
    # Запуск PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Инициализация базы данных
    python3 scripts/init-database.py
    
    log "База данных инициализирована"
}

# Создание Docker Compose файла
create_docker_compose() {
    log "Создание Docker Compose файла..."
    
    cd /opt/xray-service
    
    cat > docker-compose.yml << 'EOF'
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

# Запуск сервисов
start_services() {
    log "Запуск сервисов..."
    
    cd /opt/xray-service
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
    log "🚀 Развертывание Xray VLESS + Reality сервиса..."
    
    # Проверка прав
    check_root
    
    # Подготовка системы
    update_system
    install_docker
    install_xray
    setup_firewall
    create_service_user
    create_directories
    
    # Настройка проекта
    clone_project
    setup_environment
    generate_keys
    init_database
    create_docker_compose
    
    # Запуск сервисов
    start_services
    check_status
    
    log "🎉 Сервис успешно развернут!"
    
    info "Следующие шаги:"
    info "1. Настройте платежные системы"
    info "2. Создайте Telegram Bot"
    info "3. Протестируйте все функции"
    info "4. Запустите рекламную кампанию"
    
    warn "Не забудьте отредактировать .env файл с вашими настройками!"
}

# Запуск скрипта
main "$@"
