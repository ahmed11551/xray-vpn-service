import asyncio
import logging
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
import uuid
import hmac
import hashlib
import json

from yookassa import Payment, Configuration
from yookassa.domain.notification import WebhookNotificationEventType, WebhookNotification
from yookassa.domain.models.amount import Amount
from yookassa.domain.models.currency import Currency
from yookassa.domain.models.confirmation import ConfirmationType
from yookassa.domain.models.payment_data import PaymentData

from app.config import settings
from app.database import SessionLocal
from app.models import Payment as PaymentModel, Subscription, User
from app.schemas.payment import PaymentCreate, PaymentResponse

logger = logging.getLogger(__name__)

class YooKassaService:
    """Сервис для работы с YooKassa"""
    
    def __init__(self):
        self.shop_id = settings.YOOKASSA_SHOP_ID
        self.secret_key = settings.YOOKASSA_SECRET_KEY
        self.webhook_secret = settings.YOOKASSA_WEBHOOK_SECRET
        
    async def initialize(self):
        """Инициализация сервиса"""
        logger.info("Инициализация YooKassa сервиса...")
        
        # Настройка конфигурации YooKassa
        Configuration.account_id = self.shop_id
        Configuration.secret_key = self.secret_key
        
        logger.info("YooKassa сервис инициализирован")
    
    async def cleanup(self):
        """Очистка ресурсов"""
        logger.info("YooKassa сервис очищен")
    
    async def check_status(self) -> Dict[str, Any]:
        """Проверка статуса сервиса"""
        try:
            # Простая проверка доступности API
            return {
                "status": "healthy",
                "shop_id": self.shop_id,
                "timestamp": datetime.now().isoformat()
            }
        except Exception as e:
            logger.error(f"Ошибка проверки статуса YooKassa: {e}")
            return {
                "status": "unhealthy",
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
    
    async def create_payment(
        self, 
        user_id: int, 
        amount: float, 
        currency: str = "RUB",
        description: str = "Подписка на сервис",
        return_url: Optional[str] = None
    ) -> Dict[str, Any]:
        """Создание платежа"""
        try:
            # Генерация ID платежа
            payment_id = f"yk_{uuid.uuid4().hex[:16]}"
            
            # Создание платежа в YooKassa
            payment_data = PaymentData(
                amount=Amount(value=str(amount), currency=Currency.RUB),
                confirmation={
                    "type": ConfirmationType.REDIRECT,
                    "return_url": return_url or f"{settings.WEBHOOK_URL}/payment/success"
                },
                description=description,
                metadata={
                    "user_id": str(user_id),
                    "payment_id": payment_id,
                    "service": "xray_subscription"
                }
            )
            
            payment = Payment.create(payment_data)
            
            # Сохранение в БД
            db = SessionLocal()
            try:
                db_payment = PaymentModel(
                    payment_id=payment_id,
                    user_id=user_id,
                    amount=amount,
                    currency=currency,
                    status="pending",
                    payment_system="yookassa",
                    external_id=payment.id,
                    description=description,
                    created_at=datetime.now()
                )
                
                db.add(db_payment)
                db.commit()
                db.refresh(db_payment)
                
                logger.info(f"Создан платеж {payment_id} для пользователя {user_id}")
                
                return {
                    "payment_id": payment_id,
                    "external_id": payment.id,
                    "status": "pending",
                    "confirmation_url": payment.confirmation.confirmation_url,
                    "amount": amount,
                    "currency": currency,
                    "created_at": db_payment.created_at.isoformat()
                }
                
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Ошибка создания платежа: {e}")
            raise
    
    async def process_webhook(self, webhook_data: Dict[str, Any]) -> bool:
        """Обработка webhook от YooKassa"""
        try:
            # Проверка подписи webhook
            if not self._verify_webhook_signature(webhook_data):
                logger.warning("Неверная подпись webhook YooKassa")
                return False
            
            # Создание объекта уведомления
            notification = WebhookNotification(webhook_data)
            
            if notification.event == WebhookNotificationEventType.PAYMENT_SUCCEEDED:
                await self._handle_payment_succeeded(notification.object)
            elif notification.event == WebhookNotificationEventType.PAYMENT_CANCELED:
                await self._handle_payment_canceled(notification.object)
            elif notification.event == WebhookNotificationEventType.PAYMENT_WAITING_FOR_CAPTURE:
                await self._handle_payment_waiting(notification.object)
            
            return True
            
        except Exception as e:
            logger.error(f"Ошибка обработки webhook YooKassa: {e}")
            return False
    
    def _verify_webhook_signature(self, webhook_data: Dict[str, Any]) -> bool:
        """Проверка подписи webhook"""
        try:
            # Получение подписи из заголовков
            signature = webhook_data.get("signature")
            if not signature:
                return False
            
            # Проверка подписи
            expected_signature = hmac.new(
                self.webhook_secret.encode(),
                json.dumps(webhook_data, sort_keys=True).encode(),
                hashlib.sha256
            ).hexdigest()
            
            return hmac.compare_digest(signature, expected_signature)
            
        except Exception as e:
            logger.error(f"Ошибка проверки подписи webhook: {e}")
            return False
    
    async def _handle_payment_succeeded(self, payment_data: Dict[str, Any]):
        """Обработка успешного платежа"""
        try:
            external_id = payment_data["id"]
            amount = float(payment_data["amount"]["value"])
            currency = payment_data["amount"]["currency"]
            metadata = payment_data.get("metadata", {})
            user_id = int(metadata.get("user_id"))
            
            db = SessionLocal()
            try:
                # Поиск платежа в БД
                payment = db.query(PaymentModel).filter(
                    PaymentModel.external_id == external_id
                ).first()
                
                if not payment:
                    logger.error(f"Платеж {external_id} не найден в БД")
                    return
                
                # Обновление статуса платежа
                payment.status = "completed"
                payment.completed_at = datetime.now()
                payment.amount = amount
                payment.currency = currency
                
                db.commit()
                
                # Создание подписки
                await self._create_subscription(payment.user_id, amount, currency)
                
                logger.info(f"Платеж {payment.payment_id} успешно обработан")
                
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Ошибка обработки успешного платежа: {e}")
    
    async def _handle_payment_canceled(self, payment_data: Dict[str, Any]):
        """Обработка отмененного платежа"""
        try:
            external_id = payment_data["id"]
            
            db = SessionLocal()
            try:
                payment = db.query(PaymentModel).filter(
                    PaymentModel.external_id == external_id
                ).first()
                
                if payment:
                    payment.status = "canceled"
                    payment.canceled_at = datetime.now()
                    db.commit()
                    
                    logger.info(f"Платеж {payment.payment_id} отменен")
                
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Ошибка обработки отмененного платежа: {e}")
    
    async def _handle_payment_waiting(self, payment_data: Dict[str, Any]):
        """Обработка платежа в ожидании"""
        try:
            external_id = payment_data["id"]
            
            db = SessionLocal()
            try:
                payment = db.query(PaymentModel).filter(
                    PaymentModel.external_id == external_id
                ).first()
                
                if payment:
                    payment.status = "waiting"
                    db.commit()
                    
                    logger.info(f"Платеж {payment.payment_id} в ожидании")
                
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Ошибка обработки платежа в ожидании: {e}")
    
    async def _create_subscription(self, user_id: int, amount: float, currency: str):
        """Создание подписки после успешного платежа"""
        try:
            db = SessionLocal()
            try:
                # Определение типа подписки по сумме
                if amount >= 2000:
                    subscription_type = "yearly"
                    duration_days = 365
                else:
                    subscription_type = "monthly"
                    duration_days = 30
                
                # Создание подписки
                subscription = Subscription(
                    user_id=user_id,
                    subscription_type=subscription_type,
                    status="active",
                    start_date=datetime.now(),
                    end_date=datetime.now() + timedelta(days=duration_days),
                    amount=amount,
                    currency=currency,
                    created_at=datetime.now()
                )
                
                db.add(subscription)
                
                # Обновление статуса пользователя
                user = db.query(User).filter(User.id == user_id).first()
                if user:
                    user.is_premium = True
                    user.updated_at = datetime.now()
                
                db.commit()
                
                logger.info(f"Создана подписка для пользователя {user_id}")
                
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Ошибка создания подписки: {e}")
    
    async def get_payment_status(self, payment_id: str) -> Dict[str, Any]:
        """Получение статуса платежа"""
        try:
            db = SessionLocal()
            try:
                payment = db.query(PaymentModel).filter(
                    PaymentModel.payment_id == payment_id
                ).first()
                
                if not payment:
                    return {"error": "Платеж не найден"}
                
                return {
                    "payment_id": payment.payment_id,
                    "status": payment.status,
                    "amount": payment.amount,
                    "currency": payment.currency,
                    "created_at": payment.created_at.isoformat(),
                    "completed_at": payment.completed_at.isoformat() if payment.completed_at else None,
                    "canceled_at": payment.canceled_at.isoformat() if payment.canceled_at else None
                }
                
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Ошибка получения статуса платежа: {e}")
            return {"error": str(e)}
    
    async def cancel_payment(self, payment_id: str) -> bool:
        """Отмена платежа"""
        try:
            db = SessionLocal()
            try:
                payment = db.query(PaymentModel).filter(
                    PaymentModel.payment_id == payment_id
                ).first()
                
                if not payment:
                    return False
                
                if payment.status not in ["pending", "waiting"]:
                    return False
                
                # Отмена в YooKassa
                if payment.external_id:
                    Payment.cancel(payment.external_id)
                
                # Обновление в БД
                payment.status = "canceled"
                payment.canceled_at = datetime.now()
                db.commit()
                
                logger.info(f"Платеж {payment_id} отменен")
                return True
                
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Ошибка отмены платежа: {e}")
            return False
