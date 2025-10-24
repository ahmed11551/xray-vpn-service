#!/bin/bash

# Скрипт настройки YooKassa

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

# Настройка YooKassa
setup_yookassa() {
    log "Настройка YooKassa..."
    
    echo "Для настройки YooKassa выполните следующие шаги:"
    echo ""
    echo "1. Перейдите на https://yookassa.ru"
    echo "2. Нажмите 'Подключить магазин'"
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
    echo "1. Войдите в личный кабинет YooKassa"
    echo "2. Перейдите в 'Настройки' -> 'API'"
    echo "3. Скопируйте Shop ID и Secret Key"
    echo ""
    
    read -p "Введите Shop ID: " SHOP_ID
    read -p "Введите Secret Key: " SECRET_KEY
    
    # Генерация Webhook Secret
    WEBHOOK_SECRET=$(openssl rand -hex 32)
    
    # Обновление .env файла
    sed -i "s/YOOKASSA_SHOP_ID=.*/YOOKASSA_SHOP_ID=$SHOP_ID/" /opt/xray-service/.env
    sed -i "s/YOOKASSA_SECRET_KEY=.*/YOOKASSA_SECRET_KEY=$SECRET_KEY/" /opt/xray-service/.env
    sed -i "s/YOOKASSA_WEBHOOK_SECRET=.*/YOOKASSA_WEBHOOK_SECRET=$WEBHOOK_SECRET/" /opt/xray-service/.env
    
    log "YooKassa настроен"
    
    # Настройка webhook
    WEBHOOK_URL=$(grep "WEBHOOK_URL" /opt/xray-service/.env | cut -d= -f2)
    info "Настройте webhook в YooKassa:"
    info "URL: $WEBHOOK_URL/webhook/yookassa"
    info "Secret: $WEBHOOK_SECRET"
    
    echo ""
    echo "Инструкция по настройке webhook:"
    echo "1. В личном кабинете YooKassa перейдите в 'Настройки' -> 'Webhook'"
    echo "2. Добавьте новый webhook:"
    echo "   - URL: $WEBHOOK_URL/webhook/yookassa"
    echo "   - События: payment.succeeded, payment.canceled"
    echo "   - Secret: $WEBHOOK_SECRET"
    echo "3. Сохраните настройки"
}

# Тестирование YooKassa
test_yookassa() {
    log "Тестирование YooKassa..."
    
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
        -d '{"user_id": 1, "amount": 200, "currency": "RUB", "description": "Тестовый платеж"}')
    
    if echo "$test_payment" | grep -q "payment_id"; then
        log "✅ Создание платежа работает"
    else
        warn "⚠️  Проблемы с созданием платежа"
    fi
}

# Основная функция
main() {
    log "Настройка YooKassa..."
    
    setup_yookassa
    
    echo ""
    read -p "Хотите протестировать YooKassa? (y/n): " test_choice
    
    if [[ "$test_choice" == "y" || "$test_choice" == "Y" ]]; then
        test_yookassa
    fi
    
    log "Настройка YooKassa завершена"
}

main "$@"
