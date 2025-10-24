# Финальная документация Xray VLESS + Reality сервиса

## 🎯 Обзор проекта

Коммерческий сервис продажи конфигураций защищённого сетевого доступа на базе Xray с протоколами VLESS + Reality для мобильных пользователей.

### Ключевые особенности
- ✅ **SNI маскировка** - автоматическое обновление для обхода блокировок мобильных операторов
- ✅ **Масштабируемость** - архитектура рассчитана на рост до 1M+ пользователей
- ✅ **Автоматизация** - скрипты для обновления конфигураций и мониторинга
- ✅ **Коммерческая модель** - реферальная программа и интеграция платежей
- ✅ **Мониторинг** - полный стек мониторинга с алертами

## 🏗️ Архитектура системы

### Компоненты инфраструктуры
1. **Load Balancer** (Nginx) - распределение нагрузки между серверами
2. **Xray Core Servers** (3+ серверов) - основные прокси с VLESS + Reality
3. **Database Cluster** (PostgreSQL) - основная база данных
4. **Cache Layer** (Redis) - кэширование и сессии
5. **Backend Services** - микросервисная архитектура
6. **Monitoring Stack** - Prometheus + Grafana + алертинг
7. **Payment Gateway** - интеграция платежных систем

### Микросервисы
- **Xray Manager** (Порт 8000) - управление конфигурациями
- **Telegram Bot** (Порт 8001) - пользовательский интерфейс
- **Payment Service** (Порт 8002) - обработка платежей
- **User Service** - управление пользователями
- **Referral System** - реферальная программа

## 🔧 Технические детали

### Технологический стек
- **Backend**: Python 3.11+, FastAPI, SQLAlchemy
- **Database**: PostgreSQL 15, Redis 7
- **Proxy**: Xray-core с VLESS + Reality
- **Bot**: aiogram 3.x для Telegram
- **Payments**: YooKassa, Robokassa, криптовалюты
- **Monitoring**: Prometheus, Grafana, ELK Stack
- **Infrastructure**: Docker, Docker Compose, Nginx

### SNI маскировка
Система автоматически маскирует трафик под разрешенные домены:
- VK.com, Yandex.ru, Sberbank.ru, Mail.ru
- Автоматическое обновление при изменении правил операторов
- Мониторинг эффективности маскировки

### Платежные системы
- **YooKassa** - основная платежная система
- **Robokassa** - альтернативная система
- **Криптовалюты** - Bitcoin, Ethereum, USDT
- **Webhook обработка** - автоматическое подтверждение

## 📊 API Документация

### Xray Manager API (Порт 8000)

#### Серверы
- `GET /api/v1/servers` - список серверов
- `POST /api/v1/servers` - добавление сервера
- `GET /api/v1/servers/{id}` - информация о сервере
- `PUT /api/v1/servers/{id}` - обновление сервера
- `DELETE /api/v1/servers/{id}` - удаление сервера

#### Конфигурации
- `POST /api/v1/configs/generate` - генерация конфигурации
- `GET /api/v1/configs/{user_id}` - конфигурации пользователя
- `PUT /api/v1/configs/{id}` - обновление конфигурации
- `DELETE /api/v1/configs/{id}` - удаление конфигурации

#### SNI управление
- `GET /api/v1/sni/domains` - доступные домены
- `POST /api/v1/sni/update` - обновление SNI
- `GET /api/v1/sni/status` - статус SNI

### Payment Service API (Порт 8002)

#### Платежи
- `POST /api/v1/payments/create` - создание платежа
- `GET /api/v1/payments/{payment_id}` - информация о платеже
- `POST /api/v1/payments/{payment_id}/cancel` - отмена платежа
- `GET /api/v1/payments/user/{user_id}` - платежи пользователя

#### Подписки
- `POST /api/v1/subscriptions/create` - создание подписки
- `GET /api/v1/subscriptions/{subscription_id}` - информация о подписке
- `PUT /api/v1/subscriptions/{subscription_id}` - обновление подписки
- `DELETE /api/v1/subscriptions/{subscription_id}` - отмена подписки

#### Webhook'и
- `POST /webhook/yookassa` - YooKassa webhook
- `POST /webhook/robokassa` - Robokassa webhook
- `POST /webhook/crypto` - Крипто webhook

#### Статистика
- `GET /api/v1/stats/payments` - статистика платежей
- `GET /api/v1/stats/subscriptions` - статистика подписок
- `GET /api/v1/stats/revenue` - статистика доходов

### Telegram Bot API (Порт 8001)

#### Webhook
- `POST /webhook/` - Telegram webhook

#### Платежи
- `POST /payment/yookassa/webhook` - YooKassa webhook
- `POST /payment/robokassa/webhook` - Robokassa webhook
- `POST /payment/crypto/webhook` - Крипто webhook

#### Админка
- `GET /admin/users` - список пользователей
- `GET /admin/stats` - статистика
- `POST /admin/broadcast` - рассылка

## 🚀 Развертывание

### Быстрый старт
```bash
# 1. Клонирование проекта
git clone <repository-url> /opt/xray-service
cd /opt/xray-service

# 2. Настройка конфигурации
cp env.example .env
nano .env

# 3. Генерация ключей
python3 scripts/generate-reality-keys.py

# 4. Инициализация БД
python3 scripts/init-database.py

# 5. Запуск сервисов
docker-compose up -d

# 6. Проверка статуса
docker-compose ps
```

### Подробная инструкция
См. [DEPLOYMENT.md](DEPLOYMENT.md) для полной инструкции по развертыванию.

## 📈 Мониторинг

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

## 🔒 Безопасность

### Реализованные меры
- SSL/TLS шифрование для всех соединений
- Rate limiting для защиты от DDoS
- Валидация всех входных данных
- Безопасное хранение паролей и ключей
- Логирование всех операций
- Регулярные проверки безопасности

### Рекомендации
- Регулярно обновляйте систему и пакеты
- Используйте сильные пароли и ключи
- Настройте мониторинг безопасности
- Регулярно проверяйте логи
- Настройте автоматическое резервное копирование

## 🧪 Тестирование

### Нагрузочное тестирование
```bash
# Запуск нагрузочного тестирования
chmod +x scripts/load-testing.sh
./scripts/load-testing.sh
```

### Проверка безопасности
```bash
# Запуск аудита безопасности
chmod +x scripts/security-audit.sh
./scripts/security-audit.sh
```

### Unit тесты
```bash
# Тесты для каждого сервиса
cd services/xray-manager && pytest tests/
cd services/telegram-bot && pytest tests/
cd services/payment-service && pytest tests/
```

## 📊 Масштабирование

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

## 🔧 Обслуживание

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
```

### Backup
```bash
# Backup базы данных
docker exec xray-service_postgres_1 pg_dump -U xray_user xray_service > backup_$(date +%Y%m%d).sql

# Backup конфигураций
tar -czf configs_backup_$(date +%Y%m%d).tar.gz xray/ nginx/
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

## 📞 Поддержка

### Контакты
- Документация: `/docs/`
- Техническая поддержка: через Telegram Bot
- Мониторинг: Grafana дашборды

### Логи и диагностика
- Логи сервисов: `docker-compose logs [service_name]`
- Логи системы: `journalctl -u docker`
- Логи Nginx: `docker-compose logs nginx`

## 🎉 Заключение

Проект полностью реализован и готов к коммерческому использованию. Все компоненты протестированы, документированы и готовы к развертыванию.

### Ключевые достижения
- ✅ Полная реализация всех требований ТЗ
- ✅ Масштабируемая архитектура
- ✅ Автоматизация всех процессов
- ✅ Комплексный мониторинг
- ✅ Высокий уровень безопасности
- ✅ Готовность к продакшену

### Следующие шаги
1. Развертывание на продакшн серверах
2. Настройка мониторинга и алертов
3. Запуск рекламной кампании
4. Масштабирование по мере роста нагрузки

**Проект готов к запуску!** 🚀
