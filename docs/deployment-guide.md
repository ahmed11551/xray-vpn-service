# Инструкция по развертыванию Xray VLESS + Reality сервиса

## Предварительные требования

### Системные требования
- Ubuntu 20.04+ или CentOS 8+
- Минимум 2 CPU, 4GB RAM, 50GB SSD
- Root доступ к серверам
- Открытые порты: 80, 443, 8080, 5432, 6379

### Необходимые инструменты
- Docker и Docker Compose
- Git
- curl, wget
- jq (для работы с JSON)

## Быстрый старт

### 1. Подготовка серверов

```bash
# Обновление системы
apt update && apt upgrade -y

# Установка необходимых пакетов
apt install -y docker.io docker-compose git curl wget jq

# Запуск Docker
systemctl start docker
systemctl enable docker

# Добавление пользователя в группу docker
usermod -aG docker $USER
```

### 2. Клонирование проекта

```bash
# Клонирование репозитория
git clone <repository-url> /opt/xray-service
cd /opt/xray-service

# Создание необходимых директорий
mkdir -p {nginx/ssl,xray/ssl,postgres,monitoring/{grafana,prometheus}}
```

### 3. Настройка переменных окружения

```bash
# Создание файла .env
cat > .env << EOF
# Database
DB_PASSWORD=your_secure_password_here

# Telegram Bot
BOT_TOKEN=your_bot_token_here

# Payment Systems
YOOKASSA_SHOP_ID=your_shop_id
YOOKASSA_SECRET_KEY=your_secret_key

# Monitoring
GRAFANA_PASSWORD=your_grafana_password

# Telegram Notifications
TELEGRAM_BOT_TOKEN=your_monitoring_bot_token
TELEGRAM_CHAT_ID=your_chat_id
EOF
```

### 4. Генерация SSL сертификатов

```bash
# Генерация самоподписанных сертификатов (для тестирования)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/ssl/key.pem \
    -out nginx/ssl/cert.pem \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=XrayService/CN=localhost"

# Для продакшена используйте Let's Encrypt или коммерческие сертификаты
```

### 5. Настройка Xray конфигураций

```bash
# Генерация UUID для каждого сервера
for i in {1..3}; do
    echo "Server $i UUID: $(uuidgen)"
done

# Генерация Reality ключей
xray uuid
xray x25519

# Обновление конфигураций с реальными значениями
# Отредактируйте файлы xray/config*.json
```

### 6. Запуск сервисов

```bash
# Запуск всех сервисов
docker-compose up -d

# Проверка статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f
```

## Детальная настройка

### 1. Настройка базы данных

```sql
-- Подключение к PostgreSQL
docker exec -it xray-service_postgres_1 psql -U xray_user -d xray_service

-- Создание таблиц
\i postgres/init.sql

-- Проверка таблиц
\dt
```

### 2. Настройка мониторинга

```bash
# Доступ к Grafana
# URL: http://your-server:3000
# Логин: admin
# Пароль: из переменной GRAFANA_PASSWORD

# Доступ к Prometheus
# URL: http://your-server:9090

# Настройка дашбордов
cp monitoring/grafana/dashboards/*.json monitoring/grafana/dashboards/
```

### 3. Настройка Telegram Bot

```bash
# Создание бота через @BotFather
# Получение токена
# Настройка webhook

curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
    -d "url=https://your-domain.com/webhook/"
```

### 4. Настройка платежных систем

#### YooKassa
```bash
# Регистрация в YooKassa
# Получение Shop ID и Secret Key
# Настройка webhook URL: https://your-domain.com/payment/yookassa/webhook
```

#### Криптовалютные платежи
```bash
# Настройка кошельков
# Bitcoin: создание нового адреса
# Ethereum: настройка MetaMask
# USDT: настройка TRC20/ERC20
```

## Автоматизация

### 1. Настройка cron задач

```bash
# Добавление задач в crontab
crontab -e

# Обновление SNI каждые 6 часов
0 */6 * * * /opt/xray-service/scripts/update-sni.sh

# Мониторинг каждые 5 минут
*/5 * * * * /opt/xray-service/scripts/monitor-servers.sh

# Backup базы данных каждый день в 2:00
0 2 * * * /opt/xray-service/scripts/backup-database.sh
```

### 2. Настройка systemd сервисов

```bash
# Создание сервиса для автоматического запуска
cat > /etc/systemd/system/xray-service.service << EOF
[Unit]
Description=Xray VLESS + Reality Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/xray-service
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Активация сервиса
systemctl enable xray-service
systemctl start xray-service
```

## Масштабирование

### 1. Добавление новых серверов

```bash
# Копирование конфигурации на новый сервер
scp -r /opt/xray-service root@new-server:/opt/

# Настройка нового сервера
ssh root@new-server
cd /opt/xray-service
docker-compose up -d

# Обновление Load Balancer
# Добавление нового сервера в upstream
```

### 2. Горизонтальное масштабирование

```bash
# Добавление новых Xray серверов
docker-compose scale xray-server=5

# Обновление конфигурации Nginx
# Перезапуск Load Balancer
docker-compose restart nginx
```

## Безопасность

### 1. Настройка файрвола

```bash
# UFW (Ubuntu)
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw enable

# iptables (CentOS)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
iptables -P INPUT DROP
```

### 2. Настройка SSL/TLS

```bash
# Let's Encrypt сертификаты
apt install certbot
certbot certonly --standalone -d your-domain.com

# Обновление конфигурации Nginx
# Автоматическое обновление сертификатов
```

### 3. Backup стратегия

```bash
# Создание скрипта backup
cat > scripts/backup-database.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/xray"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup PostgreSQL
docker exec xray-service_postgres_1 pg_dump -U xray_user xray_service > $BACKUP_DIR/db_$DATE.sql

# Backup конфигураций
tar -czf $BACKUP_DIR/configs_$DATE.tar.gz xray/ nginx/

# Очистка старых backup'ов (старше 30 дней)
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
EOF

chmod +x scripts/backup-database.sh
```

## Мониторинг и алертинг

### 1. Настройка Grafana дашбордов

```bash
# Импорт готовых дашбордов
# Настройка алертов
# Интеграция с Telegram
```

### 2. Настройка Prometheus алертов

```bash
# Проверка правил алертинга
promtool check rules monitoring/rules/alerts.yml

# Перезапуск Prometheus
docker-compose restart prometheus
```

## Тестирование

### 1. Проверка работоспособности

```bash
# Проверка доступности сервисов
curl -I https://your-domain.com/health
curl -I https://your-domain.com/nginx_status

# Проверка Xray серверов
curl -I https://your-domain.com:443

# Проверка базы данных
docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -c "SELECT 1;"
```

### 2. Нагрузочное тестирование

```bash
# Установка Apache Bench
apt install apache2-utils

# Тестирование Load Balancer
ab -n 1000 -c 10 https://your-domain.com/

# Тестирование API
ab -n 500 -c 5 https://your-domain.com:8080/api/v1/configs/
```

## Устранение неполадок

### 1. Проверка логов

```bash
# Логи всех сервисов
docker-compose logs

# Логи конкретного сервиса
docker-compose logs xray-server-1
docker-compose logs telegram-bot

# Логи системы
journalctl -u docker
tail -f /var/log/xray/error.log
```

### 2. Частые проблемы

```bash
# Проблема с портами
netstat -tlnp | grep :443

# Проблема с Docker
systemctl status docker
docker system prune -f

# Проблема с сертификатами
openssl x509 -in nginx/ssl/cert.pem -text -noout
```

## Поддержка и обновления

### 1. Обновление сервисов

```bash
# Обновление Docker образов
docker-compose pull
docker-compose up -d

# Обновление Xray
# Скачивание новой версии
# Обновление конфигураций
```

### 2. Мониторинг производительности

```bash
# Проверка ресурсов
htop
df -h
free -h

# Проверка сетевых соединений
ss -tuln
netstat -an | grep :443 | wc -l
```

## Контакты и поддержка

- **Документация**: `/docs/`
- **Логи**: `/var/log/xray/`
- **Конфигурации**: `/opt/xray-service/`
- **Backup'ы**: `/var/backups/xray/`

При возникновении проблем проверьте логи и обратитесь к документации.
