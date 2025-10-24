#!/bin/bash

# Скрипт мониторинга Xray серверов

set -e

# Конфигурация
LOG_FILE="/var/log/xray/monitoring.log"
ALERT_EMAIL="admin@example.com"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"

# Пороги для алертов
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
CONNECTION_THRESHOLD=1000
ERROR_THRESHOLD=50

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Функция отправки алерта в Telegram
send_telegram_alert() {
    local message="$1"
    
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="🚨 ALERT: $message" \
            -d parse_mode="HTML"
    fi
}

# Функция отправки email алерта
send_email_alert() {
    local subject="$1"
    local message="$2"
    
    echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
}

# Функция проверки CPU
check_cpu() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    local cpu_int=$(printf "%.0f" "$cpu_usage")
    
    if [[ "$cpu_int" -gt "$CPU_THRESHOLD" ]]; then
        local message="Высокая загрузка CPU: ${cpu_usage}% (порог: ${CPU_THRESHOLD}%)"
        log "ALERT: $message"
        send_telegram_alert "$message"
        return 1
    fi
    
    return 0
}

# Функция проверки памяти
check_memory() {
    local memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    
    if [[ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]]; then
        local message="Высокое использование памяти: ${memory_usage}% (порог: ${MEMORY_THRESHOLD}%)"
        log "ALERT: $message"
        send_telegram_alert "$message"
        return 1
    fi
    
    return 0
}

# Функция проверки диска
check_disk() {
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [[ "$disk_usage" -gt "$DISK_THRESHOLD" ]]; then
        local message="Высокое использование диска: ${disk_usage}% (порог: ${DISK_THRESHOLD}%)"
        log "ALERT: $message"
        send_telegram_alert "$message"
        return 1
    fi
    
    return 0
}

# Функция проверки соединений
check_connections() {
    local connections=$(netstat -an | grep :443 | wc -l)
    
    if [[ "$connections" -gt "$CONNECTION_THRESHOLD" ]]; then
        local message="Много активных соединений: $connections (порог: $CONNECTION_THRESHOLD)"
        log "ALERT: $message"
        send_telegram_alert "$message"
        return 1
    fi
    
    return 0
}

# Функция проверки ошибок в логах
check_errors() {
    local error_count=$(tail -n 1000 /var/log/xray/error.log | grep -c "ERROR" || true)
    
    if [[ "$error_count" -gt "$ERROR_THRESHOLD" ]]; then
        local message="Много ошибок в логах: $error_count за последние 1000 строк (порог: $ERROR_THRESHOLD)"
        log "ALERT: $message"
        send_telegram_alert "$message"
        return 1
    fi
    
    return 0
}

# Функция проверки статуса сервиса
check_service_status() {
    if ! systemctl is-active --quiet xray; then
        local message="Сервис Xray не работает!"
        log "ALERT: $message"
        send_telegram_alert "$message"
        
        # Попытка перезапуска
        log "Попытка перезапуска сервиса Xray"
        systemctl restart xray
        sleep 10
        
        if systemctl is-active --quiet xray; then
            log "Сервис Xray успешно перезапущен"
            send_telegram_alert "✅ Сервис Xray восстановлен после перезапуска"
        else
            log "Не удалось перезапустить сервис Xray"
            send_telegram_alert "❌ Критическая ошибка: не удалось восстановить сервис Xray"
        fi
        
        return 1
    fi
    
    return 0
}

# Функция проверки доступности портов
check_ports() {
    local ports=(443 80 8080)
    
    for port in "${ports[@]}"; do
        if ! timeout 5 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
            local message="Порт $port недоступен!"
            log "ALERT: $message"
            send_telegram_alert "$message"
            return 1
        fi
    done
    
    return 0
}

# Функция проверки DNS
check_dns() {
    local domains=("vk.com" "yandex.ru" "google.com")
    
    for domain in "${domains[@]}"; do
        if ! nslookup "$domain" >/dev/null 2>&1; then
            local message="Проблемы с DNS резолюцией для $domain"
            log "ALERT: $message"
            send_telegram_alert "$message"
            return 1
        fi
    done
    
    return 0
}

# Функция генерации отчета
generate_report() {
    local report_file="/tmp/xray-monitoring-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=== Xray Server Monitoring Report ==="
        echo "Дата: $(date)"
        echo "Сервер: $(hostname)"
        echo ""
        
        echo "=== Системные ресурсы ==="
        echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')"
        echo "Память: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
        echo "Диск: $(df -h / | tail -1 | awk '{print $5}')"
        echo ""
        
        echo "=== Сетевые соединения ==="
        echo "Активные соединения на порту 443: $(netstat -an | grep :443 | wc -l)"
        echo "Общие соединения: $(netstat -an | wc -l)"
        echo ""
        
        echo "=== Статус сервисов ==="
        echo "Xray: $(systemctl is-active xray)"
        echo "Nginx: $(systemctl is-active nginx)"
        echo ""
        
        echo "=== Последние ошибки ==="
        tail -n 20 /var/log/xray/error.log | grep "ERROR" || echo "Ошибок не найдено"
        
    } > "$report_file"
    
    echo "$report_file"
}

# Основная функция мониторинга
main() {
    log "Начало мониторинга Xray серверов"
    
    local alerts=0
    
    # Проверяем все компоненты
    check_service_status || ((alerts++))
    check_ports || ((alerts++))
    check_cpu || ((alerts++))
    check_memory || ((alerts++))
    check_disk || ((alerts++))
    check_connections || ((alerts++))
    check_errors || ((alerts++))
    check_dns || ((alerts++))
    
    # Генерируем отчет
    local report_file=$(generate_report)
    log "Отчет сохранен в: $report_file"
    
    # Отправляем сводку
    if [[ "$alerts" -eq 0 ]]; then
        log "Все проверки пройдены успешно"
    else
        log "Обнаружено $alerts проблем"
        send_telegram_alert "Обнаружено $alerts проблем при мониторинге сервера"
    fi
    
    # Очистка старых отчетов (старше 7 дней)
    find /tmp -name "xray-monitoring-report-*.txt" -mtime +7 -delete 2>/dev/null || true
}

# Запуск скрипта
main "$@"
