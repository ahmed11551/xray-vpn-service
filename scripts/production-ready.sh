#!/bin/bash

# Скрипт подготовки к продакшену Xray VLESS + Reality сервиса

set -e

# Конфигурация
BASE_URL="https://your-domain.com"
LOG_FILE="/var/log/production-ready.log"
CHECKLIST_FILE="/tmp/production-checklist-$(date +%Y%m%d-%H%M%S).txt"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Функция проверки статуса
check_status() {
    local service_name=$1
    local url=$2
    local expected_status=$3
    
    log "Проверка $service_name..."
    
    if curl -s -f "$url/health" > /dev/null; then
        log "✅ $service_name - OK"
        echo "✅ $service_name" >> "$CHECKLIST_FILE"
        return 0
    else
        log "❌ $service_name - FAIL"
        echo "❌ $service_name" >> "$CHECKLIST_FILE"
        return 1
    fi
}

# Функция проверки SSL сертификатов
check_ssl_certificates() {
    log "Проверка SSL сертификатов..."
    
    local domains=("$BASE_URL" "$BASE_URL:8080" "$BASE_URL:8001" "$BASE_URL:8002")
    
    for domain in "${domains[@]}"; do
        log "Проверка SSL для $domain..."
        
        # Проверка срока действия сертификата
        expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain" 2>/dev/null | openssl x509 -noout -dates | grep "notAfter" | cut -d= -f2)
        
        if [[ -n "$expiry_date" ]]; then
            expiry_timestamp=$(date -d "$expiry_date" +%s)
            current_timestamp=$(date +%s)
            days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            if [[ $days_until_expiry -gt 30 ]]; then
                log "✅ SSL сертификат для $domain действителен еще $days_until_expiry дней"
                echo "✅ SSL сертификат для $domain" >> "$CHECKLIST_FILE"
            else
                log "⚠️  SSL сертификат для $domain истекает через $days_until_expiry дней"
                echo "⚠️  SSL сертификат для $domain" >> "$CHECKLIST_FILE"
            fi
        else
            log "❌ SSL сертификат для $domain не найден"
            echo "❌ SSL сертификат для $domain" >> "$CHECKLIST_FILE"
        fi
    done
}

# Функция проверки базы данных
check_database() {
    log "Проверка базы данных..."
    
    # Проверка подключения
    if docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -c "SELECT 1;" > /dev/null 2>&1; then
        log "✅ Подключение к базе данных - OK"
        echo "✅ Подключение к базе данных" >> "$CHECKLIST_FILE"
    else
        log "❌ Подключение к базе данных - FAIL"
        echo "❌ Подключение к базе данных" >> "$CHECKLIST_FILE"
        return 1
    fi
    
    # Проверка таблиц
    tables_count=$(docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')
    
    if [[ $tables_count -gt 0 ]]; then
        log "✅ Таблицы в базе данных: $tables_count"
        echo "✅ Таблицы в базе данных ($tables_count)" >> "$CHECKLIST_FILE"
    else
        log "❌ Таблицы в базе данных не найдены"
        echo "❌ Таблицы в базе данных" >> "$CHECKLIST_FILE"
        return 1
    fi
    
    # Проверка индексов
    indexes_count=$(docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -t -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';" | tr -d ' ')
    
    if [[ $indexes_count -gt 0 ]]; then
        log "✅ Индексы в базе данных: $indexes_count"
        echo "✅ Индексы в базе данных ($indexes_count)" >> "$CHECKLIST_FILE"
    else
        log "⚠️  Индексы в базе данных не найдены"
        echo "⚠️  Индексы в базе данных" >> "$CHECKLIST_FILE"
    fi
}

# Функция проверки Redis
check_redis() {
    log "Проверка Redis..."
    
    # Проверка подключения
    if docker exec xray-service_redis_1 redis-cli ping > /dev/null 2>&1; then
        log "✅ Подключение к Redis - OK"
        echo "✅ Подключение к Redis" >> "$CHECKLIST_FILE"
    else
        log "❌ Подключение к Redis - FAIL"
        echo "❌ Подключение к Redis" >> "$CHECKLIST_FILE"
        return 1
    fi
    
    # Проверка памяти
    memory_usage=$(docker exec xray-service_redis_1 redis-cli info memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
    log "📊 Использование памяти Redis: $memory_usage"
    echo "📊 Использование памяти Redis: $memory_usage" >> "$CHECKLIST_FILE"
}

# Функция проверки мониторинга
check_monitoring() {
    log "Проверка мониторинга..."
    
    # Проверка Prometheus
    if curl -s -f "$BASE_URL:9090" > /dev/null; then
        log "✅ Prometheus доступен"
        echo "✅ Prometheus доступен" >> "$CHECKLIST_FILE"
    else
        log "❌ Prometheus недоступен"
        echo "❌ Prometheus недоступен" >> "$CHECKLIST_FILE"
    fi
    
    # Проверка Grafana
    if curl -s -f "$BASE_URL:3000" > /dev/null; then
        log "✅ Grafana доступен"
        echo "✅ Grafana доступен" >> "$CHECKLIST_FILE"
    else
        log "❌ Grafana недоступен"
        echo "❌ Grafana недоступен" >> "$CHECKLIST_FILE"
    fi
    
    # Проверка метрик
    metrics_endpoints=(
        "$BASE_URL:8080/metrics"
        "$BASE_URL:8001/metrics"
        "$BASE_URL:8002/metrics"
    )
    
    for endpoint in "${metrics_endpoints[@]}"; do
        if curl -s -f "$endpoint" > /dev/null; then
            log "✅ Метрики доступны: $endpoint"
            echo "✅ Метрики доступны: $endpoint" >> "$CHECKLIST_FILE"
        else
            log "❌ Метрики недоступны: $endpoint"
            echo "❌ Метрики недоступны: $endpoint" >> "$CHECKLIST_FILE"
        fi
    done
}

# Функция проверки Telegram Bot
check_telegram_bot() {
    log "Проверка Telegram Bot..."
    
    # Проверка webhook
    webhook_info=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo")
    
    if echo "$webhook_info" | grep -q '"ok":true'; then
        log "✅ Telegram Bot webhook настроен"
        echo "✅ Telegram Bot webhook настроен" >> "$CHECKLIST_FILE"
        
        # Проверка URL webhook
        webhook_url=$(echo "$webhook_info" | jq -r '.result.url')
        if [[ "$webhook_url" == "$BASE_URL/webhook/" ]]; then
            log "✅ URL webhook корректный: $webhook_url"
            echo "✅ URL webhook корректный" >> "$CHECKLIST_FILE"
        else
            log "⚠️  URL webhook некорректный: $webhook_url"
            echo "⚠️  URL webhook некорректный" >> "$CHECKLIST_FILE"
        fi
    else
        log "❌ Telegram Bot webhook не настроен"
        echo "❌ Telegram Bot webhook не настроен" >> "$CHECKLIST_FILE"
    fi
}

# Функция проверки платежных систем
check_payment_systems() {
    log "Проверка платежных систем..."
    
    # Проверка YooKassa
    if [[ -n "$YOOKASSA_SHOP_ID" && -n "$YOOKASSA_SECRET_KEY" ]]; then
        log "✅ YooKassa настроен"
        echo "✅ YooKassa настроен" >> "$CHECKLIST_FILE"
    else
        log "❌ YooKassa не настроен"
        echo "❌ YooKassa не настроен" >> "$CHECKLIST_FILE"
    fi
    
    # Проверка Robokassa
    if [[ -n "$ROBOKASSA_MERCHANT_LOGIN" && -n "$ROBOKASSA_PASSWORD_1" ]]; then
        log "✅ Robokassa настроен"
        echo "✅ Robokassa настроен" >> "$CHECKLIST_FILE"
    else
        log "❌ Robokassa не настроен"
        echo "❌ Robokassa не настроен" >> "$CHECKLIST_FILE"
    fi
    
    # Проверка криптовалютных кошельков
    crypto_wallets=("$BITCOIN_WALLET_ADDRESS" "$ETHEREUM_WALLET_ADDRESS" "$USDT_TRC20_WALLET_ADDRESS")
    crypto_count=0
    
    for wallet in "${crypto_wallets[@]}"; do
        if [[ -n "$wallet" && "$wallet" != "your_*_address" ]]; then
            ((crypto_count++))
        fi
    done
    
    if [[ $crypto_count -gt 0 ]]; then
        log "✅ Криптовалютные кошельки настроены: $crypto_count"
        echo "✅ Криптовалютные кошельки настроены ($crypto_count)" >> "$CHECKLIST_FILE"
    else
        log "❌ Криптовалютные кошельки не настроены"
        echo "❌ Криптовалютные кошельки не настроены" >> "$CHECKLIST_FILE"
    fi
}

# Функция проверки безопасности
check_security() {
    log "Проверка безопасности..."
    
    # Проверка файрвола
    if command -v ufw >/dev/null 2>&1; then
        ufw_status=$(ufw status | head -1)
        if echo "$ufw_status" | grep -q "active"; then
            log "✅ UFW активен"
            echo "✅ UFW активен" >> "$CHECKLIST_FILE"
        else
            log "⚠️  UFW неактивен"
            echo "⚠️  UFW неактивен" >> "$CHECKLIST_FILE"
        fi
    fi
    
    # Проверка обновлений системы
    if command -v apt >/dev/null 2>&1; then
        updates=$(apt list --upgradable 2>/dev/null | wc -l)
        if [[ $updates -eq 0 ]]; then
            log "✅ Система обновлена"
            echo "✅ Система обновлена" >> "$CHECKLIST_FILE"
        else
            log "⚠️  Доступно обновлений: $updates"
            echo "⚠️  Доступно обновлений: $updates" >> "$CHECKLIST_FILE"
        fi
    fi
    
    # Проверка паролей
    if [[ -f ".env" ]]; then
        weak_passwords=$(grep -E "PASSWORD|SECRET|KEY" .env | grep -E "(123|password|secret|admin|test|your_)")
        if [[ -z "$weak_passwords" ]]; then
            log "✅ Слабые пароли не найдены"
            echo "✅ Слабые пароли не найдены" >> "$CHECKLIST_FILE"
        else
            log "⚠️  Найдены слабые пароли"
            echo "⚠️  Найдены слабые пароли" >> "$CHECKLIST_FILE"
        fi
    fi
}

# Функция проверки производительности
check_performance() {
    log "Проверка производительности..."
    
    # Проверка CPU
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    if (( $(echo "$cpu_usage < 80" | bc -l) )); then
        log "✅ CPU usage: ${cpu_usage}%"
        echo "✅ CPU usage: ${cpu_usage}%" >> "$CHECKLIST_FILE"
    else
        log "⚠️  CPU usage: ${cpu_usage}%"
        echo "⚠️  CPU usage: ${cpu_usage}%" >> "$CHECKLIST_FILE"
    fi
    
    # Проверка памяти
    memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ $memory_usage -lt 85 ]]; then
        log "✅ Memory usage: ${memory_usage}%"
        echo "✅ Memory usage: ${memory_usage}%" >> "$CHECKLIST_FILE"
    else
        log "⚠️  Memory usage: ${memory_usage}%"
        echo "⚠️  Memory usage: ${memory_usage}%" >> "$CHECKLIST_FILE"
    fi
    
    # Проверка диска
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 90 ]]; then
        log "✅ Disk usage: ${disk_usage}%"
        echo "✅ Disk usage: ${disk_usage}%" >> "$CHECKLIST_FILE"
    else
        log "⚠️  Disk usage: ${disk_usage}%"
        echo "⚠️  Disk usage: ${disk_usage}%" >> "$CHECKLIST_FILE"
    fi
}

# Функция проверки backup
check_backup() {
    log "Проверка backup..."
    
    # Проверка cron задач
    backup_cron=$(crontab -l 2>/dev/null | grep -i backup)
    if [[ -n "$backup_cron" ]]; then
        log "✅ Backup cron задачи настроены"
        echo "✅ Backup cron задачи настроены" >> "$CHECKLIST_FILE"
    else
        log "⚠️  Backup cron задачи не настроены"
        echo "⚠️  Backup cron задачи не настроены" >> "$CHECKLIST_FILE"
    fi
    
    # Проверка backup файлов
    backup_files=$(find /var/backups -name "*.sql" -o -name "*.tar.gz" 2>/dev/null | wc -l)
    if [[ $backup_files -gt 0 ]]; then
        log "✅ Backup файлы найдены: $backup_files"
        echo "✅ Backup файлы найдены ($backup_files)" >> "$CHECKLIST_FILE"
    else
        log "⚠️  Backup файлы не найдены"
        echo "⚠️  Backup файлы не найдены" >> "$CHECKLIST_FILE"
    fi
}

# Функция генерации отчета
generate_report() {
    {
        echo "=== Production Readiness Report ==="
        echo "Дата: $(date)"
        echo "Сервер: $(hostname)"
        echo "IP адрес: $(curl -s ifconfig.me)"
        echo ""
        
        echo "=== Чек-лист готовности к продакшену ==="
        cat "$CHECKLIST_FILE"
        echo ""
        
        echo "=== Рекомендации ==="
        echo "1. Убедитесь, что все сервисы работают стабильно"
        echo "2. Настройте мониторинг и алерты"
        echo "3. Проверьте безопасность системы"
        echo "4. Настройте автоматическое резервное копирование"
        echo "5. Протестируйте все функции"
        echo "6. Подготовьте команду к работе"
        echo ""
        
        echo "=== Следующие шаги ==="
        echo "1. Запуск рекламной кампании"
        echo "2. Мониторинг производительности"
        echo "3. Масштабирование по мере роста"
        echo "4. Регулярное обслуживание"
        
    } > "/tmp/production-readiness-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log "Отчет готовности к продакшену сохранен"
}

# Основная функция
main() {
    log "Начало проверки готовности к продакшену..."
    
    # Выполнение всех проверок
    check_status "Xray Manager" "$BASE_URL:8080"
    check_status "Telegram Bot" "$BASE_URL:8001"
    check_status "Payment Service" "$BASE_URL:8002"
    
    check_ssl_certificates
    check_database
    check_redis
    check_monitoring
    check_telegram_bot
    check_payment_systems
    check_security
    check_performance
    check_backup
    
    # Генерация отчета
    generate_report
    
    log "Проверка готовности к продакшену завершена"
    
    # Подсчет результатов
    total_checks=$(wc -l < "$CHECKLIST_FILE")
    passed_checks=$(grep -c "✅" "$CHECKLIST_FILE")
    warning_checks=$(grep -c "⚠️" "$CHECKLIST_FILE")
    failed_checks=$(grep -c "❌" "$CHECKLIST_FILE")
    
    log "Результаты:"
    log "✅ Пройдено: $passed_checks"
    log "⚠️  Предупреждения: $warning_checks"
    log "❌ Ошибки: $failed_checks"
    log "📊 Всего проверок: $total_checks"
    
    if [[ $failed_checks -eq 0 ]]; then
        log "🎉 Система готова к продакшену!"
    else
        log "⚠️  Требуется исправление ошибок перед запуском в продакшен"
    fi
}

# Запуск скрипта
main "$@"
