#!/bin/bash

# Скрипт настройки платежных систем

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
    echo "1. Зарегистрируйтесь на https://yookassa.ru"
    echo "2. Создайте магазин"
    echo "3. Получите Shop ID и Secret Key"
    echo ""
    
    read -p "Введите Shop ID: " SHOP_ID
    read -p "Введите Secret Key: " SECRET_KEY
    read -p "Введите Webhook Secret: " WEBHOOK_SECRET
    
    # Обновление .env файла
    sed -i "s/YOOKASSA_SHOP_ID=.*/YOOKASSA_SHOP_ID=$SHOP_ID/" /opt/xray-service/.env
    sed -i "s/YOOKASSA_SECRET_KEY=.*/YOOKASSA_SECRET_KEY=$SECRET_KEY/" /opt/xray-service/.env
    sed -i "s/YOOKASSA_WEBHOOK_SECRET=.*/YOOKASSA_WEBHOOK_SECRET=$WEBHOOK_SECRET/" /opt/xray-service/.env
    
    log "YooKassa настроен"
    
    # Настройка webhook
    WEBHOOK_URL=$(grep "WEBHOOK_URL" /opt/xray-service/.env | cut -d= -f2)
    info "Настройте webhook в YooKassa: $WEBHOOK_URL/webhook/yookassa"
}

# Настройка Robokassa
setup_robokassa() {
    log "Настройка Robokassa..."
    
    echo "Для настройки Robokassa выполните следующие шаги:"
    echo "1. Зарегистрируйтесь на https://robokassa.ru"
    echo "2. Создайте магазин"
    echo "3. Получите Merchant Login и пароли"
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
    info "Настройте webhook в Robokassa: $WEBHOOK_URL/webhook/robokassa"
}

# Настройка криптовалютных кошельков
setup_crypto() {
    log "Настройка криптовалютных кошельков..."
    
    echo "Настройка криптовалютных кошельков:"
    echo ""
    
    read -p "Введите Bitcoin адрес: " BTC_ADDRESS
    read -p "Введите Ethereum адрес: " ETH_ADDRESS
    read -p "Введите USDT TRC20 адрес: " USDT_TRC20_ADDRESS
    read -p "Введите USDT ERC20 адрес: " USDT_ERC20_ADDRESS
    
    # Обновление .env файла
    sed -i "s/BITCOIN_WALLET_ADDRESS=.*/BITCOIN_WALLET_ADDRESS=$BTC_ADDRESS/" /opt/xray-service/.env
    sed -i "s/ETHEREUM_WALLET_ADDRESS=.*/ETHEREUM_WALLET_ADDRESS=$ETH_ADDRESS/" /opt/xray-service/.env
    sed -i "s/USDT_TRC20_WALLET_ADDRESS=.*/USDT_TRC20_WALLET_ADDRESS=$USDT_TRC20_ADDRESS/" /opt/xray-service/.env
    sed -i "s/USDT_ERC20_WALLET_ADDRESS=.*/USDT_ERC20_WALLET_ADDRESS=$USDT_ERC20_ADDRESS/" /opt/xray-service/.env
    
    log "Криптовалютные кошельки настроены"
}

# Тестирование платежных систем
test_payments() {
    log "Тестирование платежных систем..."
    
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
    log "Настройка платежных систем..."
    
    echo "Выберите платежную систему для настройки:"
    echo "1. YooKassa"
    echo "2. Robokassa"
    echo "3. Криптовалютные кошельки"
    echo "4. Все системы"
    echo "5. Тестирование"
    
    read -p "Введите номер (1-5): " choice
    
    case $choice in
        1)
            setup_yookassa
            ;;
        2)
            setup_robokassa
            ;;
        3)
            setup_crypto
            ;;
        4)
            setup_yookassa
            setup_robokassa
            setup_crypto
            ;;
        5)
            test_payments
            ;;
        *)
            error "Неверный выбор"
            exit 1
            ;;
    esac
    
    log "Настройка платежных систем завершена"
}

main "$@"
