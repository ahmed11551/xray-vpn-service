import os
from typing import Optional

class Settings:
    """Настройки Telegram бота"""
    
    # Telegram Bot Token
    BOT_TOKEN: str = os.getenv("BOT_TOKEN", "")
    
    # Webhook настройки для Vercel
    WEBHOOK_URL: str = os.getenv("TELEGRAM_WEBHOOK_URL", "https://xray-vpn-service-seven.vercel.app")
    WEBHOOK_SECRET: Optional[str] = os.getenv("WEBHOOK_SECRET")
    
    # База данных
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/xray_db")
    
    # Redis
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379")
    
    # Платежные системы
    YOOKASSA_SHOP_ID: str = os.getenv("YOOKASSA_SHOP_ID", "")
    YOOKASSA_SECRET_KEY: str = os.getenv("YOOKASSA_SECRET_KEY", "")
    
    # Xray настройки
    XRAY_SERVER_IP: str = os.getenv("XRAY_SERVER_IP", "89.188.113.58")
    XRAY_SERVER_PORT: str = os.getenv("XRAY_SERVER_PORT", "443")
    REALITY_PRIVATE_KEY: str = os.getenv("REALITY_PRIVATE_KEY", "EF_esPyGL08X9rEOxQfwa7zAHCHeRN-hhjOlB1SxYE0")
    REALITY_PUBLIC_KEY: str = os.getenv("REALITY_PUBLIC_KEY", "-TL01QWTd3nVXR4qdfnAea5JgUcEzwa_qvpw9KGtTRc")
    
    # Админ настройки
    ADMIN_USER_IDS: list = [int(x) for x in os.getenv("ADMIN_USER_IDS", "").split(",") if x.strip()]
    
    # Настройки приложения
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    
    # Vercel специфичные настройки
    VERCEL_URL: str = os.getenv("VERCEL_URL", "")
    VERCEL_ENV: str = os.getenv("VERCEL_ENV", "development")
    
    @property
    def webhook_url(self) -> str:
        """Получение URL для webhook"""
        if self.VERCEL_URL:
            return f"https://{self.VERCEL_URL}"
        return self.WEBHOOK_URL
    
    @property
    def is_production(self) -> bool:
        """Проверка продакшн окружения"""
        return self.VERCEL_ENV == "production"

# Создание экземпляра настроек
settings = Settings()
