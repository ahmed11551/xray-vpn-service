from aiogram import Router, F
from aiogram.types import Message, CallbackQuery
from aiogram.filters import Command, StateFilter
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
import logging

from app.services.user_service import UserService
from app.keyboards.main import get_main_keyboard, get_start_keyboard, get_url_keyboard
from app.schemas.user import UserCreate
from app.utils.formatters import format_user_info

logger = logging.getLogger(__name__)
router = Router()

# Инициализация сервиса
user_service = UserService()

class RegistrationStates(StatesGroup):
    """Состояния регистрации"""
    waiting_for_name = State()
    waiting_for_confirmation = State()

@router.message(Command("start"))
async def cmd_start(message: Message, state: FSMContext):
    """Обработчик команды /start"""
    try:
        user_id = message.from_user.id
        username = message.from_user.username
        first_name = message.from_user.first_name
        last_name = message.from_user.last_name
        
        # Проверка существования пользователя
        user = await user_service.get_user_by_telegram_id(user_id)
        
        if user:
            # Пользователь уже зарегистрирован
            await message.answer(
                f"👋 Добро пожаловать обратно, {first_name}!\n\n"
                f"Ваш профиль:\n{format_user_info(user)}",
                reply_markup=get_main_keyboard()
            )
        else:
            # Новый пользователь - регистрация
            await message.answer(
                f"👋 Привет, {first_name}!\n\n"
                f"Добро пожаловать в наш сервис для обхода блокировок мобильных операторов!\n\n"
                f"🔹 Полный доступ к YouTube, Instagram, Facebook\n"
                f"🔹 Работает через мобильный интернет\n"
                f"🔹 Автоматическое обновление конфигураций\n"
                f"🔹 Бесплатный тест на 1 день\n\n"
                f"Для начала работы нужно пройти регистрацию.",
                reply_markup=get_start_keyboard()
            )
            
            # Сохранение данных пользователя
            await state.update_data(
                telegram_id=user_id,
                username=username,
                first_name=first_name,
                last_name=last_name
            )
            
            await state.set_state(RegistrationStates.waiting_for_confirmation)
        
    except Exception as e:
        logger.error(f"Ошибка обработки команды /start: {e}")
        await message.answer(
            "❌ Произошла ошибка. Попробуйте позже или обратитесь в поддержку."
        )

@router.callback_query(F.data == "register_user")
async def process_registration(callback: CallbackQuery, state: FSMContext):
    """Обработка регистрации пользователя"""
    try:
        data = await state.get_data()
        
        # Создание пользователя
        user_data = UserCreate(
            telegram_id=data["telegram_id"],
            username=data.get("username"),
            first_name=data.get("first_name"),
            last_name=data.get("last_name"),
            max_devices=3
        )
        
        user = await user_service.create_user(user_data)
        
        if user:
            await callback.message.edit_text(
                f"✅ Регистрация успешно завершена!\n\n"
                f"Ваш профиль:\n{format_user_info(user)}\n\n"
                f"🎁 Вам доступен бесплатный тест на 1 день!\n"
                f"Используйте кнопку 'Мои конфигурации' для получения тестового конфига.",
                reply_markup=get_main_keyboard()
            )
            
            # Очистка состояния
            await state.clear()
            
            logger.info(f"Пользователь {user.telegram_id} успешно зарегистрирован")
        else:
            await callback.message.edit_text(
                "❌ Ошибка регистрации. Попробуйте позже или обратитесь в поддержку."
            )
    
    except Exception as e:
        logger.error(f"Ошибка регистрации пользователя: {e}")
        await callback.message.edit_text(
            "❌ Произошла ошибка при регистрации. Попробуйте позже."
        )

@router.callback_query(F.data == "cancel_registration")
async def cancel_registration(callback: CallbackQuery, state: FSMContext):
    """Отмена регистрации"""
    await state.clear()
    await callback.message.edit_text(
        "❌ Регистрация отменена.\n\n"
        "Если передумаете, используйте команду /start для повторной регистрации."
    )

@router.message(Command("help"))
async def cmd_help(message: Message):
    """Обработчик команды /help"""
    help_text = """
🤖 <b>Помощь по использованию бота</b>

<b>Основные команды:</b>
/start - Начать работу с ботом
/profile - Информация о профиле
/configs - Мои конфигурации
/url - Получить URL конфигурации
/subscribe - Купить подписку
/referral - Реферальная программа
/support - Связаться с поддержкой

<b>Как получить конфигурацию:</b>
1. Нажмите "Мои конфигурации"
2. Выберите "Получить тестовый конфиг" (бесплатно на 1 день)
3. Скопируйте VLESS ссылку
4. Добавьте в ваш Xray клиент

<b>Новый функционал:</b>
🔗 <b>Команда /url</b> - Получение URL конфигурации
• Веб-интерфейс: https://xray-vpn-service-seven.vercel.app/
• Мобильные клиенты (Android/iOS)
• Десктопные клиенты (Windows/Mac/Linux)
• Файлы конфигурации и QR коды

<b>Поддерживаемые клиенты:</b>
• v2rayNG (Android)
• Shadowrocket (iOS)
• Clash (Windows/Mac)
• Qv2ray (Windows/Mac/Linux)

<b>Реферальная программа:</b>
• Получайте 10% от каждой покупки ваших рефералов
• Постоянные выплаты при продлении подписок
• Минимальная сумма вывода: 1000 руб

<b>Поддержка:</b>
Если у вас возникли вопросы, используйте команду /support
    """
    
    await message.answer(help_text, reply_markup=get_main_keyboard())

@router.message(Command("profile"))
async def cmd_profile(message: Message):
    """Обработчик команды /profile"""
    try:
        user_id = message.from_user.id
        user = await user_service.get_user_by_telegram_id(user_id)
        
        if not user:
            await message.answer(
                "❌ Пользователь не найден. Используйте /start для регистрации."
            )
            return
        
        profile_text = f"""
👤 <b>Ваш профиль</b>

🆔 ID: {user.telegram_id}
👤 Имя: {user.first_name or 'Не указано'}
📱 Username: @{user.username or 'Не указано'}
📅 Регистрация: {user.created_at.strftime('%d.%m.%Y')}

📊 <b>Статистика:</b>
🔹 Устройств: {user.device_count}/{user.max_devices}
🔹 Статус: {'✅ Активен' if user.is_active else '❌ Заблокирован'}
🔹 Премиум: {'✅ Да' if user.is_premium else '❌ Нет'}

💳 <b>Подписка:</b>
🔹 Статус: {'✅ Активна' if user.is_premium else '❌ Неактивна'}
🔹 Последний вход: {user.last_seen.strftime('%d.%m.%Y %H:%M') if user.last_seen else 'Никогда'}
        """
        
        await message.answer(profile_text, reply_markup=get_main_keyboard())
        
    except Exception as e:
        logger.error(f"Ошибка получения профиля: {e}")
        await message.answer(
            "❌ Ошибка получения профиля. Попробуйте позже."
        )

@router.callback_query(F.data == "get_url")
async def get_url_menu(callback: CallbackQuery):
    """Обработчик кнопки 'Получить URL'"""
    try:
        user_id = callback.from_user.id
        user = await user_service.get_user_by_telegram_id(user_id)
        
        if not user:
            await callback.message.edit_text(
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
        
        await callback.message.edit_text(url_text, reply_markup=get_url_keyboard())
        
    except Exception as e:
        logger.error(f"Ошибка обработки кнопки 'Получить URL': {e}")
        await callback.message.edit_text(
            "❌ Произошла ошибка. Попробуйте позже."
        )

@router.callback_query(F.data == "main_menu")
async def main_menu(callback: CallbackQuery):
    """Возврат в главное меню"""
    try:
        user_id = callback.from_user.id
        user = await user_service.get_user_by_telegram_id(user_id)
        
        if user:
            await callback.message.edit_text(
                f"🏠 <b>Главное меню</b>\n\n"
                f"Добро пожаловать, {user.first_name or 'Пользователь'}!\n\n"
                f"Выберите действие:",
                reply_markup=get_main_keyboard()
            )
        else:
            await callback.message.edit_text(
                "❌ Пользователь не найден. Используйте /start для регистрации."
            )
    
    except Exception as e:
        logger.error(f"Ошибка возврата в главное меню: {e}")
        await callback.message.edit_text(
            "❌ Ошибка. Попробуйте позже."
        )
