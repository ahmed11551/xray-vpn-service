# Telegram Bot Service

Telegram бот для управления пользователями, генерации конфигураций и обработки платежей.

## Технологический стек

- **Python 3.11+** - основной язык
- **aiogram 3.x** - Telegram Bot API
- **FastAPI** - веб-сервер для webhook'ов
- **SQLAlchemy** - ORM для работы с БД
- **Redis** - кэширование и сессии
- **Pydantic** - валидация данных
- **Docker** - контейнеризация

## Структура проекта

```
services/telegram-bot/
├── app/
│   ├── __init__.py
│   ├── main.py                 # Точка входа FastAPI
│   ├── bot.py                  # Основной бот
│   ├── config.py              # Конфигурация
│   ├── database.py            # Подключение к БД
│   ├── handlers/              # Обработчики команд
│   │   ├── __init__.py
│   │   ├── start.py           # Команда /start
│   │   ├── profile.py         # Профиль пользователя
│   │   ├── configs.py         # Управление конфигурациями
│   │   ├── subscription.py    # Подписки
│   │   ├── referral.py        # Реферальная программа
│   │   └── support.py         # Поддержка
│   ├── keyboards/             # Клавиатуры
│   │   ├── __init__.py
│   │   ├── main.py           # Основная клавиатура
│   │   ├── subscription.py   # Клавиатура подписок
│   │   └── admin.py          # Админская клавиатура
│   ├── middlewares/           # Middleware
│   │   ├── __init__.py
│   │   ├── auth.py           # Аутентификация
│   │   ├── throttling.py     # Ограничение частоты
│   │   └── logging.py        # Логирование
│   ├── services/             # Бизнес-логика
│   │   ├── __init__.py
│   │   ├── user_service.py   # Управление пользователями
│   │   ├── config_service.py  # Управление конфигурациями
│   │   ├── payment_service.py # Платежи
│   │   └── referral_service.py # Реферальная программа
│   ├── models/               # SQLAlchemy модели
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── subscription.py
│   │   ├── payment.py
│   │   └── referral.py
│   ├── schemas/              # Pydantic схемы
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── subscription.py
│   │   └── payment.py
│   └── utils/                # Утилиты
│       ├── __init__.py
│       ├── validators.py
│       ├── formatters.py
│       └── helpers.py
├── migrations/               # Alembic миграции
├── tests/                   # Тесты
├── requirements.txt         # Python зависимости
├── Dockerfile             # Docker образ
└── README.md              # Документация
```

## Основные функции

### 1. Управление пользователями
- Регистрация новых пользователей
- Авторизация и аутентификация
- Управление профилем
- Лимиты по устройствам (1-3 на аккаунт)

### 2. Конфигурации
- Генерация VLESS + Reality конфигураций
- Бесплатный тест на 1 день
- Управление подписками
- Автоматическое обновление конфигураций

### 3. Платежи
- Интеграция с YooKassa, Robokassa
- Криптовалютные платежи
- Управление подписками
- История платежей

### 4. Реферальная программа
- Уникальные реферальные ссылки
- 10% от первой покупки
- 10% от каждого продления
- Вывод средств через техподдержку

## Команды бота

### Основные команды
- `/start` - Начало работы с ботом
- `/help` - Справка по командам
- `/profile` - Информация о профиле
- `/configs` - Мои конфигурации
- `/referral` - Реферальная программа

### Управление подписками
- `/subscribe` - Купить подписку
- `/extend` - Продлить подписку
- `/cancel` - Отменить подписку
- `/history` - История платежей

### Поддержка
- `/support` - Связаться с поддержкой
- `/feedback` - Оставить отзыв
- `/bug` - Сообщить об ошибке

## API Endpoints

### Webhook
- `POST /webhook/` - Telegram webhook

### Платежи
- `POST /payment/yookassa/webhook` - YooKassa webhook
- `POST /payment/robokassa/webhook` - Robokassa webhook
- `POST /payment/crypto/webhook` - Крипто webhook

### Админка
- `GET /admin/users` - Список пользователей
- `GET /admin/stats` - Статистика
- `POST /admin/broadcast` - Рассылка

## Конфигурация

```yaml
# config.yaml
bot:
  token: "your_bot_token"
  webhook_url: "https://your-domain.com/webhook/"
  webhook_secret: "your_webhook_secret"

database:
  url: "postgresql://user:password@localhost:5432/xray_service"

redis:
  url: "redis://localhost:6379"

payments:
  yookassa:
    shop_id: "your_shop_id"
    secret_key: "your_secret_key"
  robokassa:
    merchant_login: "your_merchant_login"
    password_1: "your_password_1"
    password_2: "your_password_2"
  crypto:
    bitcoin_wallet: "your_btc_address"
    ethereum_wallet: "your_eth_address"
    usdt_wallet: "your_usdt_address"

subscriptions:
  monthly_price: 200
  yearly_price: 2000
  currency: "RUB"
  free_trial_days: 1

referral:
  commission_percent: 10
  min_withdrawal: 1000

limits:
  max_devices_per_user: 3
  rate_limit_per_minute: 10
```

## Запуск

### Локальная разработка
```bash
cd services/telegram-bot
pip install -r requirements.txt
python -m app.bot
```

### Docker
```bash
docker build -t telegram-bot .
docker run -p 8001:8001 telegram-bot
```

### Docker Compose
```bash
docker-compose up telegram-bot
```

## Тестирование

```bash
# Запуск тестов
pytest tests/

# Тесты с покрытием
pytest --cov=app tests/

# Тесты бота
pytest tests/test_bot.py
```

## Мониторинг

### Метрики
- Количество активных пользователей
- Конверсия в покупки
- Средний чек
- Эффективность реферальной программы
- Статистика по устройствам

### Алерты
- Ошибки в работе бота
- Проблемы с платежами
- Подозрительная активность
- Превышение лимитов