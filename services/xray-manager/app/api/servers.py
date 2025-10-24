from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List, Optional
import logging

from app.database import get_db
from app.schemas import (
    ServerCreate, ServerUpdate, ServerResponse, 
    PaginationParams, PaginatedResponse, MessageResponse
)
from app.services.xray_service import XrayService
from app.models import Server

logger = logging.getLogger(__name__)
router = APIRouter()

# Инициализация сервиса
xray_service = XrayService()

@router.get("/", response_model=PaginatedResponse)
async def get_servers(
    pagination: PaginationParams = Depends(),
    status: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Получить список серверов с пагинацией"""
    try:
        query = db.query(Server)
        
        # Фильтрация по статусу
        if status:
            query = query.filter(Server.status == status)
        
        # Подсчет общего количества
        total = query.count()
        
        # Пагинация
        offset = (pagination.page - 1) * pagination.size
        servers = query.offset(offset).limit(pagination.size).all()
        
        # Преобразование в словари
        items = [ServerResponse.from_orm(server).dict() for server in servers]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=pagination.page,
            size=pagination.size,
            pages=(total + pagination.size - 1) // pagination.size
        )
    except Exception as e:
        logger.error(f"Ошибка получения серверов: {e}")
        raise HTTPException(status_code=500, detail="Ошибка получения серверов")

@router.get("/{server_id}", response_model=ServerResponse)
async def get_server(server_id: str, db: Session = Depends(get_db)):
    """Получить информацию о сервере"""
    try:
        server = db.query(Server).filter(Server.server_id == server_id).first()
        if not server:
            raise HTTPException(status_code=404, detail="Сервер не найден")
        
        return ServerResponse.from_orm(server)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка получения сервера {server_id}: {e}")
        raise HTTPException(status_code=500, detail="Ошибка получения сервера")

@router.post("/", response_model=ServerResponse)
async def create_server(
    server_data: ServerCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Создать новый сервер"""
    try:
        # Проверка существования сервера
        existing_server = db.query(Server).filter(
            Server.host == server_data.host,
            Server.port == server_data.port
        ).first()
        
        if existing_server:
            raise HTTPException(
                status_code=400, 
                detail="Сервер с таким хостом и портом уже существует"
            )
        
        # Создание сервера
        server = Server(
            server_id=f"server-{len(db.query(Server).all()) + 1}",
            name=server_data.name,
            host=server_data.host,
            port=server_data.port,
            reality_private_key=server_data.reality_private_key,
            reality_public_key=server_data.reality_public_key,
            reality_short_id=server_data.reality_short_id
        )
        
        db.add(server)
        db.commit()
        db.refresh(server)
        
        # Запуск проверки здоровья в фоне
        background_tasks.add_task(xray_service.check_server_health, server.id)
        
        logger.info(f"Создан новый сервер: {server.server_id}")
        return ServerResponse.from_orm(server)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка создания сервера: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Ошибка создания сервера")

@router.put("/{server_id}", response_model=ServerResponse)
async def update_server(
    server_id: str,
    server_data: ServerUpdate,
    db: Session = Depends(get_db)
):
    """Обновить сервер"""
    try:
        server = db.query(Server).filter(Server.server_id == server_id).first()
        if not server:
            raise HTTPException(status_code=404, detail="Сервер не найден")
        
        # Обновление полей
        update_data = server_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(server, field, value)
        
        db.commit()
        db.refresh(server)
        
        logger.info(f"Обновлен сервер: {server_id}")
        return ServerResponse.from_orm(server)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка обновления сервера {server_id}: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Ошибка обновления сервера")

@router.delete("/{server_id}", response_model=MessageResponse)
async def delete_server(server_id: str, db: Session = Depends(get_db)):
    """Удалить сервер"""
    try:
        server = db.query(Server).filter(Server.server_id == server_id).first()
        if not server:
            raise HTTPException(status_code=404, detail="Сервер не найден")
        
        # Проверка наличия активных конфигураций
        active_configs = db.query(Config).filter(
            Config.server_id == server.id,
            Config.status == "active"
        ).count()
        
        if active_configs > 0:
            raise HTTPException(
                status_code=400,
                detail=f"Нельзя удалить сервер с {active_configs} активными конфигурациями"
            )
        
        db.delete(server)
        db.commit()
        
        logger.info(f"Удален сервер: {server_id}")
        return MessageResponse(message=f"Сервер {server_id} успешно удален")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка удаления сервера {server_id}: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Ошибка удаления сервера")

@router.post("/{server_id}/restart", response_model=MessageResponse)
async def restart_server(
    server_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Перезапустить сервер"""
    try:
        server = db.query(Server).filter(Server.server_id == server_id).first()
        if not server:
            raise HTTPException(status_code=404, detail="Сервер не найден")
        
        # Запуск перезапуска в фоне
        background_tasks.add_task(xray_service.restart_server, server.id)
        
        logger.info(f"Запущен перезапуск сервера: {server_id}")
        return MessageResponse(message=f"Перезапуск сервера {server_id} запущен")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка перезапуска сервера {server_id}: {e}")
        raise HTTPException(status_code=500, detail="Ошибка перезапуска сервера")

@router.get("/{server_id}/status", response_model=dict)
async def get_server_status(server_id: str, db: Session = Depends(get_db)):
    """Получить статус сервера"""
    try:
        server = db.query(Server).filter(Server.server_id == server_id).first()
        if not server:
            raise HTTPException(status_code=404, detail="Сервер не найден")
        
        # Получение детального статуса
        status = await xray_service.get_server_detailed_status(server.id)
        
        return {
            "server_id": server_id,
            "status": server.status,
            "is_healthy": server.is_healthy,
            "last_health_check": server.last_health_check,
            "metrics": {
                "cpu_usage": server.cpu_usage,
                "memory_usage": server.memory_usage,
                "connection_count": server.connection_count,
                "bandwidth_usage": server.bandwidth_usage
            },
            "detailed_status": status
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка получения статуса сервера {server_id}: {e}")
        raise HTTPException(status_code=500, detail="Ошибка получения статуса сервера")

@router.get("/{server_id}/metrics", response_model=List[dict])
async def get_server_metrics(
    server_id: str,
    hours: int = 24,
    db: Session = Depends(get_db)
):
    """Получить метрики сервера за период"""
    try:
        server = db.query(Server).filter(Server.server_id == server_id).first()
        if not server:
            raise HTTPException(status_code=404, detail="Сервер не найден")
        
        # Получение метрик за период
        metrics = await xray_service.get_server_metrics(server.id, hours)
        
        return metrics
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка получения метрик сервера {server_id}: {e}")
        raise HTTPException(status_code=500, detail="Ошибка получения метрик сервера")
