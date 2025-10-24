#!/usr/bin/env python3
"""
Скрипт инициализации базы данных для Xray VLESS + Reality сервиса
"""

import asyncio
import logging
import sys
import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Добавляем путь к проекту
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.xray-manager.app.models import Base
from services.xray-manager.app.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_database():
    """Создание базы данных"""
    try:
        # Подключение к PostgreSQL без указания базы данных
        engine = create_engine(
            settings.DATABASE_URL.replace("/xray_service", "/postgres"),
            isolation_level="AUTOCOMMIT"
        )
        
        with engine.connect() as conn:
            # Проверка существования базы данных
            result = conn.execute(text(
                "SELECT 1 FROM pg_database WHERE datname = 'xray_service'"
            ))
            
            if not result.fetchone():
                # Создание базы данных
                conn.execute(text("CREATE DATABASE xray_service"))
                logger.info("База данных 'xray_service' создана")
            else:
                logger.info("База данных 'xray_service' уже существует")
        
        engine.dispose()
        
    except Exception as e:
        logger.error(f"Ошибка создания базы данных: {e}")
        raise

def create_tables():
    """Создание таблиц"""
    try:
        # Подключение к созданной базе данных
        engine = create_engine(settings.DATABASE_URL)
        
        # Создание всех таблиц
        Base.metadata.create_all(bind=engine)
        logger.info("Таблицы созданы успешно")
        
        engine.dispose()
        
    except Exception as e:
        logger.error(f"Ошибка создания таблиц: {e}")
        raise

def create_initial_data():
    """Создание начальных данных"""
    try:
        engine = create_engine(settings.DATABASE_URL)
        SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
        
        db = SessionLocal()
        try:
            # Проверка существования данных
            from services.xray-manager.app.models import Server, SNIDomain
            
            # Проверка серверов
            servers_count = db.query(Server).count()
            if servers_count == 0:
                logger.info("Создание начальных серверов...")
                # Здесь можно добавить создание начальных серверов
                pass
            
            # Проверка SNI доменов
            domains_count = db.query(SNIDomain).count()
            if domains_count == 0:
                logger.info("Создание начальных SNI доменов...")
                initial_domains = [
                    "vk.com",
                    "yandex.ru", 
                    "sberbank.ru",
                    "mail.ru",
                    "ok.ru"
                ]
                
                for domain in initial_domains:
                    sni_domain = SNIDomain(domain=domain)
                    db.add(sni_domain)
                
                db.commit()
                logger.info(f"Создано {len(initial_domains)} SNI доменов")
            
            logger.info("Начальные данные созданы")
            
        finally:
            db.close()
        
        engine.dispose()
        
    except Exception as e:
        logger.error(f"Ошибка создания начальных данных: {e}")
        raise

def create_indexes():
    """Создание индексов для оптимизации"""
    try:
        engine = create_engine(settings.DATABASE_URL)
        
        with engine.connect() as conn:
            # Индексы для таблицы users
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_users_telegram_id 
                ON users(telegram_id);
            """))
            
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_users_created_at 
                ON users(created_at);
            """))
            
            # Индексы для таблицы servers
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_servers_status 
                ON servers(status);
            """))
            
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_servers_is_healthy 
                ON servers(is_healthy);
            """))
            
            # Индексы для таблицы configs
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_configs_user_id 
                ON configs(user_id);
            """))
            
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_configs_server_id 
                ON configs(server_id);
            """))
            
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_configs_status 
                ON configs(status);
            """))
            
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_configs_expires_at 
                ON configs(expires_at);
            """))
            
            # Индексы для таблицы payments
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_payments_user_id 
                ON payments(user_id);
            """))
            
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_payments_status 
                ON payments(status);
            """))
            
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_payments_created_at 
                ON payments(created_at);
            """))
            
            # Индексы для таблицы subscriptions
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id 
                ON subscriptions(user_id);
            """))
            
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_subscriptions_status 
                ON subscriptions(status);
            """))
            
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_subscriptions_end_date 
                ON subscriptions(end_date);
            """))
            
            conn.commit()
            
        logger.info("Индексы созданы успешно")
        engine.dispose()
        
    except Exception as e:
        logger.error(f"Ошибка создания индексов: {e}")
        raise

def main():
    """Основная функция"""
    logger.info("Начало инициализации базы данных...")
    
    try:
        # Создание базы данных
        create_database()
        
        # Создание таблиц
        create_tables()
        
        # Создание индексов
        create_indexes()
        
        # Создание начальных данных
        create_initial_data()
        
        logger.info("Инициализация базы данных завершена успешно!")
        
    except Exception as e:
        logger.error(f"Ошибка инициализации базы данных: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
