#!/bin/bash

# Скрипт настройки Robokassa

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

# Настройка Robokassa
setup_robokassa() {
    log "Настройка Robokassa..."
    
    echo "Для настройки Robokassa выполните следующие шаги:"
    echo ""
    echo "1. Перейдите на https://robokassa.ru"
    echo "2. Нажмите 'Регистрация'"
    echo "3. Заполните форму регистрации:"
    echo "   - Название магазина: Xray VPN Service"
    echo "   - Описание: Сервис продажи VPN конфигураций"
    echo "   - Категория: IT услуги"
    echo "4. Подтвердите email и телефон"
    echo "5. Загрузите документы (паспорт, ИНН)"
    echo "6. Дождитесь модерации (1-3 дня)"
    echo ""
    
    read -p "Нажмите Enter после завершения регистрации..."
    
    echo ""
    echo "После модерации:"
    echo "1. Войдите в личный кабинет Robokassa"
    echo "2. Перейдите в 'Настройки' -> 'Технические настройки'"
    echo "3. Скопируйте Merchant Login и пароли"
    echo ""
    
    read -p "Введите Merchant Login: " MERCHANT_LOGIN
    read -p "Введите Password 1: " PASSWORD_1
    read -p "Введите Password 2: " PASSWORD_2
    
    # Обновление .env файла
    sed -i "s/ROBOKASSA_MERCHANT_LOGIN=.*/ROBOKASSA_MERCHANT_LOGIN=$MERCHANT_LOGIN/" /opt/xray-service/.env
    sed -i "s/ROBOKASSA_PASSWORD_1=.*/ROBOKASSA_PASSWORD_1=$PASSWORD_1/" /opt/xray-service/.env
    sed -i "s/ROBOKASSA_PASSWORD_2=.*/ROBOKASSA_PASSWORD_2=$PASSWORD_2/" /opt/xray-service/.env
    
    log "Robokassa настроен"
    
    # Настройка webhook
    WEBHOOK_URL=$(grep "WEBHOOK_URL" /opt/xray-service/.env | cut -d= -f2)
    info "Настройте webhook в Robokassa:"
    info "URL: $WEBHOOK_URL/webhook/robokassa"
    
    echo ""
    echo "Инструкция по настройке webhook:"
    echo "1. В личном кабинете Robokassa перейдите в 'Настройки' -> 'Webhook'"
    echo "2. Добавьте новый webhook:"
    echo "   - URL: $WEBHOOK_URL/webhook/robokassa"
    echo "   - События: payment.succeeded, payment.canceled"
    echo "3. Сохраните настройки"
}

# Тестирование Robokassa
test_robokassa() {
    log "Тестирование Robokassa..."
    
    # Перезапуск сервисов
    cd /opt/xray-service
    docker-compose restart payment-service
    
    # Ожидание запуска
    sleep 10
    
    # Проверка статуса
    if curl -s -f "http://localhost:8002/health" > /dev/null; then
        log "✅ Payment Service работает"
    else
        error "❌ Payment Service не работает"
    fi
    
    # Тест создания платежа
    info "Тестирование создания платежа..."
    
    test_payment=$(curl -s -X POST "http://localhost:8002/api/v1/payments/create" \
        -H "Content-Type: application/json" \
        -d '{"user_id": 1, "amount": 200, "currency": "RUB", "description": "Тестовый платеж", "payment_system": "robokassa"}')
    
    if echo "$test_payment" | grep -q "payment_id"; then
        log "✅ Создание платежа работает"
    else
        warn "⚠️  Проблемы с созданием платежа"
    fi
}

# Основная функция
main() {
    log "Настройка Robokassa..."
    
    setup_robokassa
    
    echo ""
    read -p "Хотите протестировать Robokassa? (y/n): " test_choice
    
    if [[ "$test_choice" == "y" || "$test_choice" == "Y" ]]; then
        test_robokassa
    fi
    
    log "Настройка Robokassa завершена"
}

main "$@"
