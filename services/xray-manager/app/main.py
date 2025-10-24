from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager
import uvicorn
import logging
from typing import List, Optional

from app.config import settings
from app.database import engine, SessionLocal
from app.models import Base
from app.api import servers, configs, sni
from app.services.xray_service import XrayService
from app.services.sni_service import SNIService
from app.utils.metrics import setup_metrics

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Создание таблиц БД
Base.metadata.create_all(bind=engine)

# Инициализация сервисов
xray_service = XrayService()
sni_service = SNIService()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения"""
    logger.info("Запуск Xray Manager сервиса...")
    
    # Инициализация сервисов
    await xray_service.initialize()
    await sni_service.initialize()
    
    # Настройка метрик
    setup_metrics()
    
    logger.info("Xray Manager сервис запущен")
    yield
    
    logger.info("Остановка Xray Manager сервиса...")
    await xray_service.cleanup()
    await sni_service.cleanup()
    logger.info("Xray Manager сервис остановлен")

# Создание FastAPI приложения
app = FastAPI(
    title="Xray Manager API",
    description="Микросервис для управления Xray конфигурациями и SNI маскировкой",
    version="1.0.0",
    lifespan=lifespan
)

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.ALLOWED_HOSTS
)

# Подключение роутеров
app.include_router(servers.router, prefix="/api/v1/servers", tags=["servers"])
app.include_router(configs.router, prefix="/api/v1/configs", tags=["configs"])
app.include_router(sni.router, prefix="/api/v1/sni", tags=["sni"])

@app.get("/")
async def root():
    """Корневой endpoint"""
    return {
        "service": "Xray Manager",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Проверка подключения к БД
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
        
        # Проверка статуса сервисов
        servers_status = await xray_service.get_servers_status()
        sni_status = await sni_service.get_sni_status()
        
        return {
            "status": "healthy",
            "database": "connected",
            "servers": servers_status,
            "sni": sni_status,
            "timestamp": "2024-01-01T00:00:00Z"
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Service unhealthy")

@app.get("/metrics")
async def metrics():
    """Prometheus метрики"""
    from app.utils.metrics import get_metrics
    return get_metrics()

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="info"
    )
