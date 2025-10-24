#!/bin/bash

# Скрипт тестирования и запуска сервиса

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

# Тестирование всех сервисов
test_all_services() {
    log "Тестирование всех сервисов..."
    
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
            log "✅ $name - OK"
        else
            error "❌ $name - FAIL"
        fi
    done
}

# Тестирование API endpoints
test_api_endpoints() {
    log "Тестирование API endpoints..."
    
    # Тест Xray Manager API
    info "Тестирование Xray Manager API..."
    
    # Получение серверов
    servers_response=$(curl -s "http://localhost:8080/api/v1/servers")
    if echo "$servers_response" | grep -q "servers"; then
        log "✅ GET /api/v1/servers - OK"
    else
        error "❌ GET /api/v1/servers - FAIL"
    fi
    
    # Тест Payment Service API
    info "Тестирование Payment Service API..."
    
    # Статистика платежей
    payments_response=$(curl -s "http://localhost:8002/api/v1/stats/payments")
    if echo "$payments_response" | grep -q "payments"; then
        log "✅ GET /api/v1/stats/payments - OK"
    else
        error "❌ GET /api/v1/stats/payments - FAIL"
    fi
    
    # Тест создания платежа
    payment_response=$(curl -s -X POST "http://localhost:8002/api/v1/payments/create" \
        -H "Content-Type: application/json" \
        -d '{"user_id": 1, "amount": 200, "currency": "RUB", "description": "Тестовый платеж"}')
    
    if echo "$payment_response" | grep -q "payment_id"; then
        log "✅ POST /api/v1/payments/create - OK"
    else
        error "❌ POST /api/v1/payments/create - FAIL"
    fi
}

# Тестирование Telegram Bot
test_telegram_bot() {
    log "Тестирование Telegram Bot..."
    
    BOT_TOKEN=$(grep "BOT_TOKEN" /opt/xray-service/.env | cut -d= -f2)
    
    if [[ -z "$BOT_TOKEN" ]]; then
        error "BOT_TOKEN не настроен"
        return 1
    fi
    
    # Проверка информации о боте
    bot_info=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe")
    
    if echo "$bot_info" | grep -q '"ok":true'; then
        bot_username=$(echo "$bot_info" | jq -r '.result.username')
        log "✅ Telegram Bot работает: @$bot_username"
    else
        error "❌ Telegram Bot не работает"
        return 1
    fi
    
    # Проверка webhook
    webhook_info=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo")
    
    if echo "$webhook_info" | grep -q '"ok":true'; then
        webhook_url=$(echo "$webhook_info" | jq -r '.result.url')
        if [[ "$webhook_url" != "null" ]]; then
            log "✅ Webhook настроен: $webhook_url"
        else
            warn "⚠️  Webhook не настроен"
        fi
    else
        error "❌ Ошибка получения информации о webhook"
    fi
}

# Тестирование базы данных
test_database() {
    log "Тестирование базы данных..."
    
    # Проверка подключения
    if docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -c "SELECT 1;" > /dev/null 2>&1; then
        log "✅ Подключение к PostgreSQL - OK"
    else
        error "❌ Подключение к PostgreSQL - FAIL"
        return 1
    fi
    
    # Проверка таблиц
    tables_count=$(docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')
    
    if [[ $tables_count -gt 0 ]]; then
        log "✅ Таблицы в базе данных: $tables_count"
    else
        error "❌ Таблицы в базе данных не найдены"
        return 1
    fi
    
    # Проверка Redis
    if docker exec xray-service_redis_1 redis-cli ping > /dev/null 2>&1; then
        log "✅ Подключение к Redis - OK"
    else
        error "❌ Подключение к Redis - FAIL"
        return 1
    fi
}

# Тестирование Xray серверов
test_xray_servers() {
    log "Тестирование Xray серверов..."
    
    # Получение списка серверов
    servers_response=$(curl -s "http://localhost:8080/api/v1/servers")
    
    if echo "$servers_response" | grep -q "servers"; then
        servers_count=$(echo "$servers_response" | jq '.items | length')
        log "✅ Найдено серверов: $servers_count"
        
        # Проверка каждого сервера
        for i in $(seq 0 $((servers_count-1))); do
            server_id=$(echo "$servers_response" | jq -r ".items[$i].server_id")
            server_status=$(echo "$servers_response" | jq -r ".items[$i].status")
            
            if [[ "$server_status" == "active" ]]; then
                log "✅ Сервер $server_id - активен"
            else
                warn "⚠️  Сервер $server_id - неактивен"
            fi
        done
    else
        error "❌ Не удалось получить список серверов"
        return 1
    fi
}

# Тестирование мониторинга
test_monitoring() {
    log "Тестирование мониторинга..."
    
    # Проверка Prometheus
    if curl -s -f "http://localhost:9090" > /dev/null; then
        log "✅ Prometheus доступен"
        
        # Проверка метрик
        metrics_endpoints=(
            "http://localhost:8080/metrics"
            "http://localhost:8001/metrics"
            "http://localhost:8002/metrics"
        )
        
        for endpoint in "${metrics_endpoints[@]}"; do
            if curl -s -f "$endpoint" > /dev/null; then
                log "✅ Метрики доступны: $endpoint"
            else
                warn "⚠️  Метрики недоступны: $endpoint"
            fi
        done
    else
        error "❌ Prometheus недоступен"
    fi
    
    # Проверка Grafana
    if curl -s -f "http://localhost:3000" > /dev/null; then
        log "✅ Grafana доступен"
    else
        error "❌ Grafana недоступен"
    fi
}

# Нагрузочное тестирование
load_testing() {
    log "Нагрузочное тестирование..."
    
    # Проверка наличия Apache Bench
    if ! command -v ab >/dev/null 2>&1; then
        warn "Apache Bench не установлен, пропускаем нагрузочное тестирование"
        return 0
    fi
    
    # Тестирование Xray Manager
    info "Нагрузочное тестирование Xray Manager..."
    ab -n 100 -c 10 "http://localhost:8080/api/v1/servers" > /tmp/ab_xray_manager.log 2>&1
    
    if grep -q "Failed requests:        0" /tmp/ab_xray_manager.log; then
        log "✅ Xray Manager - все запросы успешны"
    else
        failed=$(grep "Failed requests:" /tmp/ab_xray_manager.log | awk '{print $3}')
        warn "⚠️  Xray Manager - $failed неуспешных запросов"
    fi
    
    # Тестирование Payment Service
    info "Нагрузочное тестирование Payment Service..."
    ab -n 100 -c 10 "http://localhost:8002/api/v1/stats/payments" > /tmp/ab_payment_service.log 2>&1
    
    if grep -q "Failed requests:        0" /tmp/ab_payment_service.log; then
        log "✅ Payment Service - все запросы успешны"
    else
        failed=$(grep "Failed requests:" /tmp/ab_payment_service.log | awk '{print $3}')
        warn "⚠️  Payment Service - $failed неуспешных запросов"
    fi
}

# Проверка безопасности
security_check() {
    log "Проверка безопасности..."
    
    # Проверка SSL сертификатов
    WEBHOOK_URL=$(grep "WEBHOOK_URL" /opt/xray-service/.env | cut -d= -f2)
    domain=$(echo "$WEBHOOK_URL" | sed 's|https://||' | sed 's|/.*||')
    
    if [[ -n "$domain" && "$domain" != "your-domain.com" ]]; then
        # Проверка SSL сертификата
        expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates | grep "notAfter" | cut -d= -f2)
        
        if [[ -n "$expiry_date" ]]; then
            expiry_timestamp=$(date -d "$expiry_date" +%s)
            current_timestamp=$(date +%s)
            days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            if [[ $days_until_expiry -gt 30 ]]; then
                log "✅ SSL сертификат действителен еще $days_until_expiry дней"
            else
                warn "⚠️  SSL сертификат истекает через $days_until_expiry дней"
            fi
        else
            warn "⚠️  SSL сертификат не найден"
        fi
    else
        warn "⚠️  Домен не настроен в WEBHOOK_URL"
    fi
    
    # Проверка файрвола
    if command -v ufw >/dev/null 2>&1; then
        ufw_status=$(ufw status | head -1)
        if echo "$ufw_status" | grep -q "active"; then
            log "✅ UFW активен"
        else
            warn "⚠️  UFW неактивен"
        fi
    fi
}

# Генерация отчета о тестировании
generate_test_report() {
    local report_file="/tmp/test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=== Test Report ==="
        echo "Дата тестирования: $(date)"
        echo "Сервер: $(hostname)"
        echo "IP адрес: $(curl -s ifconfig.me)"
        echo ""
        
        echo "=== Статус сервисов ==="
        docker-compose ps
        echo ""
        
        echo "=== Результаты тестирования ==="
        echo "Все тесты выполнены"
        echo ""
        
        echo "=== Рекомендации ==="
        echo "1. Протестируйте все функции вручную"
        echo "2. Настройте мониторинг и алерты"
        echo "3. Запустите рекламную кампанию"
        echo "4. Мониторьте производительность"
        
    } > "$report_file"
    
    log "Отчет о тестировании сохранен в: $report_file"
    echo "$report_file"
}

# Основная функция
main() {
    log "🧪 Тестирование и запуск сервиса..."
    
    echo "Выберите тип тестирования:"
    echo "1. Быстрое тестирование"
    echo "2. Полное тестирование"
    echo "3. Нагрузочное тестирование"
    echo "4. Проверка безопасности"
    echo "5. Все тесты"
    
    read -p "Введите номер (1-5): " choice
    
    case $choice in
        1)
            test_all_services
            test_api_endpoints
            test_telegram_bot
            ;;
        2)
            test_all_services
            test_api_endpoints
            test_telegram_bot
            test_database
            test_xray_servers
            test_monitoring
            ;;
        3)
            load_testing
            ;;
        4)
            security_check
            ;;
        5)
            test_all_services
            test_api_endpoints
            test_telegram_bot
            test_database
            test_xray_servers
            test_monitoring
            load_testing
            security_check
            ;;
        *)
            error "Неверный выбор"
            exit 1
            ;;
    esac
    
    # Генерация отчета
    report_file=$(generate_test_report)
    
    log "🎉 Тестирование завершено!"
    log "Отчет: $report_file"
    
    info "Следующие шаги:"
    info "1. Протестируйте бота, отправив /start"
    info "2. Создайте тестового пользователя"
    info "3. Протестируйте генерацию конфигураций"
    info "4. Протестируйте платежи"
    info "5. Запустите рекламную кампанию"
}

main "$@"
