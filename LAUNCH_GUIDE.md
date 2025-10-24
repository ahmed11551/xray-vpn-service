# 🚀 ИНСТРУКЦИЯ ПО ЗАПУСКУ СЕРВИСА

## 🎯 **Быстрый старт (5 минут)**

### **1. Подготовка сервера**
```bash
# Обновите систему
sudo apt update && sudo apt upgrade -y

# Установите необходимые пакеты
sudo apt install -y git curl wget jq python3 python3-pip

# Скачайте проект
git clone <ваш-репозиторий> /opt/xray-service
cd /opt/xray-service
```

### **2. Запуск автоматической настройки**
```bash
# Сделайте скрипт исполняемым
chmod +x launch.sh

# Запустите главный скрипт
sudo ./launch.sh
```

### **3. Выберите "1. Быстрый запуск"**
Скрипт автоматически:
- ✅ Установит Docker и зависимости
- ✅ Настроит файрвол
- ✅ Создаст пользователя для сервиса
- ✅ Клонирует проект
- ✅ Настроит переменные окружения
- ✅ Сгенерирует Reality ключи
- ✅ Инициализирует базу данных
- ✅ Запустит все сервисы

## 🔧 **Пошаговая настройка**

### **Этап 1: Подготовка системы**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget jq python3 python3-pip postgresql-client redis-tools
```

### **Этап 2: Установка Docker**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo rm get-docker.sh

# Установка Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### **Этап 3: Настройка проекта**
```bash
cd /opt/xray-service
cp env.example .env
nano .env  # Отредактируйте файл с вашими настройками
```

### **Этап 4: Генерация ключей и запуск**
```bash
# Генерация Reality ключей
python3 scripts/generate-reality-keys.py

# Инициализация базы данных
python3 scripts/init-database.py

# Запуск сервисов
docker-compose up -d
```

## 💳 **Настройка платежных систем**

### **YooKassa**
1. Зарегистрируйтесь на https://yookassa.ru
2. Создайте магазин
3. Получите Shop ID и Secret Key
4. Запустите настройку:
```bash
chmod +x scripts/setup-payments.sh
./scripts/setup-payments.sh
```

### **Robokassa**
1. Зарегистрируйтесь на https://robokassa.ru
2. Создайте магазин
3. Получите Merchant Login и пароли
4. Настройте через скрипт

### **Криптовалюты**
1. Создайте кошельки для Bitcoin, Ethereum, USDT
2. Настройте через скрипт

## 🤖 **Настройка Telegram Bot**

### **Создание бота**
1. Найдите @BotFather в Telegram
2. Отправьте `/newbot`
3. Введите имя бота
4. Введите username бота
5. Скопируйте токен

### **Настройка через скрипт**
```bash
chmod +x scripts/setup-telegram-bot.sh
./scripts/setup-telegram-bot.sh
```

## 🧪 **Тестирование**

### **Быстрое тестирование**
```bash
chmod +x scripts/test-and-launch.sh
./scripts/test-and-launch.sh
```

### **Проверка статуса**
```bash
# Статус контейнеров
docker-compose ps

# Проверка health check'ов
curl http://localhost:8080/health  # Xray Manager
curl http://localhost:8001/health  # Telegram Bot
curl http://localhost:8002/health  # Payment Service
```

### **Тестирование Telegram Bot**
1. Найдите вашего бота в Telegram
2. Отправьте `/start`
3. Проверьте работу всех команд

## 📊 **Мониторинг**

### **Grafana**
- URL: `http://your-server:3000`
- Логин: `admin`
- Пароль: из переменной `GRAFANA_PASSWORD`

### **Prometheus**
- URL: `http://your-server:9090`
- Метрики доступны на `/metrics` endpoint

### **Логи**
```bash
# Просмотр логов всех сервисов
docker-compose logs -f

# Логи конкретного сервиса
docker-compose logs -f xray-manager
docker-compose logs -f telegram-bot
docker-compose logs -f payment-service
```

## 🔒 **Безопасность**

### **Проверка безопасности**
```bash
chmod +x scripts/security-audit.sh
./scripts/security-audit.sh
```

### **Настройка SSL**
1. Получите SSL сертификат (Let's Encrypt)
2. Обновите `WEBHOOK_URL` в `.env`
3. Перезапустите сервисы

### **Файрвол**
```bash
# Проверка статуса UFW
sudo ufw status

# Если не активен, включите
sudo ufw enable
```

## 🚨 **Устранение неполадок**

### **Сервисы не запускаются**
```bash
# Проверка логов
docker-compose logs

# Проверка конфигурации
docker-compose config

# Перезапуск
docker-compose down && docker-compose up -d
```

### **Проблемы с базой данных**
```bash
# Проверка подключения
docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -c "SELECT 1;"

# Пересоздание базы данных
docker-compose down
docker volume rm xray-service_postgres_data
python3 scripts/init-database.py
docker-compose up -d
```

### **Проблемы с Telegram Bot**
```bash
# Проверка webhook
curl "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo"

# Переустановка webhook
curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
    -d "url=https://your-domain.com/webhook/"
```

## 📋 **Полезные команды**

### **Управление сервисами**
```bash
# Запуск
docker-compose up -d

# Остановка
docker-compose down

# Перезапуск
docker-compose restart

# Обновление
docker-compose pull && docker-compose up -d
```

### **Мониторинг**
```bash
# Статус сервисов
docker-compose ps

# Использование ресурсов
docker stats

# Логи
docker-compose logs -f
```

### **Backup**
```bash
# Backup базы данных
docker exec xray-service_postgres_1 pg_dump -U xray_user xray_service > backup_$(date +%Y%m%d).sql

# Backup конфигураций
tar -czf configs_backup_$(date +%Y%m%d).tar.gz xray/ nginx/
```

## 🎉 **Готово!**

После выполнения всех шагов ваш сервис будет готов к работе:

1. ✅ **Все сервисы запущены**
2. ✅ **Telegram Bot настроен**
3. ✅ **Платежные системы подключены**
4. ✅ **Мониторинг работает**
5. ✅ **Безопасность настроена**

### **Следующие шаги:**
1. Протестируйте все функции
2. Запустите рекламную кампанию
3. Мониторьте производительность
4. Масштабируйте по мере роста

**Удачи в бизнесе!** 🚀💰
