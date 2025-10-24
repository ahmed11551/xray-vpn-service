import asyncio
import logging
import os
from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.webhook.aiohttp_server import SimpleRequestHandler, setup_application
from aiohttp import web

from app.config import settings
from app.handlers import start, profile, configs, subscription, referral, support, url
from app.middlewares import auth, throttling, logging_middleware
from app.services.user_service import UserService
from app.services.payment_service import PaymentService

# Настройка логирования
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Создание бота
bot = Bot(
    token=settings.BOT_TOKEN,
    default=DefaultBotProperties(parse_mode=ParseMode.HTML)
)

# Создание диспетчера с MemoryStorage для Vercel
storage = MemoryStorage()
dp = Dispatcher(storage=storage)

# Регистрация middleware
dp.message.middleware(throttling.ThrottlingMiddleware())
dp.message.middleware(auth.AuthMiddleware())
dp.message.middleware(logging_middleware.LoggingMiddleware())

# Регистрация обработчиков
dp.include_router(start.router)
dp.include_router(profile.router)
dp.include_router(configs.router)
dp.include_router(subscription.router)
dp.include_router(referral.router)
dp.include_router(support.router)
dp.include_router(url.router)

# Инициализация сервисов
user_service = UserService()
payment_service = PaymentService()

async def on_startup():
    """Инициализация при запуске"""
    logger.info("Запуск Telegram Bot на Vercel...")
    
    # Установка webhook для Vercel
    webhook_url = f"{settings.webhook_url}/api/bot/webhook"
    await bot.set_webhook(
        url=webhook_url,
        secret_token=settings.WEBHOOK_SECRET
    )
    
    # Инициализация сервисов (упрощенная для Vercel)
    try:
        await user_service.initialize()
        await payment_service.initialize()
    except Exception as e:
        logger.warning(f"Ошибка инициализации сервисов: {e}")
    
    logger.info(f"Bot запущен на Vercel. Webhook: {webhook_url}")

async def on_shutdown():
    """Очистка при остановке"""
    logger.info("Остановка Telegram Bot...")
    
    # Удаление webhook
    try:
        await bot.delete_webhook()
    except Exception as e:
        logger.warning(f"Ошибка удаления webhook: {e}")
    
    # Очистка сервисов
    try:
        await user_service.cleanup()
        await payment_service.cleanup()
    except Exception as e:
        logger.warning(f"Ошибка очистки сервисов: {e}")
    
    # Закрытие соединений
    try:
        await bot.session.close()
    except Exception as e:
        logger.warning(f"Ошибка закрытия сессии: {e}")
    
    logger.info("Bot остановлен")

async def webhook_handler(request):
    """Обработчик webhook от Telegram"""
    try:
        # Получение данных
        data = await request.json()
        
        # Проверка секретного токена
        if settings.WEBHOOK_SECRET:
            secret_token = request.headers.get('X-Telegram-Bot-Api-Secret-Token')
            if secret_token != settings.WEBHOOK_SECRET:
                logger.warning("Неверный секретный токен webhook")
                return web.Response(status=403)
        
        # Обработка обновления
        await dp.feed_update(bot, data)
        
        return web.Response(text="OK")
        
    except Exception as e:
        logger.error(f"Ошибка обработки webhook: {e}")
        return web.Response(status=500)

async def payment_webhook_handler(request):
    """Обработчик webhook от платежных систем"""
    try:
        # Получение данных
        data = await request.json()
        
        # Обработка платежа
        result = await payment_service.process_webhook(data)
        
        if result:
            return web.Response(text="OK")
        else:
            return web.Response(status=400)
            
    except Exception as e:
        logger.error(f"Ошибка обработки платежного webhook: {e}")
        return web.Response(status=500)

async def health_check(request):
    """Health check endpoint"""
    try:
        # Проверка подключения к Redis
        await redis_client.ping()
        
        # Проверка статуса бота
        bot_info = await bot.get_me()
        
        return web.json_response({
            "status": "healthy",
            "bot_username": bot_info.username,
            "bot_id": bot_info.id,
            "timestamp": "2024-01-01T00:00:00Z"
        })
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return web.json_response(
            {"status": "unhealthy", "error": str(e)},
            status=503
        )

def create_app():
    """Создание aiohttp приложения для Vercel"""
    app = web.Application()
    
    # Регистрация маршрутов для Vercel
    app.router.add_post("/api/bot/webhook", webhook_handler)
    app.router.add_post("/api/payment/yookassa/webhook", payment_webhook_handler)
    app.router.add_post("/api/payment/robokassa/webhook", payment_webhook_handler)
    app.router.add_post("/api/payment/crypto/webhook", payment_webhook_handler)
    app.router.add_get("/api/bot/health", health_check)
    
    # Настройка обработчика Telegram для Vercel
    webhook_handler_obj = SimpleRequestHandler(
        dispatcher=dp,
        bot=bot,
        secret_token=settings.WEBHOOK_SECRET
    )
    webhook_handler_obj.register(app, path="/api/bot/webhook")
    
    # Настройка приложения
    setup_application(app, dp, bot=bot)
    
    return app

# Vercel handler
app = create_app()

async def vercel_handler(request):
    """Обработчик для Vercel"""
    return await app._handle_request(request)

# Для локального запуска
async def main():
    """Основная функция для локального запуска"""
    # Создание приложения
    app = create_app()
    
    # Настройка startup/shutdown
    app.on_startup.append(on_startup)
    app.on_shutdown.append(on_shutdown)
    
    # Запуск сервера
    runner = web.AppRunner(app)
    await runner.setup()
    
    site = web.TCPSite(runner, "0.0.0.0", 8001)
    await site.start()
    
    logger.info("Сервер запущен на порту 8001")
    
    # Ожидание завершения
    try:
        await asyncio.Future()  # Бесконечное ожидание
    except KeyboardInterrupt:
        logger.info("Получен сигнал остановки")
    finally:
        await runner.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
