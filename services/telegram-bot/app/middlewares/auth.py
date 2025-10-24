import logging
from aiogram import BaseMiddleware
from aiogram.types import Message, CallbackQuery

logger = logging.getLogger(__name__)

class AuthMiddleware(BaseMiddleware):
    """Упрощенный middleware для аутентификации"""
    
    async def __call__(self, handler, event, data):
        # Простая проверка без базы данных
        return await handler(event, data)
