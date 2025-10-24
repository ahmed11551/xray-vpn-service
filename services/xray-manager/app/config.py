from pydantic import BaseSettings, Field
from typing import List, Optional
import os

class Settings(BaseSettings):
    """Конфигурация приложения"""
    
    # Основные настройки
    DEBUG: bool = Field(default=False, env="DEBUG")
    LOG_LEVEL: str = Field(default="info", env="LOG_LEVEL")
    ENVIRONMENT: str = Field(default="production", env="ENVIRONMENT")
    
    # API настройки
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "Xray Manager"
    VERSION: str = "1.0.0"
    
    # CORS настройки
    ALLOWED_ORIGINS: List[str] = Field(
        default=["http://localhost:3000", "https://your-domain.com"],
        env="ALLOWED_ORIGINS"
    )
    ALLOWED_HOSTS: List[str] = Field(
        default=["localhost", "127.0.0.1", "your-domain.com"],
        env="ALLOWED_HOSTS"
    )
    
    # База данных
    DATABASE_URL: str = Field(
        default="postgresql://xray_user:password@localhost:5432/xray_service",
        env="DATABASE_URL"
    )
    
    # Redis
    REDIS_URL: str = Field(
        default="redis://localhost:6379",
        env="REDIS_URL"
    )
    
    # Xray настройки
    XRAY_CONFIG_DIR: str = Field(
        default="/etc/xray",
        env="XRAY_CONFIG_DIR"
    )
    XRAY_LOG_DIR: str = Field(
        default="/var/log/xray",
        env="XRAY_LOG_DIR"
    )
    
    # SNI настройки
    SNI_DOMAINS: List[str] = Field(
        default=["vk.com", "yandex.ru", "sberbank.ru", "mail.ru"],
        env="SNI_DOMAINS"
    )
    SNI_UPDATE_INTERVAL: str = Field(
        default="6h",
        env="SNI_UPDATE_INTERVAL"
    )
    SNI_HEALTH_CHECK_INTERVAL: str = Field(
        default="5m",
        env="SNI_HEALTH_CHECK_INTERVAL"
    )
    
    # Мониторинг
    METRICS_ENABLED: bool = Field(default=True, env="METRICS_ENABLED")
    PROMETHEUS_PORT: int = Field(default=9090, env="PROMETHEUS_PORT")
    
    # Алерты
    ALERT_CPU_THRESHOLD: int = Field(default=80, env="ALERT_CPU_THRESHOLD")
    ALERT_MEMORY_THRESHOLD: int = Field(default=85, env="ALERT_MEMORY_THRESHOLD")
    ALERT_CONNECTION_THRESHOLD: int = Field(default=1000, env="ALERT_CONNECTION_THRESHOLD")
    
    # Telegram уведомления
    TELEGRAM_BOT_TOKEN: Optional[str] = Field(default=None, env="TELEGRAM_BOT_TOKEN")
    TELEGRAM_CHAT_ID: Optional[str] = Field(default=None, env="TELEGRAM_CHAT_ID")
    
    # Безопасность
    SECRET_KEY: str = Field(
        default="your-secret-key-change-in-production",
        env="SECRET_KEY"
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=30, env="ACCESS_TOKEN_EXPIRE_MINUTES")
    
    # Rate limiting
    RATE_LIMIT_REQUESTS: int = Field(default=100, env="RATE_LIMIT_REQUESTS")
    RATE_LIMIT_WINDOW: int = Field(default=60, env="RATE_LIMIT_WINDOW")
    
    # Backup настройки
    BACKUP_ENABLED: bool = Field(default=True, env="BACKUP_ENABLED")
    BACKUP_RETENTION_DAYS: int = Field(default=30, env="BACKUP_RETENTION_DAYS")
    BACKUP_SCHEDULE: str = Field(default="0 2 * * *", env="BACKUP_SCHEDULE")
    
    class Config:
        env_file = ".env"
        case_sensitive = True

# Создание экземпляра настроек
settings = Settings()

# Валидация настроек
def validate_settings():
    """Валидация конфигурации"""
    if settings.ENVIRONMENT == "production":
        if settings.SECRET_KEY == "your-secret-key-change-in-production":
            raise ValueError("SECRET_KEY must be changed in production")
        
        if not settings.TELEGRAM_BOT_TOKEN:
            raise ValueError("TELEGRAM_BOT_TOKEN is required in production")
        
        if not settings.TELEGRAM_CHAT_ID:
            raise ValueError("TELEGRAM_CHAT_ID is required in production")

# Выполнение валидации при импорте
validate_settings()
