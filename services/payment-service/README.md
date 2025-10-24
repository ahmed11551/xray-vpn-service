# Payment Service

Микросервис для обработки платежей и управления подписками.

## Технологический стек

- **Python 3.11+** - основной язык
- **FastAPI** - веб-фреймворк
- **SQLAlchemy** - ORM для работы с БД
- **Redis** - кэширование
- **Pydantic** - валидация данных
- **Docker** - контейнеризация

## Структура проекта

```
services/payment-service/
├── app/
│   ├── __init__.py
│   ├── main.py                 # Точка входа FastAPI
│   ├── config.py              # Конфигурация
│   ├── database.py            # Подключение к БД
│   ├── models/                # SQLAlchemy модели
│   │   ├── __init__.py
│   │   ├── payment.py
│   │   ├── subscription.py
│   │   └── transaction.py
│   ├── schemas/               # Pydantic схемы
│   │   ├── __init__.py
│   │   ├── payment.py
│   │   ├── subscription.py
│   │   └── transaction.py
│   ├── api/                   # API endpoints
│   │   ├── __init__.py
│   │   ├── payments.py
│   │   ├── subscriptions.py
│   │   └── webhooks.py
│   ├── services/              # Бизнес-логика
│   │   ├── __init__.py
│   │   ├── yookassa_service.py
│   │   ├── robokassa_service.py
│   │   ├── crypto_service.py
│   │   └── subscription_service.py
│   └── utils/                 # Утилиты
│       ├── __init__.py
│       ├── validators.py
│       └── formatters.py
├── migrations/                # Alembic миграции
├── tests/                    # Тесты
├── requirements.txt           # Python зависимости
├── Dockerfile               # Docker образ
└── README.md                # Документация
```

## Основные функции

### 1. Платежные системы
- **YooKassa** - основная платежная система
- **Robokassa** - альтернативная платежная система
- **Криптовалюты** - Bitcoin, Ethereum, USDT
- **Webhook обработка** - автоматическое подтверждение платежей

### 2. Управление подписками
- Создание подписок
- Автоматическое продление
- Отмена подписок
- Уведомления об истечении

### 3. Реферальная программа
- Начисление комиссий
- Управление балансом
- Вывод средств
- История операций

### 4. Мониторинг
- Статистика платежей
- Отчеты по доходам
- Аналитика конверсии
- Алерты при проблемах

## API Endpoints

### Платежи
- `POST /api/v1/payments/create` - создание платежа
- `GET /api/v1/payments/{payment_id}` - информация о платеже
- `POST /api/v1/payments/{payment_id}/cancel` - отмена платежа
- `GET /api/v1/payments/user/{user_id}` - платежи пользователя

### Подписки
- `POST /api/v1/subscriptions/create` - создание подписки
- `GET /api/v1/subscriptions/{subscription_id}` - информация о подписке
- `PUT /api/v1/subscriptions/{subscription_id}` - обновление подписки
- `DELETE /api/v1/subscriptions/{subscription_id}` - отмена подписки

### Webhook'и
- `POST /webhook/yookassa` - YooKassa webhook
- `POST /webhook/robokassa` - Robokassa webhook
- `POST /webhook/crypto` - Крипто webhook

### Статистика
- `GET /api/v1/stats/payments` - статистика платежей
- `GET /api/v1/stats/subscriptions` - статистика подписок
- `GET /api/v1/stats/revenue` - статистика доходов

## Конфигурация

```yaml
# config.yaml
payments:
  yookassa:
    shop_id: "your_shop_id"
    secret_key: "your_secret_key"
    webhook_url: "https://your-domain.com/webhook/yookassa"
  
  robokassa:
    merchant_login: "your_merchant_login"
    password_1: "your_password_1"
    password_2: "your_password_2"
    webhook_url: "https://your-domain.com/webhook/robokassa"
  
  crypto:
    bitcoin_wallet: "your_btc_address"
    ethereum_wallet: "your_eth_address"
    usdt_wallet: "your_usdt_address"
    confirmation_blocks: 3

subscriptions:
  monthly_price: 200
  yearly_price: 2000
  currency: "RUB"
  auto_renewal: true
  grace_period_days: 3

referral:
  commission_percent: 10
  min_withdrawal: 1000
  withdrawal_fee: 50

notifications:
  telegram_enabled: true
  email_enabled: false
  webhook_enabled: true
```

## Запуск

### Локальная разработка
```bash
cd services/payment-service
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8002
```

### Docker
```bash
docker build -t payment-service .
docker run -p 8002:8002 payment-service
```

### Docker Compose
```bash
docker-compose up payment-service
```

## Тестирование

```bash
# Запуск тестов
pytest tests/

# Тесты с покрытием
pytest --cov=app tests/

# Тесты платежных систем
pytest tests/test_payments.py
```

## Мониторинг

### Метрики Prometheus
- `payments_total` - общее количество платежей
- `payments_successful` - успешные платежи
- `payments_failed` - неуспешные платежи
- `subscriptions_active` - активные подписки
- `revenue_total` - общий доход

### Health Checks
- `GET /health` - общий статус сервиса
- `GET /health/payments` - статус платежных систем
- `GET /health/database` - статус БД
- `GET /health/redis` - статус Redis
