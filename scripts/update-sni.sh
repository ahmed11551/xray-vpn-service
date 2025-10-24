#!/bin/bash

# Скрипт для автоматического обновления SNI конфигураций Xray

set -e

# Конфигурация
CONFIG_DIR="/etc/xray"
BACKUP_DIR="/var/backups/xray"
LOG_FILE="/var/log/xray/sni-update.log"
SERVERS=("xray-server-1" "xray-server-2" "xray-server-3")

# SNI домены для маскировки
SNI_DOMAINS=(
    "www.vk.com"
    "vk.com"
    "www.yandex.ru"
    "yandex.ru"
    "mail.ru"
    "www.mail.ru"
    "ok.ru"
    "www.ok.ru"
)

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Функция проверки доступности домена
check_domain() {
    local domain=$1
    local port=${2:-443}
    
    timeout 5 bash -c "</dev/tcp/$domain/$port" 2>/dev/null
    return $?
}

# Функция генерации нового SNI домена
get_best_sni_domain() {
    local best_domain=""
    local min_latency=999999
    
    for domain in "${SNI_DOMAINS[@]}"; do
        if check_domain "$domain"; then
            # Измеряем латентность
            local latency=$(ping -c 1 -W 1 "$domain" 2>/dev/null | grep "time=" | cut -d'=' -f2 | cut -d' ' -f1 | cut -d'.' -f1)
            
            if [[ -n "$latency" && "$latency" -lt "$min_latency" ]]; then
                min_latency=$latency
                best_domain="$domain"
            fi
        fi
    done
    
    echo "$best_domain"
}

# Функция обновления конфигурации сервера
update_server_config() {
    local server=$1
    local new_sni=$2
    
    log "Обновление конфигурации для $server с SNI: $new_sni"
    
    # Создаем резервную копию
    cp "$CONFIG_DIR/config.json" "$BACKUP_DIR/config-$(date +%Y%m%d-%H%M%S).json"
    
    # Обновляем конфигурацию
    jq --arg sni "$new_sni" '
        .inbounds[0].streamSettings.realitySettings.dest = ($sni + ":443") |
        .inbounds[0].streamSettings.realitySettings.serverNames = [$sni]
    ' "$CONFIG_DIR/config.json" > "$CONFIG_DIR/config-new.json"
    
    # Проверяем синтаксис
    if xray -test -config "$CONFIG_DIR/config-new.json"; then
        mv "$CONFIG_DIR/config-new.json" "$CONFIG_DIR/config.json"
        log "Конфигурация $server успешно обновлена"
        return 0
    else
        log "Ошибка в конфигурации $server"
        rm -f "$CONFIG_DIR/config-new.json"
        return 1
    fi
}

# Функция перезапуска сервиса
restart_service() {
    local server=$1
    
    log "Перезапуск сервиса $server"
    systemctl restart xray
    sleep 5
    
    if systemctl is-active --quiet xray; then
        log "Сервис $server успешно перезапущен"
        return 0
    else
        log "Ошибка перезапуска сервиса $server"
        return 1
    fi
}

# Функция проверки работоспособности
check_service_health() {
    local server=$1
    local port=${2:-443}
    
    # Проверяем доступность порта
    if ! check_domain "localhost" "$port"; then
        log "Сервис $server недоступен на порту $port"
        return 1
    fi
    
    # Проверяем логи на ошибки
    local error_count=$(tail -n 100 /var/log/xray/error.log | grep -c "ERROR" || true)
    if [[ "$error_count" -gt 10 ]]; then
        log "Обнаружено много ошибок в логах $server: $error_count"
        return 1
    fi
    
    return 0
}

# Основная функция
main() {
    log "Начало обновления SNI конфигураций"
    
    # Создаем директории если не существуют
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Получаем лучший SNI домен
    local best_sni=$(get_best_sni_domain)
    
    if [[ -z "$best_sni" ]]; then
        log "Не удалось найти доступный SNI домен"
        exit 1
    fi
    
    log "Выбран SNI домен: $best_sni"
    
    # Обновляем конфигурации для всех серверов
    local success_count=0
    for server in "${SERVERS[@]}"; do
        if update_server_config "$server" "$best_sni"; then
            if restart_service "$server"; then
                if check_service_health "$server"; then
                    log "Сервер $server успешно обновлен и работает"
                    ((success_count++))
                else
                    log "Проблемы с работоспособностью сервера $server"
                fi
            else
                log "Ошибка перезапуска сервера $server"
            fi
        else
            log "Ошибка обновления конфигурации сервера $server"
        fi
    done
    
    log "Обновление завершено. Успешно обновлено: $success_count из ${#SERVERS[@]} серверов"
    
    # Отправляем уведомление в Telegram (если настроено)
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="SNI обновление завершено. Обновлено: $success_count/${#SERVERS[@]} серверов. Новый SNI: $best_sni"
    fi
}

# Запуск скрипта
main "$@"
