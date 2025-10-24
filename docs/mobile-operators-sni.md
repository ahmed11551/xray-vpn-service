# Работа с мобильными операторами и SNI маскировка

## Проблема мобильных операторов

### Описание проблемы
Мобильные операторы (МТС, Мегафон, Билайн, Теле2) блокируют доступ к определенным сайтам через мобильный интернет, но оставляют доступ к "белому списку" сайтов:

**Разрешенные сайты:**
- vk.com, vk.ru
- yandex.ru, ya.ru
- sberbank.ru
- mail.ru
- ok.ru
- rambler.ru
- rutube.ru

**Заблокированные сайты:**
- youtube.com
- instagram.com
- facebook.com
- twitter.com
- telegram.org
- whatsapp.com

### Механизм блокировки
1. Оператор анализирует SNI (Server Name Indication) в TLS соединениях
2. Если SNI содержит заблокированный домен - соединение блокируется
3. Если SNI содержит разрешенный домен - соединение пропускается
4. Блокировка происходит на уровне оператора, не на уровне сайта

## Решение через Xray VLESS + Reality

### Принцип работы
1. **SNI маскировка** - прокси-сервер "притворяется" разрешенным сайтом
2. **Reality протокол** - маскирует трафик под обычный HTTPS
3. **VLESS** - эффективный протокол для обхода блокировок
4. **Автоматическое обновление** - когда оператор меняет правила

### Конфигурация SNI маскировки

```json
{
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "www.vk.com:443",
      "xver": 0,
      "serverNames": [
        "www.vk.com",
        "vk.com"
      ],
      "privateKey": "your-private-key",
      "shortIds": [
        "your-short-id"
      ]
    }
  }
}
```

### Автоматическое обновление SNI

```bash
#!/bin/bash
# Скрипт для автоматического обновления SNI конфигураций

# Список разрешенных доменов для маскировки
ALLOWED_DOMAINS=(
    "www.vk.com"
    "vk.com"
    "www.yandex.ru"
    "yandex.ru"
    "www.sberbank.ru"
    "sberbank.ru"
    "www.mail.ru"
    "mail.ru"
    "www.ok.ru"
    "ok.ru"
)

# Функция проверки доступности домена
check_domain() {
    local domain=$1
    timeout 5 bash -c "</dev/tcp/$domain/443" 2>/dev/null
    return $?
}

# Функция выбора лучшего домена для маскировки
get_best_sni_domain() {
    local best_domain=""
    local min_latency=999999
    
    for domain in "${ALLOWED_DOMAINS[@]}"; do
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

# Обновление конфигурации
update_config() {
    local new_sni=$1
    local config_file="/etc/xray/config.json"
    
    # Создаем резервную копию
    cp "$config_file" "$config_file.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Обновляем конфигурацию
    jq --arg sni "$new_sni" '
        .inbounds[0].streamSettings.realitySettings.dest = ($sni + ":443") |
        .inbounds[0].streamSettings.realitySettings.serverNames = [$sni]
    ' "$config_file" > "$config_file.new"
    
    # Проверяем синтаксис
    if xray -test -config "$config_file.new"; then
        mv "$config_file.new" "$config_file"
        systemctl restart xray
        echo "SNI обновлен на: $new_sni"
        return 0
    else
        echo "Ошибка в конфигурации"
        rm -f "$config_file.new"
        return 1
    fi
}

# Основная функция
main() {
    local best_sni=$(get_best_sni_domain)
    
    if [[ -n "$best_sni" ]]; then
        echo "Выбран SNI домен: $best_sni"
        update_config "$best_sni"
    else
        echo "Не удалось найти доступный SNI домен"
        exit 1
    fi
}

main "$@"
```

## Специфика работы с мобильными операторами

### Различия между операторами

#### МТС
- Блокирует: YouTube, Instagram, Facebook, Twitter
- Разрешает: VK, Yandex, Sberbank, Mail.ru
- Особенности: Агрессивная блокировка, быстро меняет правила

#### Мегафон
- Блокирует: YouTube, Instagram, Facebook, Twitter
- Разрешает: VK, Yandex, Sberbank, Mail.ru
- Особенности: Менее агрессивная блокировка

#### Билайн
- Блокирует: YouTube, Instagram, Facebook, Twitter
- Разрешает: VK, Yandex, Sberbank, Mail.ru
- Особенности: Блокировка по регионам

#### Теле2
- Блокирует: YouTube, Instagram, Facebook, Twitter
- Разрешает: VK, Yandex, Sberbank, Mail.ru
- Особенности: Наиболее агрессивная блокировка

### Методы обхода

#### 1. SNI маскировка
- Прокси-сервер "притворяется" разрешенным сайтом
- Оператор видит соединение с VK.com вместо YouTube.com
- Трафик пропускается без блокировки

#### 2. Reality протокол
- Маскирует прокси-трафик под обычный HTTPS
- Оператор не может отличить прокси от обычного сайта
- Высокая эффективность обхода

#### 3. Автоматическое обновление
- Когда оператор меняет правила блокировки
- Система автоматически переключается на другой SNI
- Обеспечивает стабильную работу

## Конфигурация для мобильных операторов

### Оптимальные настройки

```json
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.vk.com:443",
          "xver": 0,
          "serverNames": [
            "www.vk.com",
            "vk.com"
          ],
          "privateKey": "your-private-key",
          "shortIds": [
            "your-short-id"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
```

### Генерация ключей

```bash
# Генерация Reality ключей
xray x25519

# Результат:
# Private key: your-private-key
# Public key: your-public-key
# Short ID: your-short-id
```

## Мониторинг эффективности

### Метрики для отслеживания

```bash
# Скрипт мониторинга эффективности SNI
#!/bin/bash

# Проверка доступности заблокированных сайтов
check_blocked_sites() {
    local sites=("youtube.com" "instagram.com" "facebook.com")
    local accessible=0
    local total=${#sites[@]}
    
    for site in "${sites[@]}"; do
        if timeout 5 bash -c "</dev/tcp/$site/443" 2>/dev/null; then
            ((accessible++))
        fi
    done
    
    echo "Доступно $accessible из $total заблокированных сайтов"
}

# Проверка латентности разрешенных сайтов
check_allowed_sites() {
    local sites=("vk.com" "yandex.ru" "sberbank.ru")
    
    for site in "${sites[@]}"; do
        local latency=$(ping -c 1 -W 1 "$site" 2>/dev/null | grep "time=" | cut -d'=' -f2 | cut -d' ' -f1)
        echo "$site: ${latency}ms"
    done
}

# Основная функция
main() {
    echo "=== Проверка эффективности SNI маскировки ==="
    echo "Дата: $(date)"
    echo ""
    
    echo "Доступность заблокированных сайтов:"
    check_blocked_sites
    echo ""
    
    echo "Латентность разрешенных сайтов:"
    check_allowed_sites
}

main "$@"
```

## Автоматизация обновлений

### Cron задачи

```bash
# Добавление в crontab
crontab -e

# Обновление SNI каждые 6 часов
0 */6 * * * /opt/xray-service/scripts/update-sni.sh

# Проверка эффективности каждые 2 часа
0 */2 * * * /opt/xray-service/scripts/check-sni-effectiveness.sh

# Мониторинг блокировок каждые 30 минут
*/30 * * * * /opt/xray-service/scripts/monitor-blocking.sh
```

### Алерты при проблемах

```bash
# Скрипт отправки алертов
send_alert() {
    local message="$1"
    local telegram_token="$TELEGRAM_BOT_TOKEN"
    local chat_id="$TELEGRAM_CHAT_ID"
    
    curl -s -X POST "https://api.telegram.org/bot$telegram_token/sendMessage" \
        -d chat_id="$chat_id" \
        -d text="🚨 ALERT: $message"
}

# Проверка блокировок
check_blocking() {
    local blocked_count=$(check_blocked_sites | grep -o '[0-9]*' | head -1)
    
    if [[ "$blocked_count" -gt 0 ]]; then
        send_alert "Обнаружены блокировки! Доступно $blocked_count сайтов"
    fi
}
```

## Рекомендации для специалиста

### Обязательные навыки
- ✅ Понимание SNI маскировки
- ✅ Опыт работы с Reality протоколом
- ✅ Знание методов обхода блокировок операторов
- ✅ Опыт автоматизации обновлений
- ✅ Мониторинг эффективности

### Дополнительные навыки
- ✅ Анализ трафика операторов
- ✅ Понимание TLS/SSL протоколов
- ✅ Опыт работы с мобильными операторами
- ✅ Знание российского рынка

### Инструменты для работы
- ✅ Xray-core с Reality
- ✅ Скрипты автоматизации
- ✅ Мониторинг и алертинг
- ✅ Анализ эффективности
- ✅ Backup и восстановление

## Заключение

Работа с мобильными операторами требует:
1. **Понимания SNI маскировки** - ключевой навык
2. **Автоматизации обновлений** - операторы меняют правила
3. **Мониторинга эффективности** - отслеживание блокировок
4. **Быстрой реакции** - оперативное обновление конфигураций

Специалист должен иметь опыт работы именно с такими ограничениями и понимать специфику российских мобильных операторов.
