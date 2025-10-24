#!/bin/bash

# Скрипт быстрого запуска Xray VLESS + Reality сервиса

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
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

# Установка дополнительных пакетов
install_packages() {
    log "Установка дополнительных пакетов..."
    apt install -y git curl wget jq python3 python3-pip postgresql-client redis-tools
    log "Пакеты установлены"
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
        read -p "Введите URL репозитория: " REPO_URL
        git clone "$REPO_URL" /opt/xray-service
    fi
    
    cd /opt/xray-service
    chown -R xray-service:xray-service /opt/xray-service
    
    log "Проект клонирован"
}

# Настройка переменных окружения
setup_environment() {
    log "Настройка переменных окружения..."
    
    if [[ ! -f "/opt/xray-service/.env" ]]; then
        cp /opt/xray-service/env.example /opt/xray-service/.env
        warn "Файл .env создан из примера. Необходимо отредактировать его!"
        info "Редактируйте файл: nano /opt/xray-service/.env"
        read -p "Нажмите Enter после редактирования .env файла..."
    else
        log "Файл .env уже существует"
    fi
}

# Генерация ключей
generate_keys() {
    log "Генерация Reality ключей..."
    
    cd /opt/xray-service
    python3 scripts/generate-reality-keys.py
    
    log "Ключи сгенерированы"
}

# Инициализация базы данных
init_database() {
    log "Инициализация базы данных..."
    
    cd /opt/xray-service
    python3 scripts/init-database.py
    
    log "База данных инициализирована"
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

# Настройка Telegram Bot
setup_telegram_bot() {
    log "Настройка Telegram Bot..."
    
    # Чтение токена из .env
    BOT_TOKEN=$(grep "BOT_TOKEN" /opt/xray-service/.env | cut -d= -f2)
    WEBHOOK_URL=$(grep "WEBHOOK_URL" /opt/xray-service/.env | cut -d= -f2)
    
    if [[ -n "$BOT_TOKEN" && -n "$WEBHOOK_URL" ]]; then
        # Установка webhook
        curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
            -d "url=$WEBHOOK_URL/webhook/"
        
        log "Telegram Bot webhook настроен"
    else
        warn "BOT_TOKEN или WEBHOOK_URL не настроены в .env"
    fi
}

# Настройка мониторинга
setup_monitoring() {
    log "Настройка мониторинга..."
    
    # Проверка доступности Grafana
    if curl -s -f "http://localhost:3000" > /dev/null; then
        log "✅ Grafana доступен на http://localhost:3000"
        info "Логин: admin, Пароль: из переменной GRAFANA_PASSWORD"
    else
        warn "Grafana недоступен"
    fi
    
    # Проверка доступности Prometheus
    if curl -s -f "http://localhost:9090" > /dev/null; then
        log "✅ Prometheus доступен на http://localhost:9090"
    else
        warn "Prometheus недоступен"
    fi
}

# Настройка cron задач
setup_cron() {
    log "Настройка cron задач..."
    
    # Создание cron задач
    cat > /tmp/xray-cron << EOF
# Обновление SNI каждые 6 часов
0 */6 * * * cd /opt/xray-service && ./scripts/update-sni.sh

# Мониторинг каждые 5 минут
*/5 * * * * cd /opt/xray-service && ./scripts/monitor-servers.sh

# Backup базы данных каждый день в 2:00
0 2 * * * cd /opt/xray-service && python3 scripts/backup-database.py

# Проверка безопасности каждую неделю
0 3 * * 0 cd /opt/xray-service && ./scripts/security-audit.sh
EOF
    
    # Установка cron задач
    crontab /tmp/xray-cron
    rm /tmp/xray-cron
    
    log "Cron задачи настроены"
}

# Генерация отчета о запуске
generate_startup_report() {
    local report_file="/tmp/startup-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=== Xray VLESS + Reality Service Startup Report ==="
        echo "Дата запуска: $(date)"
        echo "Сервер: $(hostname)"
        echo "IP адрес: $(curl -s ifconfig.me)"
        echo ""
        
        echo "=== Статус сервисов ==="
        cd /opt/xray-service && docker-compose ps
        echo ""
        
        echo "=== Health Checks ==="
        echo "Xray Manager: $(curl -s http://localhost:8080/health | jq -r '.status' 2>/dev/null || echo 'FAIL')"
        echo "Telegram Bot: $(curl -s http://localhost:8001/health | jq -r '.status' 2>/dev/null || echo 'FAIL')"
        echo "Payment Service: $(curl -s http://localhost:8002/health | jq -r '.status' 2>/dev/null || echo 'FAIL')"
        echo ""
        
        echo "=== Мониторинг ==="
        echo "Grafana: http://$(curl -s ifconfig.me):3000"
        echo "Prometheus: http://$(curl -s ifconfig.me):9090"
        echo ""
        
        echo "=== Следующие шаги ==="
        echo "1. Настройте платежные системы (YooKassa, Robokassa)"
        echo "2. Протестируйте все функции"
        echo "3. Запустите рекламную кампанию"
        echo "4. Мониторьте производительность"
        echo ""
        
        echo "=== Полезные команды ==="
        echo "Просмотр логов: docker-compose logs -f"
        echo "Перезапуск: docker-compose restart"
        echo "Обновление: docker-compose pull && docker-compose up -d"
        echo "Остановка: docker-compose down"
        
    } > "$report_file"
    
    log "Отчет о запуске сохранен в: $report_file"
    echo "$report_file"
}

# Основная функция
main() {
    log "🚀 Запуск Xray VLESS + Reality сервиса..."
    
    # Проверка прав
    check_root
    
    # Подготовка системы
    update_system
    install_docker
    install_packages
    install_xray
    setup_firewall
    create_service_user
    create_directories
    
    # Настройка проекта
    clone_project
    setup_environment
    generate_keys
    init_database
    
    # Запуск сервисов
    start_services
    check_status
    setup_telegram_bot
    setup_monitoring
    setup_cron
    
    # Генерация отчета
    report_file=$(generate_startup_report)
    
    log "🎉 Сервис успешно запущен!"
    log "Отчет: $report_file"
    
    info "Следующие шаги:"
    info "1. Настройте платежные системы в .env файле"
    info "2. Протестируйте все функции"
    info "3. Запустите рекламную кампанию"
    info "4. Мониторьте производительность через Grafana"
    
    warn "Не забудьте отредактировать .env файл с вашими настройками!"
}

# Запуск скрипта
main "$@"
