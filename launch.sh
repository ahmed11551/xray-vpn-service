#!/bin/bash

# Главный скрипт запуска Xray VLESS + Reality сервиса

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
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           🚀 Xray VLESS + Reality Service                   ║"
    echo "║                                                              ║"
    echo "║              Коммерческий VPN сервис                        ║"
    echo "║                                                              ║"
    echo "║         Автоматический обход блокировок мобильных            ║"
    echo "║                    операторов России                         ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Проверка системы
check_system() {
    log "Проверка системы..."
    
    # Проверка ОС
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        error "Этот скрипт предназначен для Linux"
        exit 1
    fi
    
    # Проверка прав root
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    # Проверка архитектуры
    arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        warn "Архитектура $arch может не поддерживаться"
    fi
    
    success "Система проверена"
}

# Меню выбора
show_menu() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    МЕНЮ ЗАПУСКА                              ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ 1. 🚀 Быстрый запуск (автоматическая настройка)            ║"
    echo "║ 2. 🔧 Пошаговая настройка                                  ║"
    echo "║ 3. 💳 Настройка платежных систем                           ║"
    echo "║ 4. 🤖 Настройка Telegram Bot                               ║"
    echo "║ 5. 🧪 Тестирование и проверка                              ║"
    echo "║ 6. 📊 Мониторинг и статистика                              ║"
    echo "║ 7. 🔒 Проверка безопасности                                ║"
    echo "║ 8. 📋 Статус сервисов                                      ║"
    echo "║ 9. 🔄 Перезапуск сервисов                                  ║"
    echo "║ 0. ❌ Выход                                                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Быстрый запуск
quick_start() {
    log "🚀 Быстрый запуск сервиса..."
    
    echo "Этот режим выполнит автоматическую настройку:"
    echo "1. Установка Docker и зависимостей"
    echo "2. Клонирование проекта"
    echo "3. Настройка переменных окружения"
    echo "4. Генерация ключей"
    echo "5. Инициализация базы данных"
    echo "6. Запуск сервисов"
    echo ""
    
    read -p "Продолжить? (y/n): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        chmod +x scripts/quick-start.sh
        ./scripts/quick-start.sh
    else
        info "Быстрый запуск отменен"
    fi
}

# Пошаговая настройка
step_by_step() {
    log "🔧 Пошаговая настройка..."
    
    echo "Выберите этап настройки:"
    echo "1. Подготовка системы"
    echo "2. Установка зависимостей"
    echo "3. Настройка проекта"
    echo "4. Запуск сервисов"
    echo "5. Настройка мониторинга"
    echo ""
    
    read -p "Введите номер этапа (1-5): " step
    
    case $step in
        1)
            info "Этап 1: Подготовка системы"
            apt update && apt upgrade -y
            apt install -y git curl wget jq python3 python3-pip
            success "Система подготовлена"
            ;;
        2)
            info "Этап 2: Установка зависимостей"
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            rm get-docker.sh
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            success "Зависимости установлены"
            ;;
        3)
            info "Этап 3: Настройка проекта"
            if [[ ! -d "/opt/xray-service" ]]; then
                read -p "Введите URL репозитория: " REPO_URL
                git clone "$REPO_URL" /opt/xray-service
            fi
            cd /opt/xray-service
            cp env.example .env
            info "Отредактируйте файл .env: nano .env"
            read -p "Нажмите Enter после редактирования .env файла..."
            success "Проект настроен"
            ;;
        4)
            info "Этап 4: Запуск сервисов"
            cd /opt/xray-service
            python3 scripts/generate-reality-keys.py
            python3 scripts/init-database.py
            docker-compose up -d
            success "Сервисы запущены"
            ;;
        5)
            info "Этап 5: Настройка мониторинга"
            cd /opt/xray-service
            chmod +x scripts/*.sh
            ./scripts/setup-monitoring.sh
            success "Мониторинг настроен"
            ;;
        *)
            error "Неверный номер этапа"
            ;;
    esac
}

# Настройка платежных систем
setup_payments() {
    log "💳 Настройка платежных систем..."
    
    chmod +x scripts/setup-payments.sh
    ./scripts/setup-payments.sh
}

# Настройка Telegram Bot
setup_telegram_bot() {
    log "🤖 Настройка Telegram Bot..."
    
    chmod +x scripts/setup-telegram-bot.sh
    ./scripts/setup-telegram-bot.sh
}

# Тестирование
test_services() {
    log "🧪 Тестирование сервисов..."
    
    chmod +x scripts/test-and-launch.sh
    ./scripts/test-and-launch.sh
}

# Мониторинг
show_monitoring() {
    log "📊 Мониторинг и статистика..."
    
    echo "Доступные дашборды:"
    echo "1. Grafana: http://$(curl -s ifconfig.me):3000"
    echo "2. Prometheus: http://$(curl -s ifconfig.me):9090"
    echo ""
    
    echo "Статус сервисов:"
    cd /opt/xray-service
    docker-compose ps
    
    echo ""
    echo "Использование ресурсов:"
    echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')"
    echo "Memory: $(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')%"
    echo "Disk: $(df / | tail -1 | awk '{print $5}')"
}

# Проверка безопасности
security_check() {
    log "🔒 Проверка безопасности..."
    
    chmod +x scripts/security-audit.sh
    ./scripts/security-audit.sh
}

# Статус сервисов
show_status() {
    log "📋 Статус сервисов..."
    
    cd /opt/xray-service
    
    echo "Docker контейнеры:"
    docker-compose ps
    
    echo ""
    echo "Health checks:"
    
    services=(
        "Xray Manager:8080"
        "Telegram Bot:8001"
        "Payment Service:8002"
        "PostgreSQL:5432"
        "Redis:6379"
        "Grafana:3000"
        "Prometheus:9090"
    )
    
    for service in "${services[@]}"; do
        name=$(echo $service | cut -d: -f1)
        port=$(echo $service | cut -d: -f2)
        
        if curl -s -f "http://localhost:$port" > /dev/null 2>&1; then
            success "✅ $name - OK"
        else
            error "❌ $name - FAIL"
        fi
    done
}

# Перезапуск сервисов
restart_services() {
    log "🔄 Перезапуск сервисов..."
    
    cd /opt/xray-service
    
    echo "Выберите действие:"
    echo "1. Перезапустить все сервисы"
    echo "2. Перезапустить конкретный сервис"
    echo "3. Остановить все сервисы"
    echo "4. Запустить все сервисы"
    
    read -p "Введите номер (1-4): " choice
    
    case $choice in
        1)
            docker-compose restart
            success "Все сервисы перезапущены"
            ;;
        2)
            docker-compose ps
            read -p "Введите имя сервиса: " service_name
            docker-compose restart "$service_name"
            success "Сервис $service_name перезапущен"
            ;;
        3)
            docker-compose down
            success "Все сервисы остановлены"
            ;;
        4)
            docker-compose up -d
            success "Все сервисы запущены"
            ;;
        *)
            error "Неверный выбор"
            ;;
    esac
}

# Основная функция
main() {
    show_header
    check_system
    
    while true; do
        show_menu
        read -p "Введите номер (0-9): " choice
        
        case $choice in
            1)
                quick_start
                ;;
            2)
                step_by_step
                ;;
            3)
                setup_payments
                ;;
            4)
                setup_telegram_bot
                ;;
            5)
                test_services
                ;;
            6)
                show_monitoring
                ;;
            7)
                security_check
                ;;
            8)
                show_status
                ;;
            9)
                restart_services
                ;;
            0)
                log "До свидания!"
                exit 0
                ;;
            *)
                error "Неверный выбор. Попробуйте снова."
                ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
        clear
    done
}

# Запуск скрипта
main "$@"
