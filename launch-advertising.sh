#!/bin/bash

# Скрипт запуска рекламной кампании

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Создание Telegram канала
create_telegram_channel() {
    log "Создание Telegram канала..."
    
    echo "Для создания Telegram канала выполните следующие шаги:"
    echo ""
    echo "1. Откройте Telegram и нажмите 'Создать канал'"
    echo "2. Введите название: 'Xray VPN Service'"
    echo "3. Введите описание:"
    echo "   '🚀 Полный доступ к YouTube, Instagram, Facebook"
    echo "   🔹 Работает через мобильный интернет"
    echo "   🔹 Автоматическое обновление конфигураций"
    echo "   🔹 Бесплатный тест на 1 день"
    echo "   🔹 Реферальная программа'"
    echo "4. Добавьте логотип (опционально)"
    echo "5. Сделайте канал публичным"
    echo "6. Скопируйте ссылку на канал"
    echo ""
    
    read -p "Введите ссылку на канал: " CHANNEL_URL
    
    if [[ -n "$CHANNEL_URL" ]]; then
        log "✅ Канал создан: $CHANNEL_URL"
        
        # Добавление бота в канал как администратора
        BOT_TOKEN=$(grep "BOT_TOKEN" /opt/xray-service/.env | cut -d= -f2)
        bot_username=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe" | jq -r '.result.username')
        
        info "Добавьте бота @$bot_username в канал как администратора"
        info "Предоставьте права на отправку сообщений"
    else
        warn "Ссылка на канал не указана"
    fi
}

# Настройка реферальной программы
setup_referral_program() {
    log "Настройка реферальной программы..."
    
    echo "Реферальная программа настроена автоматически:"
    echo ""
    echo "✅ Каждый пользователь получает уникальную реферальную ссылку"
    echo "✅ 10% от первой покупки реферала"
    echo "✅ 10% от каждого продления подписки реферала"
    echo "✅ Бонусы начисляются на баланс пользователя"
    echo "✅ Можно использовать для продления подписки или вывести"
    echo ""
    
    info "Реферальная программа готова к работе!"
}

# Создание рекламных материалов
create_ad_materials() {
    log "Создание рекламных материалов..."
    
    # Создание директории для материалов
    mkdir -p /opt/xray-service/ad-materials
    
    # Создание текста для рекламы
    cat > /opt/xray-service/ad-materials/ad-text.txt << 'EOF'
🚀 Xray VLESS + Reality Service

🔹 Полный доступ к YouTube, Instagram, Facebook
🔹 Работает через мобильный интернет (МТС, Мегафон, Билайн, Теле2)
🔹 Автоматическое обновление конфигураций
🔹 Бесплатный тест на 1 день
🔹 Реферальная программа (10% от каждой продажи)

💰 Цены:
• Месяц: 200₽
• Год: 2000₽ (скидка 17%)

💳 Способы оплаты:
• YooKassa (карты, СБП, электронные кошельки)
• Robokassa (карты, СБП, электронные кошельки)
• Криптовалюты (Bitcoin, Ethereum, USDT)

🎁 Реферальная программа:
• Приводите друзей и получайте 10% от их покупок
• Бонусы можно использовать для продления или вывести

📱 Начать: @your_bot_username
EOF
    
    # Создание текста для постов
    cat > /opt/xray-service/ad-materials/post-text.txt << 'EOF'
🔥 НОВИНКА! Xray VLESS + Reality Service

Теперь YouTube, Instagram и Facebook доступны через мобильный интернет!

✅ Работает на всех операторах (МТС, Мегафон, Билайн, Теле2)
✅ Автоматическое обновление конфигураций
✅ Стабильное соединение
✅ Быстрая скорость

🎁 БЕСПЛАТНЫЙ ТЕСТ НА 1 ДЕНЬ!

💰 Всего 200₽ в месяц за полный доступ ко всем сайтам

📱 Переходите к боту: @your_bot_username
EOF
    
    # Создание текста для историй
    cat > /opt/xray-service/ad-materials/story-text.txt << 'EOF'
🚀 Xray VPN Service

Полный доступ к YouTube, Instagram, Facebook через мобильный интернет!

🔹 Работает на всех операторах
🔹 Автоматическое обновление
🔹 Стабильное соединение

🎁 Бесплатный тест на 1 день!

@your_bot_username
EOF
    
    log "Рекламные материалы созданы в /opt/xray-service/ad-materials/"
    
    info "Созданные материалы:"
    info "• ad-text.txt - основной рекламный текст"
    info "• post-text.txt - текст для постов"
    info "• story-text.txt - текст для историй"
}

# Настройка мониторинга рекламы
setup_ad_monitoring() {
    log "Настройка мониторинга рекламы..."
    
    # Создание скрипта для отслеживания статистики
    cat > /opt/xray-service/scripts/monitor-advertising.sh << 'EOF'
#!/bin/bash

# Скрипт мониторинга рекламной кампании

LOG_FILE="/var/log/advertising-monitor.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Получение статистики пользователей
get_user_stats() {
    cd /opt/xray-service
    
    # Количество пользователей
    total_users=$(docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -t -c "SELECT COUNT(*) FROM users;" | tr -d ' ')
    
    # Количество активных подписок
    active_subscriptions=$(docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -t -c "SELECT COUNT(*) FROM subscriptions WHERE is_active = true;" | tr -d ' ')
    
    # Количество платежей за сегодня
    today_payments=$(docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -t -c "SELECT COUNT(*) FROM payments WHERE DATE(created_at) = CURRENT_DATE;" | tr -d ' ')
    
    # Сумма платежей за сегодня
    today_revenue=$(docker exec xray-service_postgres_1 psql -U xray_user -d xray_service -t -c "SELECT COALESCE(SUM(amount), 0) FROM payments WHERE DATE(created_at) = CURRENT_DATE AND status = 'succeeded';" | tr -d ' ')
    
    log "Статистика за $(date '+%Y-%m-%d'):"
    log "• Всего пользователей: $total_users"
    log "• Активных подписок: $active_subscriptions"
    log "• Платежей за сегодня: $today_payments"
    log "• Доход за сегодня: $today_revenue₽"
}

# Отправка статистики в Telegram
send_stats_to_telegram() {
    BOT_TOKEN=$(grep "BOT_TOKEN" /opt/xray-service/.env | cut -d= -f2)
    ADMIN_CHAT_ID=$(grep "ADMIN_CHAT_ID" /opt/xray-service/.env | cut -d= -f2)
    
    if [[ -n "$BOT_TOKEN" && -n "$ADMIN_CHAT_ID" ]]; then
        stats_message="📊 Статистика за $(date '+%Y-%m-%d'):\n\n• Всего пользователей: $total_users\n• Активных подписок: $active_subscriptions\n• Платежей за сегодня: $today_payments\n• Доход за сегодня: $today_revenue₽"
        
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d chat_id="$ADMIN_CHAT_ID" \
            -d text="$stats_message"
    fi
}

# Основная функция
main() {
    get_user_stats
    send_stats_to_telegram
}

main "$@"
EOF
    
    chmod +x /opt/xray-service/scripts/monitor-advertising.sh
    
    # Добавление в cron для ежедневного мониторинга
    echo "0 9 * * * /opt/xray-service/scripts/monitor-advertising.sh" | crontab -
    
    log "Мониторинг рекламы настроен"
}

# Создание плана рекламной кампании
create_advertising_plan() {
    log "Создание плана рекламной кампании..."
    
    cat > /opt/xray-service/ad-materials/advertising-plan.txt << 'EOF'
📋 ПЛАН РЕКЛАМНОЙ КАМПАНИИ

🎯 ЦЕЛИ:
• Привлечь 1000 пользователей в первый месяц
• Достичь 100 активных подписок
• Получить доход 20,000₽ в месяц

📱 КАНАЛЫ ПРОДВИЖЕНИЯ:

1. TELEGRAM КАНАЛЫ:
   • Поиск каналов по тематике VPN, обход блокировок
   • Размещение рекламы в каналах с аудиторией 10K+
   • Стоимость: 500-2000₽ за пост
   • Ожидаемый охват: 50,000+ человек

2. TELEGRAM ГРУППЫ:
   • Поиск групп по тематике IT, технологии, обход блокировок
   • Размещение рекламы в группах с активной аудиторией
   • Стоимость: 200-1000₽ за пост
   • Ожидаемый охват: 20,000+ человек

3. СОЦИАЛЬНЫЕ СЕТИ:
   • VKontakte: группы по IT, технологии
   • Одноклассники: группы по обходу блокировок
   • Стоимость: 300-1500₽ за пост
   • Ожидаемый охват: 30,000+ человек

4. ФОРУМЫ И САЙТЫ:
   • IT форумы, сайты по обходу блокировок
   • Размещение рекламы в тематических разделах
   • Стоимость: 500-3000₽ за размещение
   • Ожидаемый охват: 15,000+ человек

💰 БЮДЖЕТ НА РЕКЛАМУ:
• Неделя 1: 5,000₽
• Неделя 2: 7,500₽
• Неделя 3: 10,000₽
• Неделя 4: 12,500₽
• Итого: 35,000₽ в месяц

📊 МЕТРИКИ ДЛЯ ОТСЛЕЖИВАНИЯ:
• Количество переходов по реферальным ссылкам
• Конверсия в регистрацию
• Конверсия в покупку
• Средний чек
• LTV (Lifetime Value) пользователя

🎁 ПРОМО-АКЦИИ:
• Бесплатный тест на 1 день
• Скидка 20% на первый месяц для новых пользователей
• Бонус 100₽ за привлечение 5 рефералов
• Скидка 17% при покупке годовой подписки

📈 ПЛАН РОСТА:
• Месяц 1: 1000 пользователей, 100 подписок
• Месяц 2: 2500 пользователей, 300 подписок
• Месяц 3: 5000 пользователей, 600 подписок
• Месяц 6: 15000 пользователей, 2000 подписок
• Месяц 12: 50000 пользователей, 8000 подписок
EOF
    
    log "План рекламной кампании создан"
}

# Основная функция
main() {
    log "📢 Запуск рекламной кампании..."
    
    echo "Выберите действие:"
    echo "1. Создать Telegram канал"
    echo "2. Настроить реферальную программу"
    echo "3. Создать рекламные материалы"
    echo "4. Настроить мониторинг рекламы"
    echo "5. Создать план рекламной кампании"
    echo "6. Все действия"
    
    read -p "Введите номер (1-6): " choice
    
    case $choice in
        1)
            create_telegram_channel
            ;;
        2)
            setup_referral_program
            ;;
        3)
            create_ad_materials
            ;;
        4)
            setup_ad_monitoring
            ;;
        5)
            create_advertising_plan
            ;;
        6)
            create_telegram_channel
            setup_referral_program
            create_ad_materials
            setup_ad_monitoring
            create_advertising_plan
            ;;
        *)
            error "Неверный выбор"
            exit 1
            ;;
    esac
    
    log "🎉 Рекламная кампания запущена!"
    
    info "Следующие шаги:"
    info "1. Разместите рекламу в Telegram каналах"
    info "2. Мониторьте статистику через бота"
    info "3. Оптимизируйте рекламные материалы"
    info "4. Масштабируйте успешные каналы"
}

main "$@"
