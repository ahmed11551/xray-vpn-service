from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum

class ServerStatus(str, Enum):
    """Статусы сервера"""
    ACTIVE = "active"
    INACTIVE = "inactive"
    MAINTENANCE = "maintenance"

class ConfigStatus(str, Enum):
    """Статусы конфигурации"""
    ACTIVE = "active"
    EXPIRED = "expired"
    SUSPENDED = "suspended"

# Server Schemas
class ServerBase(BaseModel):
    """Базовая схема сервера"""
    name: str = Field(..., description="Название сервера")
    host: str = Field(..., description="Хост сервера")
    port: int = Field(443, description="Порт сервера")

class ServerCreate(ServerBase):
    """Схема создания сервера"""
    reality_private_key: str = Field(..., description="Приватный ключ Reality")
    reality_public_key: str = Field(..., description="Публичный ключ Reality")
    reality_short_id: str = Field(..., description="Короткий ID Reality")

class ServerUpdate(BaseModel):
    """Схема обновления сервера"""
    name: Optional[str] = None
    host: Optional[str] = None
    port: Optional[int] = None
    status: Optional[ServerStatus] = None
    reality_private_key: Optional[str] = None
    reality_public_key: Optional[str] = None
    reality_short_id: Optional[str] = None

class ServerResponse(ServerBase):
    """Схема ответа сервера"""
    id: int
    server_id: str
    uuid: str
    reality_public_key: str
    reality_short_id: str
    status: ServerStatus
    is_healthy: bool
    last_health_check: datetime
    cpu_usage: float
    memory_usage: float
    connection_count: int
    bandwidth_usage: float
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Config Schemas
class ConfigBase(BaseModel):
    """Базовая схема конфигурации"""
    user_id: int = Field(..., description="ID пользователя")
    server_id: int = Field(..., description="ID сервера")

class ConfigCreate(ConfigBase):
    """Схема создания конфигурации"""
    expires_at: Optional[datetime] = None

class ConfigUpdate(BaseModel):
    """Схема обновления конфигурации"""
    status: Optional[ConfigStatus] = None
    expires_at: Optional[datetime] = None
    sni_domain: Optional[str] = None

class ConfigResponse(ConfigBase):
    """Схема ответа конфигурации"""
    id: int
    config_id: str
    config_data: str
    config_url: str
    sni_domain: str
    sni_dest: str
    status: ConfigStatus
    expires_at: Optional[datetime]
    bytes_uploaded: int
    bytes_downloaded: int
    last_used: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# User Schemas
class UserBase(BaseModel):
    """Базовая схема пользователя"""
    telegram_id: int = Field(..., description="Telegram ID")
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None

class UserCreate(UserBase):
    """Схема создания пользователя"""
    max_devices: int = Field(3, description="Максимальное количество устройств")

class UserUpdate(BaseModel):
    """Схема обновления пользователя"""
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    is_active: Optional[bool] = None
    is_premium: Optional[bool] = None
    max_devices: Optional[int] = None

class UserResponse(UserBase):
    """Схема ответа пользователя"""
    id: int
    is_active: bool
    is_premium: bool
    max_devices: int
    device_count: int
    created_at: datetime
    updated_at: datetime
    last_seen: Optional[datetime]

    class Config:
        from_attributes = True

# SNI Schemas
class SNIDomainBase(BaseModel):
    """Базовая схема SNI домена"""
    domain: str = Field(..., description="Домен для маскировки")

class SNIDomainCreate(SNIDomainBase):
    """Схема создания SNI домена"""
    pass

class SNIDomainUpdate(BaseModel):
    """Схема обновления SNI домена"""
    is_available: Optional[bool] = None
    is_active: Optional[bool] = None

class SNIDomainResponse(SNIDomainBase):
    """Схема ответа SNI домена"""
    id: int
    is_available: bool
    is_active: bool
    last_checked: datetime
    latency: float
    success_rate: float
    usage_count: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Metrics Schemas
class ServerMetricsResponse(BaseModel):
    """Схема метрик сервера"""
    server_id: int
    cpu_usage: float
    memory_usage: float
    disk_usage: float
    connection_count: int
    bandwidth_usage: float
    timestamp: datetime

    class Config:
        from_attributes = True

class ConfigUsageResponse(BaseModel):
    """Схема использования конфигурации"""
    config_id: int
    bytes_uploaded: int
    bytes_downloaded: int
    connection_time: int
    timestamp: datetime

    class Config:
        from_attributes = True

# Health Check Schemas
class HealthCheckResponse(BaseModel):
    """Схема health check"""
    status: str
    database: str
    servers: dict
    sni: dict
    timestamp: str

# Error Schemas
class ErrorResponse(BaseModel):
    """Схема ошибки"""
    error: str
    detail: Optional[str] = None
    timestamp: datetime

# Pagination Schemas
class PaginationParams(BaseModel):
    """Параметры пагинации"""
    page: int = Field(1, ge=1, description="Номер страницы")
    size: int = Field(20, ge=1, le=100, description="Размер страницы")

class PaginatedResponse(BaseModel):
    """Схема пагинированного ответа"""
    items: List[dict]
    total: int
    page: int
    size: int
    pages: int

# Utility Schemas
class MessageResponse(BaseModel):
    """Схема сообщения"""
    message: str
    timestamp: datetime
