# Xray VPN Service

🚀 **Полная инфраструктура для коммерческого сервиса продажи конфигураций защищённого сетевого доступа**

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/ahmed11551/xray-vpn-service)
[![GitHub](https://img.shields.io/github/license/ahmed11551/xray-vpn-service)](https://github.com/ahmed11551/xray-vpn-service/blob/main/LICENSE)

## ✨ Особенности

- 🔐 **Xray VLESS + Reality** - Современный протокол обхода блокировок
- 🤖 **Telegram Bot** - Удобное управление через мессенджер
- 💳 **Платежная система** - Интеграция с YooKassa, Robokassa, криптовалюты
- 📊 **Мониторинг** - Grafana + Prometheus для отслеживания работы
- 🐳 **Docker** - Простое развертывание и масштабирование
- 🔒 **Безопасность** - SNI маскировка и защита от DPI

## 🌐 Способы развертывания

### 🚀 Vercel (Рекомендуется)
[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/ahmed11551/xray-vpn-service)

### 🚂 Railway
[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/ahmed11551/xray-vpn-service)

### 🐳 Docker (Собственный сервер)
```bash
docker-compose up -d
```

### ☁️ Heroku
[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/ahmed11551/xray-vpn-service)

## 📁 Структура проекта

```
xray-service/
├── 📄 README.md                    # Основная документация
├── 🐳 docker-compose.yml          # Docker Compose конфигурация
├── 📁 docs/                       # Документация
│   ├── 📄 architecture.md         # Архитектура системы
│   ├── 📄 technical-proposal.md   # Техническое предложение
│   └── 📄 deployment-guide.md     # Инструкция по развертыванию
├── 📁 services/                   # Микросервисы
│   ├── 📁 xray-manager/           # Управление Xray конфигурациями
│   │   └── 📄 README.md
│   ├── 📁 telegram-bot/           # Telegram бот
│   │   └── 📄 README.md
│   ├── 📁 payment-service/         # Платежный сервис
│   └── 📁 user-service/           # Управление пользователями
├── 📁 infrastructure/             # Инфраструктурные компоненты
│   ├── 📁 nginx/                  # Load Balancer конфигурация
│   │   └── 📄 nginx.conf
│   ├── 📁 xray/                   # Xray серверы
│   │   ├── 📄 config1.json
│   │   ├── 📄 config2.json
│   │   └── 📄 config3.json
│   └── 📁 postgres/               # База данных
├── 📁 monitoring/                 # Мониторинг и алертинг
│   ├── 📄 prometheus.yml          # Prometheus конфигурация
│   └── 📁 rules/
│       └── 📄 alerts.yml          # Правила алертинга
└── 📁 scripts/                    # Скрипты автоматизации
    ├── 📄 update-sni.sh          # Обновление SNI конфигураций
    └── 📄 monitor-servers.sh      # Мониторинг серверов
```

## 🚀 Быстрый старт

### ⚠️ Важно: GitHub Pages не поддерживается!
Это серверное приложение требует базу данных и переменные окружения. Используйте Vercel, Railway или собственный сервер.

### 1. Клонирование проекта
```bash
# Клонирование проекта
git clone https://github.com/ahmed11551/xray-vpn-service.git
cd xray-vpn-service
```

### 2. Подготовка окружения
```bash
# Перемещение в рабочую директорию (для Linux сервера)
sudo mv xray-vpn-service /opt/xray-service
cd /opt/xray-service

# Установка зависимостей
sudo apt update && sudo apt install -y docker.io docker-compose git curl wget jq

# Запуск Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 2. Настройка конфигурации
```bash
# Копирование файла переменных окружения
cp env.example .env

# Редактирование конфигурации
nano .env
```

### 3. Генерация ключей и конфигураций
```bash
# Установка Xray (если не установлен)
wget -O xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip xray.zip
sudo mv xray /usr/local/bin/
sudo chmod +x /usr/local/bin/xray

# Генерация Reality ключей
python3 scripts/generate-reality-keys.py

# Инициализация базы данных
python3 scripts/init-database.py
```

### 4. Запуск сервисов
```bash
# Запуск всех сервисов
docker-compose up -d

# Проверка статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f
```

### 5. Проверка работоспособности
```bash
# Проверка health check'ов
curl -I https://your-domain.com/health
curl -I https://your-domain.com:8080/health
curl -I https://your-domain.com:8001/health
curl -I https://your-domain.com:8002/health

# Проверка API
curl -I https://your-domain.com:8080/api/v1/servers
curl -I https://your-domain.com:8002/api/v1/stats/payments
```

## 🔧 Основные компоненты

### Load Balancer (Nginx)
- Распределение нагрузки между Xray серверами
- SSL termination
- Rate limiting и защита от DDoS
- Health checks

### Xray Core Servers
- VLESS + Reality протоколы
- SNI маскировка для обхода блокировок мобильных операторов
- Маскировка под разрешенные домены (VK, Yandex, Sberbank, Mail.ru)
- Автоматическое обновление конфигураций при изменении правил операторов
- Мониторинг производительности и эффективности обхода

### Backend Services
- **Xray Manager**: управление конфигурациями
- **Telegram Bot**: пользовательский интерфейс
- **Payment Service**: обработка платежей
- **User Service**: управление пользователями

### Data Layer
- **PostgreSQL**: основная база данных
- **Redis**: кэширование и сессии
- **File Storage**: конфигурации и логи

### Monitoring Stack
- **Prometheus**: сбор метрик
- **Grafana**: визуализация
- **AlertManager**: уведомления
- **ELK Stack**: логирование

## 💰 Бизнес-модель

### Функциональность
- ✅ Автоматическая генерация конфигураций
- ✅ SNI маскировка для обхода блокировок мобильных операторов
- ✅ Бесплатный тест на 1 день
- ✅ Подписки (месяц/год)
- ✅ Лимиты по устройствам (1-3 на аккаунт)
- ✅ Реферальная программа (10% от продаж)
- ✅ Интеграция с платежными системами
- ✅ Автоматическое обновление SNI при изменении правил операторов

### Платежные системы
- YooKassa, Robokassa
- Криптовалютные платежи (BTC, ETH, USDT)
- Автоматическое управление подписками

## 📈 Масштабирование

### Планы роста
- **Старт**: 3 сервера, 100-1000 пользователей
- **Рост**: 10+ серверов, 10,000+ пользователей  
- **Масштаб**: 100+ серверов, 1M+ пользователей

### Автоматизация
- Автоматическое распределение пользователей
- Health checks и failover
- Автоматическое обновление SNI
- Мониторинг и алертинг

## 🔒 Безопасность

### Защита от атак
- DDoS защита (Cloudflare)
- Rate limiting
- Автоматическое блокирование подозрительного трафика

### Шифрование
- TLS для всех соединений
- Шифрование базы данных
- Безопасное хранение ключей

## 📊 Мониторинг

### Системные метрики
- CPU, Memory, Disk usage
- Сетевые соединения
- Статус сервисов

### Бизнес-метрики
- Количество пользователей
- Конверсия в покупки
- Эффективность реферальной программы

## 🛠️ Техническое задание

### Этап 1: Инфраструктура (1-2 недели)
1. Настройка серверов
2. Установка Xray-core
3. Настройка Load Balancer
4. Развертывание мониторинга

### Этап 2: Backend сервисы (2-3 недели)
1. Разработка Xray Manager
2. Создание Telegram Bot
3. Интеграция платежных систем
4. Настройка базы данных

### Этап 3: Автоматизация (1-2 недели)
1. Автоматическое обновление SNI
2. Скрипты мониторинга
3. CI/CD пайплайны
4. Backup стратегия

### Этап 4: Тестирование и запуск (1 неделя)
1. Нагрузочное тестирование
2. Безопасность и аудит
3. Документация
4. Обучение команды

## 💼 Условия сотрудничества

### Оплата за разработку
- **Начальная настройка**: 10,000 - 50,000 руб
- **Зависит от**: сложности, сроков, дополнительных требований

### Ongoing поддержка
- **Фиксированный оклад**: обсуждается индивидуально
- **Процент от продаж**: 15% от каждой продажи
- **Постоянные выплаты**: при продлении подписок клиентов
- **Периодичность**: ежемесячно или раз в две недели

## 📞 Контакты

Для подачи заявки пришлите:
1. Резюме с опытом работы с Xray/Reality
2. Примеры реализованных проектов
3. Предложение по архитектуре и технологиям
4. Ожидания по бюджету и срокам

**Готовы начать проект сразу после найма специалиста!**

---

## 📚 Дополнительная документация

- [Архитектура системы](docs/architecture.md)
- [Техническое предложение](docs/technical-proposal.md)
- [Инструкция по развертыванию](docs/deployment-guide.md)
- [Работа с мобильными операторами](docs/mobile-operators-sni.md)
- [Требования для специалиста](docs/mobile-operators-requirements.md)
- [Инструкция по найму](docs/hiring-guide.md)
- [Xray Manager](services/xray-manager/README.md)
- [Telegram Bot](services/telegram-bot/README.md)

## 🔗 Полезные ссылки

- [Xray-core документация](https://xtls.github.io/)
- [VLESS протокол](https://github.com/XTLS/Xray-core)
- [Reality протокол](https://github.com/XTLS/REALITY)
- [Docker Compose](https://docs.docker.com/compose/)
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)