import logging
from aiogram import BaseMiddleware
from aiogram.types import Message, CallbackQuery

logger = logging.getLogger(__name__)

class LoggingMiddleware(BaseMiddleware):
    """Middleware для логирования"""
    
    async def __call__(self, handler, event, data):
        logger.info(f"Обработка события: {type(event).__name__}")
        return await handler(event, data)
