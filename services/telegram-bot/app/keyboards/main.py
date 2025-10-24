from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.utils.keyboard import InlineKeyboardBuilder

def get_start_keyboard() -> InlineKeyboardMarkup:
    """Клавиатура для начала работы"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="✅ Зарегистрироваться",
        callback_data="register_user"
    ))
    builder.add(InlineKeyboardButton(
        text="❌ Отменить",
        callback_data="cancel_registration"
    ))
    
    builder.adjust(1)
    return builder.as_markup()

def get_url_keyboard() -> InlineKeyboardMarkup:
    """Клавиатура для работы с URL"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="🌐 Веб-интерфейс",
        callback_data="get_web_url"
    ))
    builder.add(InlineKeyboardButton(
        text="📱 Мобильные клиенты",
        callback_data="get_mobile_url"
    ))
    builder.add(InlineKeyboardButton(
        text="💻 Десктопные клиенты",
        callback_data="get_desktop_url"
    ))
    builder.add(InlineKeyboardButton(
        text="📄 Файл конфигурации",
        callback_data="get_config_file"
    ))
    builder.add(InlineKeyboardButton(
        text="🏠 Главное меню",
        callback_data="main_menu"
    ))
    
    builder.adjust(2, 2, 1)
    return builder.as_markup()

def get_main_keyboard() -> InlineKeyboardMarkup:
    """Основная клавиатура"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="📱 Мои конфигурации",
        callback_data="my_configs"
    ))
    builder.add(InlineKeyboardButton(
        text="🔗 Получить URL",
        callback_data="get_url"
    ))
    builder.add(InlineKeyboardButton(
        text="💳 Подписка",
        callback_data="subscription"
    ))
    builder.add(InlineKeyboardButton(
        text="👥 Реферальная программа",
        callback_data="referral"
    ))
    builder.add(InlineKeyboardButton(
        text="👤 Профиль",
        callback_data="profile"
    ))
    builder.add(InlineKeyboardButton(
        text="🆘 Поддержка",
        callback_data="support"
    ))
    builder.add(InlineKeyboardButton(
        text="ℹ️ Помощь",
        callback_data="help"
    ))
    
    builder.adjust(2, 2, 2, 1)
    return builder.as_markup()

def get_configs_keyboard() -> InlineKeyboardMarkup:
    """Клавиатура управления конфигурациями"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="🆓 Получить тестовый конфиг",
        callback_data="get_test_config"
    ))
    builder.add(InlineKeyboardButton(
        text="📋 Мои конфигурации",
        callback_data="list_configs"
    ))
    builder.add(InlineKeyboardButton(
        text="🔄 Обновить конфигурации",
        callback_data="refresh_configs"
    ))
    builder.add(InlineKeyboardButton(
        text="🏠 Главное меню",
        callback_data="main_menu"
    ))
    
    builder.adjust(1)
    return builder.as_markup()

def get_subscription_keyboard() -> InlineKeyboardMarkup:
    """Клавиатура подписок"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="📅 Месячная подписка - 200₽",
        callback_data="subscribe_monthly"
    ))
    builder.add(InlineKeyboardButton(
        text="📅 Годовая подписка - 2000₽",
        callback_data="subscribe_yearly"
    ))
    builder.add(InlineKeyboardButton(
        text="🔄 Продлить подписку",
        callback_data="extend_subscription"
    ))
    builder.add(InlineKeyboardButton(
        text="📊 История платежей",
        callback_data="payment_history"
    ))
    builder.add(InlineKeyboardButton(
        text="🏠 Главное меню",
        callback_data="main_menu"
    ))
    
    builder.adjust(1)
    return builder.as_markup()

def get_payment_keyboard(payment_url: str, payment_id: str) -> InlineKeyboardMarkup:
    """Клавиатура для оплаты"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="💳 Оплатить",
        url=payment_url
    ))
    builder.add(InlineKeyboardButton(
        text="✅ Я оплатил",
        callback_data=f"check_payment_{payment_id}"
    ))
    builder.add(InlineKeyboardButton(
        text="❌ Отменить",
        callback_data="cancel_payment"
    ))
    
    builder.adjust(1)
    return builder.as_markup()

def get_referral_keyboard() -> InlineKeyboardMarkup:
    """Клавиатура реферальной программы"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="🔗 Моя реферальная ссылка",
        callback_data="get_referral_link"
    ))
    builder.add(InlineKeyboardButton(
        text="👥 Мои рефералы",
        callback_data="my_referrals"
    ))
    builder.add(InlineKeyboardButton(
        text="💰 Мой баланс",
        callback_data="referral_balance"
    ))
    builder.add(InlineKeyboardButton(
        text="💸 Вывести средства",
        callback_data="withdraw_funds"
    ))
    builder.add(InlineKeyboardButton(
        text="🏠 Главное меню",
        callback_data="main_menu"
    ))
    
    builder.adjust(1)
    return builder.as_markup()

def get_support_keyboard() -> InlineKeyboardMarkup:
    """Клавиатура поддержки"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="💬 Написать в поддержку",
        callback_data="contact_support"
    ))
    builder.add(InlineKeyboardButton(
        text="🐛 Сообщить об ошибке",
        callback_data="report_bug"
    ))
    builder.add(InlineKeyboardButton(
        text="💡 Предложить улучшение",
        callback_data="suggest_improvement"
    ))
    builder.add(InlineKeyboardButton(
        text="📞 Связаться с администратором",
        callback_data="contact_admin"
    ))
    builder.add(InlineKeyboardButton(
        text="🏠 Главное меню",
        callback_data="main_menu"
    ))
    
    builder.adjust(1)
    return builder.as_markup()

def get_admin_keyboard() -> InlineKeyboardMarkup:
    """Админская клавиатура"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="📊 Статистика",
        callback_data="admin_stats"
    ))
    builder.add(InlineKeyboardButton(
        text="👥 Пользователи",
        callback_data="admin_users"
    ))
    builder.add(InlineKeyboardButton(
        text="📢 Рассылка",
        callback_data="admin_broadcast"
    ))
    builder.add(InlineKeyboardButton(
        text="⚙️ Настройки",
        callback_data="admin_settings"
    ))
    builder.add(InlineKeyboardButton(
        text="🏠 Главное меню",
        callback_data="main_menu"
    ))
    
    builder.adjust(2, 2, 1)
    return builder.as_markup()

def get_confirmation_keyboard(action: str) -> InlineKeyboardMarkup:
    """Клавиатура подтверждения"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="✅ Да",
        callback_data=f"confirm_{action}"
    ))
    builder.add(InlineKeyboardButton(
        text="❌ Нет",
        callback_data=f"cancel_{action}"
    ))
    
    builder.adjust(2)
    return builder.as_markup()

def get_back_keyboard() -> InlineKeyboardMarkup:
    """Клавиатура с кнопкой назад"""
    builder = InlineKeyboardBuilder()
    
    builder.add(InlineKeyboardButton(
        text="🔙 Назад",
        callback_data="back"
    ))
    builder.add(InlineKeyboardButton(
        text="🏠 Главное меню",
        callback_data="main_menu"
    ))
    
    builder.adjust(2)
    return builder.as_markup()
