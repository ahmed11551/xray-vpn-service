# Инструкция по развертыванию Xray VLESS + Reality сервиса

## 🎯 Что готово

Полная реализация коммерческого сервиса продажи конфигураций защищённого сетевого доступа на базе Xray с протоколами VLESS + Reality.

### ✅ Реализованные компоненты

#### 1. **Xray Manager Service** (Порт 8000)
- ✅ Управление Xray серверами
- ✅ Генерация VLESS + Reality конфигураций
- ✅ SNI маскировка для обхода блокировок мобильных операторов
- ✅ Автоматическое обновление конфигураций
- ✅ Мониторинг производительности серверов
- ✅ REST API для управления

#### 2. **Telegram Bot Service** (Порт 8001)
- ✅ Полнофункциональный Telegram бот
- ✅ Регистрация и управление пользователями
- ✅ Генерация конфигураций через бота
- ✅ Бесплатный тест на 1 день
- ✅ Лимиты по устройствам (1-3 на аккаунт)
- ✅ Интеграция с платежными системами
- ✅ Реферальная программа (10% от продаж)

#### 3. **Payment Service** (Порт 8002)
- ✅ Интеграция с YooKassa
- ✅ Интеграция с Robokassa
- ✅ Криптовалютные платежи (BTC, ETH, USDT)
- ✅ Автоматическое управление подписками
- ✅ Webhook обработка платежей
- ✅ Статистика и аналитика

#### 4. **Infrastructure**
- ✅ Docker Compose конфигурация
- ✅ PostgreSQL база данных
- ✅ Redis кэширование
- ✅ Nginx Load Balancer
- ✅ Prometheus + Grafana мониторинг
- ✅ ELK Stack логирование

#### 5. **Автоматизация**
- ✅ Скрипты обновления SNI конфигураций
- ✅ Мониторинг серверов
- ✅ Генерация Reality ключей
- ✅ Инициализация базы данных
- ✅ Backup стратегия

## 🚀 Развертывание

### Предварительные требования
- Ubuntu 20.04+ или CentOS 8+
- Docker и Docker Compose
- Минимум 4GB RAM, 2 CPU, 50GB SSD
- Открытые порты: 80, 443, 8080, 8000, 8001, 8002, 5432, 6379

### Пошаговое развертывание

#### 1. Подготовка сервера
```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Установка Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Установка дополнительных пакетов
sudo apt install -y git curl wget jq python3 python3-pip
```

#### 2. Клонирование проекта
```bash
# Клонирование репозитория
git clone <repository-url> /opt/xray-service
cd /opt/xray-service

# Установка прав доступа
sudo chown -R $USER:$USER /opt/xray-service
```

#### 3. Настройка конфигурации
```bash
# Копирование файла переменных окружения
cp env.example .env

# Редактирование конфигурации
nano .env
```

**Обязательные параметры для настройки:**
```bash
# Telegram Bot
BOT_TOKEN=your_bot_token_here
WEBHOOK_URL=https://your-domain.com
WEBHOOK_SECRET=your_webhook_secret

# База данных
DB_PASSWORD=your_secure_password_here

# Платежные системы
YOOKASSA_SHOP_ID=your_shop_id
YOOKASSA_SECRET_KEY=your_secret_key
YOOKASSA_WEBHOOK_SECRET=your_webhook_secret

ROBOKASSA_MERCHANT_LOGIN=your_merchant_login
ROBOKASSA_PASSWORD_1=your_password_1
ROBOKASSA_PASSWORD_2=your_password_2

# Криптовалютные кошельки
BITCOIN_WALLET_ADDRESS=your_btc_address
ETHEREUM_WALLET_ADDRESS=your_eth_address
USDT_TRC20_WALLET_ADDRESS=your_usdt_address

# Мониторинг
GRAFANA_PASSWORD=your_grafana_password
TELEGRAM_BOT_TOKEN=your_monitoring_bot_token
TELEGRAM_CHAT_ID=your_chat_id
```

#### 4. Установка Xray
```bash
# Скачивание Xray
wget -O xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip xray.zip
sudo mv xray /usr/local/bin/
sudo chmod +x /usr/local/bin/xray

# Проверка установки
xray --version
```

#### 5. Генерация ключей и конфигураций
```bash
# Генерация Reality ключей
python3 scripts/generate-reality-keys.py

# Инициализация базы данных
python3 scripts/init-database.py
```

#### 6. Настройка SSL сертификатов
```bash
# Установка Certbot
sudo apt install certbot

# Получение сертификатов
sudo certbot certonly --standalone -d your-domain.com

# Копирование сертификатов
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem nginx/ssl/key.pem
sudo chown $USER:$USER nginx/ssl/*
```

#### 7. Запуск сервисов
```bash
# Запуск всех сервисов
docker-compose up -d

# Проверка статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f
```

#### 8. Настройка Telegram Bot
```bash
# Установка webhook
curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
    -d "url=https://your-domain.com/webhook/"
```

#### 9. Настройка платежных систем

**YooKassa:**
- Зарегистрируйтесь в YooKassa
- Получите Shop ID и Secret Key
- Настройте webhook URL: `https://your-domain.com/webhook/yookassa`

**Robokassa:**
- Зарегистрируйтесь в Robokassa
- Получите Merchant Login и пароли
- Настройте webhook URL: `https://your-domain.com/webhook/robokassa`

#### 10. Проверка работоспособности
```bash
# Проверка health check'ов
curl -I https://your-domain.com/health
curl -I https://your-domain.com:8080/health
curl -I https://your-domain.com:8001/health
curl -I https://your-domain.com:8002/health

# Проверка API
curl -I https://your-domain.com:8080/api/v1/servers
curl -I https://your-domain.com:8002/api/v1/stats/payments

# Проверка мониторинга
curl -I https://your-domain.com:3000  # Grafana
curl -I https://your-domain.com:9090  # Prometheus
```

## 🔧 Настройка мониторинга

### Grafana дашборды
- URL: `https://your-domain.com:3000`
- Логин: `admin`
- Пароль: из переменной `GRAFANA_PASSWORD`

### Prometheus метрики
- URL: `https://your-domain.com:9090`
- Метрики доступны на `/metrics` endpoint каждого сервиса

### Алерты
- Настроены алерты в Telegram
- Мониторинг CPU, памяти, диска
- Отслеживание ошибок и недоступности сервисов

## 📊 Управление сервисом

### Основные команды
```bash
# Перезапуск сервисов
docker-compose restart

# Обновление сервисов
docker-compose pull
docker-compose up -d

# Просмотр логов
docker-compose logs -f [service_name]

# Остановка сервисов
docker-compose down

# Очистка данных
docker-compose down -v
```

### Мониторинг
```bash
# Проверка статуса серверов
curl https://your-domain.com:8080/api/v1/servers

# Статистика платежей
curl https://your-domain.com:8002/api/v1/stats/payments

# Статистика подписок
curl https://your-domain.com:8002/api/v1/stats/subscriptions
```

### Backup
```bash
# Backup базы данных
docker exec xray-service_postgres_1 pg_dump -U xray_user xray_service > backup_$(date +%Y%m%d).sql

# Backup конфигураций
tar -czf configs_backup_$(date +%Y%m%d).tar.gz xray/ nginx/
```

## 🚨 Устранение неполадок

### Частые проблемы

#### 1. Сервисы не запускаются
```bash
# Проверка логов
docker-compose logs

# Проверка конфигурации
docker-compose config

# Перезапуск
docker-compose down && docker-compose up -d
```

#### 2. Проблемы с базой данных
```bash
# Проверка подключения
docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -c "SELECT 1;"

# Пересоздание базы данных
docker-compose down
docker volume rm xray-service_postgres_data
python3 scripts/init-database.py
docker-compose up -d
```

#### 3. Проблемы с Telegram Bot
```bash
# Проверка webhook
curl "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo"

# Переустановка webhook
curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
    -d "url=https://your-domain.com/webhook/"
```

#### 4. Проблемы с платежами
```bash
# Проверка статуса платежных систем
curl https://your-domain.com:8002/health

# Проверка webhook'ов
curl -X POST https://your-domain.com/webhook/yookassa \
    -H "Content-Type: application/json" \
    -d '{"test": "data"}'
```

## 📈 Масштабирование

### Горизонтальное масштабирование
```bash
# Добавление новых Xray серверов
docker-compose scale xray-server=5

# Обновление Load Balancer
docker-compose restart nginx
```

### Вертикальное масштабирование
```bash
# Увеличение ресурсов в docker-compose.yml
services:
  xray-manager:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
```

## 🔒 Безопасность

### Настройка файрвола
```bash
# UFW (Ubuntu)
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 8001/tcp
sudo ufw allow 8002/tcp
sudo ufw enable
```

### Обновление сертификатов
```bash
# Автоматическое обновление
sudo crontab -e
# Добавить: 0 2 * * * certbot renew --quiet && docker-compose restart nginx
```

## 📞 Поддержка

### Логи и диагностика
- Логи сервисов: `docker-compose logs [service_name]`
- Логи системы: `journalctl -u docker`
- Логи Nginx: `docker-compose logs nginx`

### Контакты
- Документация: `/docs/`
- Техническая поддержка: через Telegram Bot
- Мониторинг: Grafana дашборды

---

## 🎉 Готово к использованию!

Ваш коммерческий сервис Xray VLESS + Reality полностью развернут и готов к работе!

**Основные URL:**
- Главная страница: `https://your-domain.com`
- API Xray Manager: `https://your-domain.com:8080`
- Telegram Bot: `@your_bot_username`
- API Payment Service: `https://your-domain.com:8002`
- Мониторинг Grafana: `https://your-domain.com:3000`
- Метрики Prometheus: `https://your-domain.com:9090`

**Следующие шаги:**
1. Протестируйте все функции
2. Настройте уведомления в Telegram
3. Запустите рекламную кампанию
4. Мониторьте производительность
5. Масштабируйте по мере роста нагрузки
