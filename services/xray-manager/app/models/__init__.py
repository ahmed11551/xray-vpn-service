from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, ForeignKey, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import uuid

Base = declarative_base()

class Server(Base):
    """Модель сервера Xray"""
    __tablename__ = "servers"
    
    id = Column(Integer, primary_key=True, index=True)
    server_id = Column(String(50), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=False)
    host = Column(String(255), nullable=False)
    port = Column(Integer, nullable=False, default=443)
    
    # Xray конфигурация
    uuid = Column(String(36), nullable=False, default=lambda: str(uuid.uuid4()))
    reality_private_key = Column(String(255), nullable=False)
    reality_public_key = Column(String(255), nullable=False)
    reality_short_id = Column(String(50), nullable=False)
    
    # Статус и мониторинг
    status = Column(String(20), default="active")  # active, inactive, maintenance
    is_healthy = Column(Boolean, default=True)
    last_health_check = Column(DateTime, default=func.now())
    
    # Метрики
    cpu_usage = Column(Float, default=0.0)
    memory_usage = Column(Float, default=0.0)
    connection_count = Column(Integer, default=0)
    bandwidth_usage = Column(Float, default=0.0)
    
    # Временные метки
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    
    # Связи
    configs = relationship("Config", back_populates="server")

class Config(Base):
    """Модель конфигурации пользователя"""
    __tablename__ = "configs"
    
    id = Column(Integer, primary_key=True, index=True)
    config_id = Column(String(50), unique=True, index=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    server_id = Column(Integer, ForeignKey("servers.id"), nullable=False)
    
    # Конфигурация
    config_data = Column(Text, nullable=False)  # JSON конфигурация
    config_url = Column(Text, nullable=False)    # VLESS URL
    
    # SNI настройки
    sni_domain = Column(String(255), nullable=False)
    sni_dest = Column(String(255), nullable=False)
    
    # Статус
    status = Column(String(20), default="active")  # active, expired, suspended
    expires_at = Column(DateTime, nullable=True)
    
    # Использование
    bytes_uploaded = Column(Integer, default=0)
    bytes_downloaded = Column(Integer, default=0)
    last_used = Column(DateTime, nullable=True)
    
    # Временные метки
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    
    # Связи
    user = relationship("User", back_populates="configs")
    server = relationship("Server", back_populates="configs")

class User(Base):
    """Модель пользователя"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    telegram_id = Column(Integer, unique=True, index=True, nullable=False)
    username = Column(String(255), nullable=True)
    first_name = Column(String(255), nullable=True)
    last_name = Column(String(255), nullable=True)
    
    # Статус
    is_active = Column(Boolean, default=True)
    is_premium = Column(Boolean, default=False)
    
    # Лимиты
    max_devices = Column(Integer, default=3)
    device_count = Column(Integer, default=0)
    
    # Временные метки
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    last_seen = Column(DateTime, nullable=True)
    
    # Связи
    configs = relationship("Config", back_populates="user")

class SNIDomain(Base):
    """Модель SNI домена"""
    __tablename__ = "sni_domains"
    
    id = Column(Integer, primary_key=True, index=True)
    domain = Column(String(255), unique=True, index=True, nullable=False)
    
    # Статус
    is_available = Column(Boolean, default=True)
    is_active = Column(Boolean, default=True)
    last_checked = Column(DateTime, default=func.now())
    
    # Метрики
    latency = Column(Float, default=0.0)
    success_rate = Column(Float, default=100.0)
    usage_count = Column(Integer, default=0)
    
    # Временные метки
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

class ServerMetrics(Base):
    """Модель метрик сервера"""
    __tablename__ = "server_metrics"
    
    id = Column(Integer, primary_key=True, index=True)
    server_id = Column(Integer, ForeignKey("servers.id"), nullable=False)
    
    # Метрики
    cpu_usage = Column(Float, nullable=False)
    memory_usage = Column(Float, nullable=False)
    disk_usage = Column(Float, nullable=False)
    connection_count = Column(Integer, nullable=False)
    bandwidth_usage = Column(Float, nullable=False)
    
    # Временная метка
    timestamp = Column(DateTime, default=func.now())
    
    # Связи
    server = relationship("Server")

class ConfigUsage(Base):
    """Модель использования конфигурации"""
    __tablename__ = "config_usage"
    
    id = Column(Integer, primary_key=True, index=True)
    config_id = Column(Integer, ForeignKey("configs.id"), nullable=False)
    
    # Использование
    bytes_uploaded = Column(Integer, default=0)
    bytes_downloaded = Column(Integer, default=0)
    connection_time = Column(Integer, default=0)  # в секундах
    
    # Временная метка
    timestamp = Column(DateTime, default=func.now())
    
    # Связи
    config = relationship("Config")
