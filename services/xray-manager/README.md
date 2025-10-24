# Xray Manager Service

Микросервис для управления Xray конфигурациями и автоматического обновления SNI.

## Технологический стек

- **Python 3.11+** - основной язык
- **FastAPI** - веб-фреймворк
- **SQLAlchemy** - ORM для работы с БД
- **Alembic** - миграции БД
- **Redis** - кэширование
- **Pydantic** - валидация данных
- **Docker** - контейнеризация

## Структура проекта

```
services/xray-manager/
├── app/
│   ├── __init__.py
│   ├── main.py                 # Точка входа FastAPI
│   ├── config.py              # Конфигурация
│   ├── database.py            # Подключение к БД
│   ├── models/                # SQLAlchemy модели
│   │   ├── __init__.py
│   │   ├── server.py
│   │   ├── config.py
│   │   └── user.py
│   ├── schemas/               # Pydantic схемы
│   │   ├── __init__.py
│   │   ├── server.py
│   │   ├── config.py
│   │   └── user.py
│   ├── api/                   # API endpoints
│   │   ├── __init__.py
│   │   ├── servers.py
│   │   ├── configs.py
│   │   └── sni.py
│   ├── services/              # Бизнес-логика
│   │   ├── __init__.py
│   │   ├── xray_service.py
│   │   ├── sni_service.py
│   │   └── config_service.py
│   └── utils/                 # Утилиты
│       ├── __init__.py
│       ├── crypto.py
│       └── validators.py
├── migrations/                # Alembic миграции
├── tests/                    # Тесты
├── requirements.txt           # Python зависимости
├── Dockerfile               # Docker образ
└── README.md                # Документация
```

## Основные функции

### 1. Управление серверами
- Добавление/удаление Xray серверов
- Мониторинг статуса серверов
- Автоматическое распределение нагрузки

### 2. Генерация конфигураций
- Создание VLESS + Reality конфигураций
- Автоматический выбор оптимального сервера
- Генерация уникальных UUID и ключей

### 3. SNI управление
- Автоматическое обновление SNI доменов
- Мониторинг доступности доменов
- Переключение между доменами

### 4. Мониторинг
- Сбор метрик производительности
- Отслеживание ошибок
- Алерты при проблемах

## API Endpoints

### Серверы
- `GET /api/v1/servers` - список серверов
- `POST /api/v1/servers` - добавление сервера
- `GET /api/v1/servers/{id}` - информация о сервере
- `PUT /api/v1/servers/{id}` - обновление сервера
- `DELETE /api/v1/servers/{id}` - удаление сервера

### Конфигурации
- `POST /api/v1/configs/generate` - генерация конфигурации
- `GET /api/v1/configs/{user_id}` - конфигурации пользователя
- `PUT /api/v1/configs/{id}` - обновление конфигурации
- `DELETE /api/v1/configs/{id}` - удаление конфигурации

### SNI управление
- `GET /api/v1/sni/domains` - доступные домены
- `POST /api/v1/sni/update` - обновление SNI
- `GET /api/v1/sni/status` - статус SNI

## Конфигурация

```yaml
# config.yaml
xray:
  servers:
    - id: "server-1"
      host: "xray1.example.com"
      port: 443
      uuid: "550e8400-e29b-41d4-a716-446655440000"
      reality_private_key: "your-private-key"
      reality_public_key: "your-public-key"
      reality_short_id: "your-short-id"
  
  sni:
    domains:
      - "vk.com"
      - "yandex.ru"
      - "sberbank.ru"
      - "mail.ru"
    update_interval: "6h"
    health_check_interval: "5m"
  
  monitoring:
    metrics_enabled: true
    log_level: "info"
    alert_thresholds:
      cpu_usage: 80
      memory_usage: 85
      connection_count: 1000
```

## Запуск

### Локальная разработка
```bash
cd services/xray-manager
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Docker
```bash
docker build -t xray-manager .
docker run -p 8000:8000 xray-manager
```

### Docker Compose
```bash
docker-compose up xray-manager
```

## Тестирование

```bash
# Запуск тестов
pytest tests/

# Тесты с покрытием
pytest --cov=app tests/

# Тесты производительности
pytest tests/performance/
```

## Мониторинг

### Метрики Prometheus
- `xray_server_status` - статус серверов
- `xray_configs_total` - количество конфигураций
- `xray_sni_domains_available` - доступные SNI домены
- `xray_server_connections` - активные соединения

### Health Checks
- `GET /health` - общий статус сервиса
- `GET /health/servers` - статус серверов
- `GET /health/database` - статус БД
- `GET /health/redis` - статус Redis