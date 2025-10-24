#!/bin/bash

# Скрипт создания Telegram Bot

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

# Создание Telegram Bot
create_telegram_bot() {
    log "Создание Telegram Bot..."
    
    echo "Для создания Telegram Bot выполните следующие шаги:"
    echo ""
    echo "1. Откройте Telegram и найдите @BotFather"
    echo "2. Отправьте команду /newbot"
    echo "3. Введите имя бота (например: Xray VPN Service)"
    echo "4. Введите username бота (например: xray_vpn_bot)"
    echo "5. Скопируйте полученный токен"
    echo ""
    
    read -p "Введите токен бота: " BOT_TOKEN
    
    if [[ -z "$BOT_TOKEN" ]]; then
        error "Токен бота не может быть пустым"
        exit 1
    fi
    
    # Обновление .env файла
    sed -i "s/BOT_TOKEN=.*/BOT_TOKEN=$BOT_TOKEN/" /opt/xray-service/.env
    
    log "Telegram Bot токен сохранен"
    
    # Получение информации о боте
    bot_info=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe")
    
    if echo "$bot_info" | grep -q '"ok":true'; then
        bot_username=$(echo "$bot_info" | jq -r '.result.username')
        bot_name=$(echo "$bot_info" | jq -r '.result.first_name')
        
        log "✅ Бот создан успешно!"
        info "Имя бота: $bot_name"
        info "Username: @$bot_username"
        info "Токен: $BOT_TOKEN"
    else
        error "Ошибка создания бота. Проверьте токен."
        exit 1
    fi
}

# Настройка команд бота
setup_bot_commands() {
    log "Настройка команд бота..."
    
    BOT_TOKEN=$(grep "BOT_TOKEN" /opt/xray-service/.env | cut -d= -f2)
    
    # Список команд
    commands='[
        {"command": "start", "description": "Начать работу с ботом"},
        {"command": "help", "description": "Справка по командам"},
        {"command": "profile", "description": "Информация о профиле"},
        {"command": "configs", "description": "Мои конфигурации"},
        {"command": "subscribe", "description": "Купить подписку"},
        {"command": "referral", "description": "Реферальная программа"},
        {"command": "support", "description": "Связаться с поддержкой"}
    ]'
    
    # Установка команд
    curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/setMyCommands" \
        -H "Content-Type: application/json" \
        -d "{\"commands\": $commands}"
    
    log "Команды бота настроены"
}

# Настройка webhook
setup_webhook() {
    log "Настройка webhook..."
    
    BOT_TOKEN=$(grep "BOT_TOKEN" /opt/xray-service/.env | cut -d= -f2)
    WEBHOOK_URL=$(grep "WEBHOOK_URL" /opt/xray-service/.env | cut -d= -f2)
    WEBHOOK_SECRET=$(openssl rand -hex 32)
    
    # Обновление .env файла
    sed -i "s/WEBHOOK_SECRET=.*/WEBHOOK_SECRET=$WEBHOOK_SECRET/" /opt/xray-service/.env
    
    # Установка webhook
    webhook_result=$(curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
        -d "url=$WEBHOOK_URL/webhook/" \
        -d "secret_token=$WEBHOOK_SECRET")
    
    if echo "$webhook_result" | grep -q '"ok":true'; then
        log "✅ Webhook настроен успешно"
        info "URL: $WEBHOOK_URL/webhook/"
        info "Secret: $WEBHOOK_SECRET"
    else
        error "Ошибка настройки webhook"
        echo "$webhook_result"
    fi
}

# Настройка описания бота
setup_bot_description() {
    log "Настройка описания бота..."
    
    BOT_TOKEN=$(grep "BOT_TOKEN" /opt/xray-service/.env | cut -d= -f2)
    
    description="🚀 Xray VLESS + Reality Service

🔹 Полный доступ к YouTube, Instagram, Facebook
🔹 Работает через мобильный интернет
🔹 Автоматическое обновление конфигураций
🔹 Бесплатный тест на 1 день
🔹 Реферальная программа

Нажмите /start для начала работы!"
    
    # Установка описания
    curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/setMyDescription" \
        -d "description=$description"
    
    log "Описание бота настроено"
}

# Тестирование бота
test_bot() {
    log "Тестирование бота..."
    
    BOT_TOKEN=$(grep "BOT_TOKEN" /opt/xray-service/.env | cut -d= -f2)
    
    # Проверка информации о боте
    bot_info=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe")
    
    if echo "$bot_info" | grep -q '"ok":true'; then
        log "✅ Бот работает корректно"
        
        # Проверка webhook
        webhook_info=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo")
        
        if echo "$webhook_info" | grep -q '"ok":true'; then
            webhook_url=$(echo "$webhook_info" | jq -r '.result.url')
            log "✅ Webhook настроен: $webhook_url"
        else
            warn "⚠️  Webhook не настроен"
        fi
        
        # Проверка команд
        commands_info=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMyCommands")
        
        if echo "$commands_info" | grep -q '"ok":true'; then
            commands_count=$(echo "$commands_info" | jq '.result | length')
            log "✅ Команды настроены: $commands_count"
        else
            warn "⚠️  Команды не настроены"
        fi
        
    else
        error "❌ Бот не работает"
        echo "$bot_info"
    fi
}

# Перезапуск сервисов
restart_services() {
    log "Перезапуск сервисов..."
    
    cd /opt/xray-service
    docker-compose restart telegram-bot
    
    # Ожидание запуска
    sleep 10
    
    # Проверка статуса
    if curl -s -f "http://localhost:8001/health" > /dev/null; then
        log "✅ Telegram Bot Service работает"
    else
        error "❌ Telegram Bot Service не работает"
    fi
}

# Основная функция
main() {
    log "Настройка Telegram Bot..."
    
    echo "Выберите действие:"
    echo "1. Создать нового бота"
    echo "2. Настроить существующего бота"
    echo "3. Тестировать бота"
    echo "4. Полная настройка"
    
    read -p "Введите номер (1-4): " choice
    
    case $choice in
        1)
            create_telegram_bot
            setup_bot_commands
            setup_webhook
            setup_bot_description
            restart_services
            test_bot
            ;;
        2)
            read -p "Введите токен существующего бота: " BOT_TOKEN
            sed -i "s/BOT_TOKEN=.*/BOT_TOKEN=$BOT_TOKEN/" /opt/xray-service/.env
            setup_bot_commands
            setup_webhook
            setup_bot_description
            restart_services
            test_bot
            ;;
        3)
            test_bot
            ;;
        4)
            create_telegram_bot
            setup_bot_commands
            setup_webhook
            setup_bot_description
            restart_services
            test_bot
            ;;
        *)
            error "Неверный выбор"
            exit 1
            ;;
    esac
    
    log "Настройка Telegram Bot завершена"
    
    info "Следующие шаги:"
    info "1. Протестируйте бота, отправив /start"
    info "2. Настройте платежные системы"
    info "3. Запустите рекламную кампанию"
}

main "$@"
