from aiogram import Router, F
from aiogram.types import Message, CallbackQuery, InlineKeyboardMarkup
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
import logging

from app.services.user_service import UserService
from app.keyboards.main import get_url_keyboard, get_main_keyboard
from app.utils.formatters import format_vless_url

logger = logging.getLogger(__name__)
router = Router()

# Инициализация сервиса
user_service = UserService()

class URLStates(StatesGroup):
    """Состояния для работы с URL"""
    waiting_for_url_input = State()

@router.message(Command("url"))
async def cmd_url(message: Message):
    """Обработчик команды /url"""
    try:
        user_id = message.from_user.id
        user = await user_service.get_user_by_telegram_id(user_id)
        
        if not user:
            await message.answer(
                "❌ Пользователь не найден. Используйте /start для регистрации."
            )
            return
        
        url_text = f"""
🔗 <b>Получение URL конфигурации</b>

Выберите тип URL который вам нужен:

🌐 <b>Веб-интерфейс:</b>
• Основной сайт: https://xray-vpn-service-seven.vercel.app/
• API документация: https://xray-vpn-service-seven.vercel.app/docs

📱 <b>Мобильные клиенты:</b>
• v2rayNG (Android)
• Shadowrocket (iOS)
• Clash (Windows/Mac)

💻 <b>Десктопные клиенты:</b>
• Qv2ray (Windows/Mac/Linux)
• Clash for Windows
• v2rayN (Windows)

Выберите действие:
        """
        
        await message.answer(url_text, reply_markup=get_url_keyboard())
        
    except Exception as e:
        logger.error(f"Ошибка обработки команды /url: {e}")
        await message.answer(
            "❌ Произошла ошибка. Попробуйте позже или обратитесь в поддержку."
        )

@router.callback_query(F.data == "get_web_url")
async def get_web_url(callback: CallbackQuery):
    """Получение веб-URL"""
    try:
        web_urls = f"""
🌐 <b>Веб-интерфейс сервиса</b>

🔗 <b>Основные ссылки:</b>
• Главная страница: https://xray-vpn-service-seven.vercel.app/
• API документация: https://xray-vpn-service-seven.vercel.app/docs
• Статус сервиса: https://xray-vpn-service-seven.vercel.app/health

📊 <b>Мониторинг:</b>
• Grafana: https://xray-vpn-service-seven.vercel.app/grafana
• Prometheus: https://xray-vpn-service-seven.vercel.app/prometheus

🔧 <b>Администрирование:</b>
• Панель управления: https://xray-vpn-service-seven.vercel.app/admin
• Логи системы: https://xray-vpn-service-seven.vercel.app/logs

💡 <b>Полезные ссылки:</b>
• Инструкция по настройке: https://xray-vpn-service-seven.vercel.app/guide
• FAQ: https://xray-vpn-service-seven.vercel.app/faq
• Поддержка: https://xray-vpn-service-seven.vercel.app/support
        """
        
        await callback.message.edit_text(web_urls, reply_markup=get_url_keyboard())
        
    except Exception as e:
        logger.error(f"Ошибка получения веб-URL: {e}")
        await callback.message.edit_text(
            "❌ Ошибка получения URL. Попробуйте позже."
        )

@router.callback_query(F.data == "get_mobile_url")
async def get_mobile_url(callback: CallbackQuery):
    """Получение мобильных URL"""
    try:
        user_id = callback.from_user.id
        user = await user_service.get_user_by_telegram_id(user_id)
        
        if not user:
            await callback.message.edit_text(
                "❌ Пользователь не найден."
            )
            return
        
        # Генерируем VLESS URL для пользователя
        vless_url = await generate_user_vless_url(user)
        
        mobile_text = f"""
📱 <b>Мобильные клиенты</b>

🔗 <b>Ваша VLESS конфигурация:</b>
<code>{vless_url}</code>

📲 <b>Поддерживаемые клиенты:</b>

🤖 <b>Android:</b>
• v2rayNG - https://play.google.com/store/apps/details?id=com.v2ray.ang
• v2rayTun - https://play.google.com/store/apps/details?id=com.v2ray.tun

🍎 <b>iOS:</b>
• Shadowrocket - https://apps.apple.com/app/shadowrocket/id932747118
• OneClick - https://apps.apple.com/app/oneclick/id1545555197

📋 <b>Инструкция:</b>
1. Скопируйте VLESS ссылку выше
2. Откройте ваш VPN клиент
3. Нажмите "Импорт" или "+"
4. Вставьте ссылку
5. Подключитесь к серверу

⚠️ <b>Важно:</b>
• Не передавайте ссылку третьим лицам
• Используйте только на ваших устройствах
• Максимум устройств: {user.max_devices}
        """
        
        await callback.message.edit_text(mobile_text, reply_markup=get_url_keyboard())
        
    except Exception as e:
        logger.error(f"Ошибка получения мобильного URL: {e}")
        await callback.message.edit_text(
            "❌ Ошибка получения конфигурации. Попробуйте позже."
        )

@router.callback_query(F.data == "get_desktop_url")
async def get_desktop_url(callback: CallbackQuery):
    """Получение десктопных URL"""
    try:
        user_id = callback.from_user.id
        user = await user_service.get_user_by_telegram_id(user_id)
        
        if not user:
            await callback.message.edit_text(
                "❌ Пользователь не найден."
            )
            return
        
        # Генерируем VLESS URL для пользователя
        vless_url = await generate_user_vless_url(user)
        
        desktop_text = f"""
💻 <b>Десктопные клиенты</b>

🔗 <b>Ваша VLESS конфигурация:</b>
<code>{vless_url}</code>

🖥️ <b>Поддерживаемые клиенты:</b>

🪟 <b>Windows:</b>
• v2rayN - https://github.com/2dust/v2rayN
• Clash for Windows - https://github.com/Fndroid/clash_for_windows_pkg
• Qv2ray - https://github.com/Qv2ray/Qv2ray

🍎 <b>macOS:</b>
• ClashX - https://github.com/yichengchen/clashX
• V2rayU - https://github.com/yanue/V2rayU
• Qv2ray - https://github.com/Qv2ray/Qv2ray

🐧 <b>Linux:</b>
• Qv2ray - https://github.com/Qv2ray/Qv2ray
• v2ray-core - https://github.com/v2fly/v2ray-core
• Clash - https://github.com/Dreamacro/clash

📋 <b>Инструкция:</b>
1. Скачайте подходящий клиент для вашей ОС
2. Скопируйте VLESS ссылку выше
3. Импортируйте конфигурацию в клиент
4. Подключитесь к серверу

⚠️ <b>Важно:</b>
• Не передавайте ссылку третьим лицам
• Используйте только на ваших устройствах
• Максимум устройств: {user.max_devices}
        """
        
        await callback.message.edit_text(desktop_text, reply_markup=get_url_keyboard())
        
    except Exception as e:
        logger.error(f"Ошибка получения десктопного URL: {e}")
        await callback.message.edit_text(
            "❌ Ошибка получения конфигурации. Попробуйте позже."
        )

@router.callback_query(F.data == "get_config_file")
async def get_config_file(callback: CallbackQuery):
    """Получение файла конфигурации"""
    try:
        user_id = callback.from_user.id
        user = await user_service.get_user_by_telegram_id(user_id)
        
        if not user:
            await callback.message.edit_text(
                "❌ Пользователь не найден."
            )
            return
        
        config_text = f"""
📄 <b>Файл конфигурации</b>

🔗 <b>Скачать конфигурацию:</b>
• JSON конфиг: https://xray-vpn-service-seven.vercel.app/api/config/{user.telegram_id}/json
• VLESS ссылка: https://xray-vpn-service-seven.vercel.app/api/config/{user.telegram_id}/vless
• QR код: https://xray-vpn-service-seven.vercel.app/api/config/{user.telegram_id}/qr

📱 <b>QR код для мобильных:</b>
• Отсканируйте QR код для быстрой настройки
• Работает с большинством VPN клиентов

🔧 <b>Ручная настройка:</b>
• Используйте JSON конфиг для продвинутых клиентов
• VLESS ссылка для простых клиентов

⚠️ <b>Безопасность:</b>
• Ссылки действительны только для вашего аккаунта
• Не передавайте ссылки третьим лицам
• При подозрении на компрометацию обратитесь в поддержку
        """
        
        await callback.message.edit_text(config_text, reply_markup=get_url_keyboard())
        
    except Exception as e:
        logger.error(f"Ошибка получения файла конфигурации: {e}")
        await callback.message.edit_text(
            "❌ Ошибка получения конфигурации. Попробуйте позже."
        )

async def generate_user_vless_url(user) -> str:
    """Генерация VLESS URL для пользователя"""
    try:
        # Здесь должна быть логика генерации VLESS URL
        # Пока возвращаем пример
        server_ip = "89.188.113.58"  # IP вашего сервера
        port = "443"
        uuid = "2227fcce-08c2-473f-87a1-4d9595972646"  # UUID из конфига
        public_key = "-TL01QWTd3nVXR4qdfnAea5JgUcEzwa_qvpw9KGtTRc"  # Public key
        server_name = "www.microsoft.com"  # SNI домен
        
        vless_url = f"vless://{uuid}@{server_ip}:{port}?encryption=none&security=reality&sni={server_name}&pbk={public_key}&fp=chrome&type=tcp&headerType=none&flow=#XrayVPN-{user.telegram_id}"
        
        return vless_url
        
    except Exception as e:
        logger.error(f"Ошибка генерации VLESS URL: {e}")
        return "Ошибка генерации конфигурации"

@router.callback_query(F.data == "url_back")
async def url_back(callback: CallbackQuery):
    """Возврат к URL меню"""
    try:
        url_text = f"""
🔗 <b>Получение URL конфигурации</b>

Выберите тип URL который вам нужен:

🌐 <b>Веб-интерфейс:</b>
• Основной сайт: https://xray-vpn-service-seven.vercel.app/
• API документация: https://xray-vpn-service-seven.vercel.app/docs

📱 <b>Мобильные клиенты:</b>
• v2rayNG (Android)
• Shadowrocket (iOS)
• Clash (Windows/Mac)

💻 <b>Десктопные клиенты:</b>
• Qv2ray (Windows/Mac/Linux)
• Clash for Windows
• v2rayN (Windows)

Выберите действие:
        """
        
        await callback.message.edit_text(url_text, reply_markup=get_url_keyboard())
        
    except Exception as e:
        logger.error(f"Ошибка возврата к URL меню: {e}")
        await callback.message.edit_text(
            "❌ Ошибка. Попробуйте позже."
        )
