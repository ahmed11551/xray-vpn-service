#!/bin/bash

# Скрипт проверки безопасности Xray VLESS + Reality сервиса

set -e

# Конфигурация
BASE_URL="https://your-domain.com"
LOG_FILE="/var/log/security-audit.log"
REPORT_FILE="/tmp/security-audit-report-$(date +%Y%m%d-%H%M%S).txt"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Функция проверки SSL/TLS
check_ssl_security() {
    log "Проверка SSL/TLS безопасности..."
    
    local domains=("$BASE_URL" "$BASE_URL:8080" "$BASE_URL:8001" "$BASE_URL:8002")
    
    for domain in "${domains[@]}"; do
        log "Проверка SSL для $domain..."
        
        # Проверка сертификата
        cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain" 2>/dev/null | openssl x509 -noout -text)
        
        if echo "$cert_info" | grep -q "Subject:"; then
            log "✅ SSL сертификат найден для $domain"
            
            # Проверка срока действия
            expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain" 2>/dev/null | openssl x509 -noout -dates | grep "notAfter")
            log "📅 Срок действия сертификата: $expiry"
            
            # Проверка алгоритма подписи
            if echo "$cert_info" | grep -q "sha256"; then
                log "✅ Используется SHA-256"
            else
                log "⚠️  Рекомендуется SHA-256"
            fi
        else
            log "❌ SSL сертификат не найден для $domain"
        fi
    done
}

# Функция проверки файрвола
check_firewall() {
    log "Проверка настроек файрвола..."
    
    # Проверка UFW (Ubuntu)
    if command -v ufw >/dev/null 2>&1; then
        ufw_status=$(ufw status | head -1)
        log "📊 UFW статус: $ufw_status"
        
        if echo "$ufw_status" | grep -q "active"; then
            log "✅ UFW активен"
            
            # Проверка правил
            ufw_rules=$(ufw status numbered | grep -E "(80|443|8080|8000|8001|8002)")
            log "📋 Правила файрвола:"
            echo "$ufw_rules" | while read rule; do
                log "  $rule"
            done
        else
            log "⚠️  UFW неактивен - рекомендуется включить"
        fi
    fi
    
    # Проверка iptables
    if command -v iptables >/dev/null 2>&1; then
        iptables_rules=$(iptables -L -n | wc -l)
        log "📊 Количество правил iptables: $iptables_rules"
    fi
}

# Функция проверки открытых портов
check_open_ports() {
    log "Проверка открытых портов..."
    
    # Сканирование портов
    ports=$(nmap -sT -O localhost 2>/dev/null | grep -E "open|filtered" | awk '{print $1}' | cut -d'/' -f1)
    
    log "📋 Открытые порты:"
    for port in $ports; do
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            case $port in
                22) log "  $port - SSH" ;;
                80) log "  $port - HTTP" ;;
                443) log "  $port - HTTPS" ;;
                8080) log "  $port - API" ;;
                8000) log "  $port - Xray Manager" ;;
                8001) log "  $port - Telegram Bot" ;;
                8002) log "  $port - Payment Service" ;;
                5432) log "  $port - PostgreSQL" ;;
                6379) log "  $port - Redis" ;;
                3000) log "  $port - Grafana" ;;
                9090) log "  $port - Prometheus" ;;
                *) log "  $port - Неизвестный порт" ;;
            esac
        fi
    done
}

# Функция проверки Docker безопасности
check_docker_security() {
    log "Проверка безопасности Docker..."
    
    # Проверка запущенных контейнеров
    containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
    log "📋 Запущенные контейнеры:"
    echo "$containers" | while read line; do
        log "  $line"
    done
    
    # Проверка привилегированных контейнеров
    privileged_containers=$(docker ps --format "{{.Names}}" --filter "label=privileged=true")
    if [[ -n "$privileged_containers" ]]; then
        log "⚠️  Найдены привилегированные контейнеры: $privileged_containers"
    else
        log "✅ Привилегированные контейнеры не найдены"
    fi
    
    # Проверка root пользователей в контейнерах
    docker ps --format "{{.Names}}" | while read container; do
        user=$(docker exec "$container" whoami 2>/dev/null || echo "unknown")
        if [[ "$user" == "root" ]]; then
            log "⚠️  Контейнер $container запущен от root"
        else
            log "✅ Контейнер $container запущен от пользователя $user"
        fi
    done
}

# Функция проверки паролей и ключей
check_passwords_security() {
    log "Проверка безопасности паролей и ключей..."
    
    # Проверка файла .env
    if [[ -f ".env" ]]; then
        log "📋 Проверка файла .env..."
        
        # Проверка на слабые пароли
        weak_passwords=$(grep -E "PASSWORD|SECRET|KEY" .env | grep -E "(123|password|secret|admin|test)")
        if [[ -n "$weak_passwords" ]]; then
            log "⚠️  Найдены слабые пароли в .env:"
            echo "$weak_passwords" | while read line; do
                log "  $line"
            done
        else
            log "✅ Слабые пароли в .env не найдены"
        fi
        
        # Проверка на дефолтные значения
        default_values=$(grep -E "your_|default_|change_" .env)
        if [[ -n "$default_values" ]]; then
            log "⚠️  Найдены дефолтные значения в .env:"
            echo "$default_values" | while read line; do
                log "  $line"
            done
        else
            log "✅ Дефолтные значения в .env не найдены"
        fi
    else
        log "❌ Файл .env не найден"
    fi
    
    # Проверка SSH ключей
    if [[ -d "$HOME/.ssh" ]]; then
        ssh_keys=$(ls "$HOME/.ssh"/*.pub 2>/dev/null | wc -l)
        log "📊 Количество SSH ключей: $ssh_keys"
        
        if [[ $ssh_keys -gt 0 ]]; then
            log "✅ SSH ключи настроены"
        else
            log "⚠️  SSH ключи не найдены"
        fi
    fi
}

# Функция проверки логирования
check_logging_security() {
    log "Проверка безопасности логирования..."
    
    # Проверка логов на чувствительную информацию
    sensitive_logs=$(find /var/log -name "*.log" -exec grep -l -E "(password|secret|key|token)" {} \; 2>/dev/null | head -5)
    
    if [[ -n "$sensitive_logs" ]]; then
        log "⚠️  Найдены логи с чувствительной информацией:"
        echo "$sensitive_logs" | while read log_file; do
            log "  $log_file"
        done
    else
        log "✅ Чувствительная информация в логах не найдена"
    fi
    
    # Проверка размера логов
    log_size=$(du -sh /var/log 2>/dev/null | awk '{print $1}')
    log "📊 Размер логов: $log_size"
    
    # Проверка ротации логов
    if [[ -f "/etc/logrotate.conf" ]]; then
        log "✅ Logrotate настроен"
    else
        log "⚠️  Logrotate не настроен"
    fi
}

# Функция проверки обновлений системы
check_system_updates() {
    log "Проверка обновлений системы..."
    
    # Проверка обновлений пакетов
    if command -v apt >/dev/null 2>&1; then
        updates=$(apt list --upgradable 2>/dev/null | wc -l)
        log "📊 Доступно обновлений пакетов: $updates"
        
        if [[ $updates -gt 0 ]]; then
            log "⚠️  Рекомендуется обновить пакеты"
        else
            log "✅ Все пакеты обновлены"
        fi
    fi
    
    # Проверка версии ядра
    kernel_version=$(uname -r)
    log "📊 Версия ядра: $kernel_version"
    
    # Проверка последнего обновления системы
    last_update=$(stat -c %y /var/log/apt/history.log 2>/dev/null | cut -d' ' -f1)
    if [[ -n "$last_update" ]]; then
        log "📅 Последнее обновление системы: $last_update"
    fi
}

# Функция проверки резервного копирования
check_backup_security() {
    log "Проверка резервного копирования..."
    
    # Проверка cron задач для backup
    backup_cron=$(crontab -l 2>/dev/null | grep -i backup)
    if [[ -n "$backup_cron" ]]; then
        log "✅ Настроены cron задачи для backup:"
        echo "$backup_cron" | while read line; do
            log "  $line"
        done
    else
        log "⚠️  Cron задачи для backup не найдены"
    fi
    
    # Проверка существования backup файлов
    backup_files=$(find /var/backups -name "*.sql" -o -name "*.tar.gz" 2>/dev/null | wc -l)
    log "📊 Количество backup файлов: $backup_files"
    
    if [[ $backup_files -gt 0 ]]; then
        log "✅ Backup файлы найдены"
    else
        log "⚠️  Backup файлы не найдены"
    fi
}

# Функция проверки сетевой безопасности
check_network_security() {
    log "Проверка сетевой безопасности..."
    
    # Проверка активных соединений
    connections=$(netstat -an | grep ESTABLISHED | wc -l)
    log "📊 Активных соединений: $connections"
    
    # Проверка подозрительных соединений
    suspicious_connections=$(netstat -an | grep ESTABLISHED | grep -E "(23|135|139|445|1433|3389)" | wc -l)
    if [[ $suspicious_connections -gt 0 ]]; then
        log "⚠️  Найдены подозрительные соединения: $suspicious_connections"
    else
        log "✅ Подозрительные соединения не найдены"
    fi
    
    # Проверка DNS настроек
    dns_servers=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
    log "📊 DNS серверы: $dns_servers"
}

# Функция генерации отчета по безопасности
generate_security_report() {
    {
        echo "=== Security Audit Report ==="
        echo "Дата: $(date)"
        echo "Сервер: $(hostname)"
        echo "IP адрес: $(curl -s ifconfig.me)"
        echo ""
        
        echo "=== SSL/TLS Security ==="
        echo "Проверка сертификатов выполнена"
        echo ""
        
        echo "=== Firewall Status ==="
        ufw status 2>/dev/null || echo "UFW не установлен"
        echo ""
        
        echo "=== Open Ports ==="
        nmap -sT -O localhost 2>/dev/null | grep -E "open|filtered"
        echo ""
        
        echo "=== Docker Security ==="
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        
        echo "=== System Updates ==="
        apt list --upgradable 2>/dev/null | head -10
        echo ""
        
        echo "=== Network Security ==="
        netstat -an | grep ESTABLISHED | head -10
        echo ""
        
        echo "=== Recommendations ==="
        echo "1. Регулярно обновляйте систему и пакеты"
        echo "2. Используйте сильные пароли и ключи"
        echo "3. Настройте мониторинг безопасности"
        echo "4. Регулярно проверяйте логи"
        echo "5. Настройте автоматическое резервное копирование"
        
    } > "$REPORT_FILE"
    
    log "Отчет по безопасности сохранен в: $REPORT_FILE"
    echo "$REPORT_FILE"
}

# Основная функция
main() {
    log "Начало аудита безопасности..."
    
    # Выполнение всех проверок
    check_ssl_security
    check_firewall
    check_open_ports
    check_docker_security
    check_passwords_security
    check_logging_security
    check_system_updates
    check_backup_security
    check_network_security
    
    # Генерация отчета
    report_file=$(generate_security_report)
    
    log "Аудит безопасности завершен"
    log "Отчет: $report_file"
    
    # Отправка отчета в Telegram (если настроено)
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
            -F chat_id="$TELEGRAM_CHAT_ID" \
            -F document="@$report_file" \
            -F caption="🔒 Отчет по безопасности - $(date)"
    fi
}

# Запуск скрипта
main "$@"
