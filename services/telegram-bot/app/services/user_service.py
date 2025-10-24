import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

class UserService:
    """Упрощенный сервис пользователей для Vercel"""
    
    def __init__(self):
        self.users = {}  # Простое хранилище в памяти
    
    async def initialize(self):
        """Инициализация сервиса"""
        logger.info("UserService инициализирован (Vercel режим)")
    
    async def cleanup(self):
        """Очистка сервиса"""
        logger.info("UserService очищен")
    
    async def get_user_by_telegram_id(self, telegram_id: int) -> Optional[Dict[str, Any]]:
        """Получение пользователя по Telegram ID"""
        return self.users.get(telegram_id)
    
    async def create_user(self, user_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Создание пользователя"""
        user = {
            "telegram_id": user_data.get("telegram_id"),
            "username": user_data.get("username"),
            "first_name": user_data.get("first_name"),
            "last_name": user_data.get("last_name"),
            "max_devices": user_data.get("max_devices", 3),
            "device_count": 0,
            "is_active": True,
            "is_premium": False,
            "created_at": "2024-01-01T00:00:00Z",
            "last_seen": "2024-01-01T00:00:00Z"
        }
        self.users[user_data["telegram_id"]] = user
        return user

class PaymentService:
    """Упрощенный сервис платежей для Vercel"""
    
    def __init__(self):
        self.payments = {}
    
    async def initialize(self):
        """Инициализация сервиса"""
        logger.info("PaymentService инициализирован (Vercel режим)")
    
    async def cleanup(self):
        """Очистка сервиса"""
        logger.info("PaymentService очищен")
    
    async def process_webhook(self, data: Dict[str, Any]) -> bool:
        """Обработка webhook платежа"""
        logger.info(f"Обработка платежа: {data}")
        return True
