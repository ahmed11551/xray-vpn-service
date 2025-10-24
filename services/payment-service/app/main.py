from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
import logging
from typing import List, Optional

from app.config import settings
from app.database import engine, SessionLocal
from app.models import Base
from app.api import payments, subscriptions, webhooks
from app.services.yookassa_service import YooKassaService
from app.services.robokassa_service import RobokassaService
from app.services.crypto_service import CryptoService
from app.services.subscription_service import SubscriptionService
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
yookassa_service = YooKassaService()
robokassa_service = RobokassaService()
crypto_service = CryptoService()
subscription_service = SubscriptionService()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения"""
    logger.info("Запуск Payment Service...")
    
    # Инициализация сервисов
    await yookassa_service.initialize()
    await robokassa_service.initialize()
    await crypto_service.initialize()
    await subscription_service.initialize()
    
    # Настройка метрик
    setup_metrics()
    
    logger.info("Payment Service запущен")
    yield
    
    logger.info("Остановка Payment Service...")
    await yookassa_service.cleanup()
    await robokassa_service.cleanup()
    await crypto_service.cleanup()
    await subscription_service.cleanup()
    logger.info("Payment Service остановлен")

# Создание FastAPI приложения
app = FastAPI(
    title="Payment Service API",
    description="Микросервис для обработки платежей и управления подписками",
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

# Подключение роутеров
app.include_router(payments.router, prefix="/api/v1/payments", tags=["payments"])
app.include_router(subscriptions.router, prefix="/api/v1/subscriptions", tags=["subscriptions"])
app.include_router(webhooks.router, prefix="/webhook", tags=["webhooks"])

@app.get("/")
async def root():
    """Корневой endpoint"""
    return {
        "service": "Payment Service",
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
        
        # Проверка статуса платежных систем
        yookassa_status = await yookassa_service.check_status()
        robokassa_status = await robokassa_service.check_status()
        crypto_status = await crypto_service.check_status()
        
        return {
            "status": "healthy",
            "database": "connected",
            "payment_systems": {
                "yookassa": yookassa_status,
                "robokassa": robokassa_status,
                "crypto": crypto_status
            },
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

@app.get("/api/v1/stats/payments")
async def get_payments_stats():
    """Статистика платежей"""
    try:
        stats = await subscription_service.get_payments_stats()
        return stats
    except Exception as e:
        logger.error(f"Ошибка получения статистики платежей: {e}")
        raise HTTPException(status_code=500, detail="Ошибка получения статистики")

@app.get("/api/v1/stats/subscriptions")
async def get_subscriptions_stats():
    """Статистика подписок"""
    try:
        stats = await subscription_service.get_subscriptions_stats()
        return stats
    except Exception as e:
        logger.error(f"Ошибка получения статистики подписок: {e}")
        raise HTTPException(status_code=500, detail="Ошибка получения статистики")

@app.get("/api/v1/stats/revenue")
async def get_revenue_stats():
    """Статистика доходов"""
    try:
        stats = await subscription_service.get_revenue_stats()
        return stats
    except Exception as e:
        logger.error(f"Ошибка получения статистики доходов: {e}")
        raise HTTPException(status_code=500, detail="Ошибка получения статистики")

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8002,
        reload=settings.DEBUG,
        log_level="info"
    )
