#!/bin/bash

# Скрипт нагрузочного тестирования Xray VLESS + Reality сервиса

set -e

# Конфигурация
BASE_URL="https://your-domain.com"
API_URL="$BASE_URL:8080"
BOT_URL="$BASE_URL:8001"
PAYMENT_URL="$BASE_URL:8002"
CONCURRENT_USERS=100
TEST_DURATION=300  # 5 минут
LOG_FILE="/var/log/load-test.log"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Функция проверки доступности сервиса
check_service_health() {
    local service_name=$1
    local url=$2
    
    log "Проверка доступности $service_name..."
    
    if curl -s -f "$url/health" > /dev/null; then
        log "✅ $service_name доступен"
        return 0
    else
        log "❌ $service_name недоступен"
        return 1
    fi
}

# Функция тестирования API endpoints
test_api_endpoints() {
    log "Тестирование API endpoints..."
    
    # Тест получения серверов
    log "Тест: GET /api/v1/servers"
    response=$(curl -s -w "%{http_code}" -o /dev/null "$API_URL/api/v1/servers")
    if [[ "$response" == "200" ]]; then
        log "✅ GET /api/v1/servers - OK"
    else
        log "❌ GET /api/v1/servers - FAIL ($response)"
    fi
    
    # Тест создания конфигурации
    log "Тест: POST /api/v1/configs/generate"
    response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"user_id": 1, "server_id": 1}' \
        "$API_URL/api/v1/configs/generate")
    if [[ "$response" == "200" || "$response" == "201" ]]; then
        log "✅ POST /api/v1/configs/generate - OK"
    else
        log "❌ POST /api/v1/configs/generate - FAIL ($response)"
    fi
    
    # Тест статистики платежей
    log "Тест: GET /api/v1/stats/payments"
    response=$(curl -s -w "%{http_code}" -o /dev/null "$PAYMENT_URL/api/v1/stats/payments")
    if [[ "$response" == "200" ]]; then
        log "✅ GET /api/v1/stats/payments - OK"
    else
        log "❌ GET /api/v1/stats/payments - FAIL ($response)"
    fi
}

# Функция нагрузочного тестирования с Apache Bench
load_test_with_ab() {
    local service_name=$1
    local url=$2
    local endpoint=$3
    local users=$4
    
    log "Нагрузочное тестирование $service_name с $users пользователями..."
    
    ab -n 1000 -c "$users" -g "/tmp/ab_${service_name}.tsv" \
        "$url$endpoint" > "/tmp/ab_${service_name}.log" 2>&1
    
    # Анализ результатов
    if grep -q "Failed requests:        0" "/tmp/ab_${service_name}.log"; then
        log "✅ $service_name - все запросы успешны"
    else
        failed=$(grep "Failed requests:" "/tmp/ab_${service_name}.log" | awk '{print $3}')
        log "❌ $service_name - $failed неуспешных запросов"
    fi
    
    # Время ответа
    avg_time=$(grep "Time per request:" "/tmp/ab_${service_name}.log" | head -1 | awk '{print $4}')
    log "📊 $service_name - среднее время ответа: ${avg_time}ms"
}

# Функция тестирования Xray серверов
test_xray_servers() {
    log "Тестирование Xray серверов..."
    
    # Получение списка серверов
    servers=$(curl -s "$API_URL/api/v1/servers" | jq -r '.items[].server_id')
    
    for server in $servers; do
        log "Тестирование сервера: $server"
        
        # Проверка статуса сервера
        status=$(curl -s "$API_URL/api/v1/servers/$server/status" | jq -r '.status')
        if [[ "$status" == "active" ]]; then
            log "✅ Сервер $server активен"
        else
            log "❌ Сервер $server неактивен"
        fi
        
        # Проверка метрик
        metrics=$(curl -s "$API_URL/api/v1/servers/$server/metrics")
        cpu_usage=$(echo "$metrics" | jq -r '.[0].cpu_usage // 0')
        memory_usage=$(echo "$metrics" | jq -r '.[0].memory_usage // 0')
        
        log "📊 Сервер $server - CPU: ${cpu_usage}%, Memory: ${memory_usage}%"
    done
}

# Функция тестирования базы данных
test_database_performance() {
    log "Тестирование производительности базы данных..."
    
    # Подключение к PostgreSQL
    db_url="postgresql://xray_user:${DB_PASSWORD}@localhost:5432/xray_service"
    
    # Тест простого запроса
    start_time=$(date +%s%N)
    psql "$db_url" -c "SELECT COUNT(*) FROM users;" > /dev/null 2>&1
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    
    log "📊 Простой запрос к БД: ${duration}ms"
    
    # Тест сложного запроса
    start_time=$(date +%s%N)
    psql "$db_url" -c "SELECT u.*, COUNT(c.id) as config_count FROM users u LEFT JOIN configs c ON u.id = c.user_id GROUP BY u.id;" > /dev/null 2>&1
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    
    log "📊 Сложный запрос к БД: ${duration}ms"
}

# Функция тестирования Redis
test_redis_performance() {
    log "Тестирование производительности Redis..."
    
    # Тест записи
    start_time=$(date +%s%N)
    redis-cli set "test_key_$(date +%s)" "test_value" > /dev/null
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    
    log "📊 Запись в Redis: ${duration}ms"
    
    # Тест чтения
    start_time=$(date +%s%N)
    redis-cli get "test_key_$(date +%s)" > /dev/null
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    
    log "📊 Чтение из Redis: ${duration}ms"
}

# Функция мониторинга ресурсов
monitor_resources() {
    log "Мониторинг системных ресурсов..."
    
    # CPU
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    log "📊 CPU usage: ${cpu_usage}%"
    
    # Memory
    memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    log "📊 Memory usage: ${memory_usage}%"
    
    # Disk
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    log "📊 Disk usage: ${disk_usage}%"
    
    # Network connections
    connections=$(netstat -an | grep :443 | wc -l)
    log "📊 Active connections: $connections"
}

# Функция генерации отчета
generate_report() {
    local report_file="/tmp/load-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=== Load Test Report ==="
        echo "Дата: $(date)"
        echo "Тестовая нагрузка: $CONCURRENT_USERS пользователей"
        echo "Длительность: $TEST_DURATION секунд"
        echo ""
        
        echo "=== Результаты тестирования ==="
        echo "API Endpoints:"
        cat /tmp/ab_xray-manager.log | grep -E "(Failed requests|Time per request|Requests per second)"
        echo ""
        
        echo "Payment Service:"
        cat /tmp/ab_payment-service.log | grep -E "(Failed requests|Time per request|Requests per second)"
        echo ""
        
        echo "=== Системные ресурсы ==="
        echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')"
        echo "Memory: $(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')%"
        echo "Disk: $(df / | tail -1 | awk '{print $5}')"
        echo "Connections: $(netstat -an | grep :443 | wc -l)"
        
    } > "$report_file"
    
    log "Отчет сохранен в: $report_file"
    echo "$report_file"
}

# Основная функция
main() {
    log "Начало нагрузочного тестирования..."
    
    # Проверка доступности сервисов
    check_service_health "Xray Manager" "$API_URL" || exit 1
    check_service_health "Telegram Bot" "$BOT_URL" || exit 1
    check_service_health "Payment Service" "$PAYMENT_URL" || exit 1
    
    # Тестирование API endpoints
    test_api_endpoints
    
    # Нагрузочное тестирование
    load_test_with_ab "xray-manager" "$API_URL" "/api/v1/servers" "$CONCURRENT_USERS"
    load_test_with_ab "payment-service" "$PAYMENT_URL" "/api/v1/stats/payments" "$CONCURRENT_USERS"
    
    # Тестирование Xray серверов
    test_xray_servers
    
    # Тестирование производительности
    test_database_performance
    test_redis_performance
    
    # Мониторинг ресурсов
    monitor_resources
    
    # Генерация отчета
    report_file=$(generate_report)
    
    log "Нагрузочное тестирование завершено"
    log "Отчет: $report_file"
    
    # Очистка временных файлов
    rm -f /tmp/ab_*.log /tmp/ab_*.tsv
}

# Запуск скрипта
main "$@"
