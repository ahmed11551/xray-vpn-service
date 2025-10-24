import asyncio
import json
import uuid
import logging
from typing import List, Dict, Optional, Any
from datetime import datetime, timedelta
import subprocess
import os
import yaml

from app.config import settings
from app.database import SessionLocal
from app.models import Server, Config, SNIDomain, ServerMetrics
from app.schemas import ServerCreate, ConfigCreate

logger = logging.getLogger(__name__)

class XrayService:
    """Сервис для управления Xray серверами"""
    
    def __init__(self):
        self.servers = {}
        self.config_templates = {}
        self.sni_domains = []
        
    async def initialize(self):
        """Инициализация сервиса"""
        logger.info("Инициализация Xray сервиса...")
        
        # Загрузка конфигурации
        await self._load_config()
        
        # Инициализация серверов
        await self._initialize_servers()
        
        # Загрузка SNI доменов
        await self._load_sni_domains()
        
        logger.info("Xray сервис инициализирован")
    
    async def cleanup(self):
        """Очистка ресурсов"""
        logger.info("Очистка Xray сервиса...")
        
        # Остановка мониторинга
        for server_id in self.servers:
            await self._stop_server_monitoring(server_id)
        
        logger.info("Xray сервис очищен")
    
    async def _load_config(self):
        """Загрузка конфигурации"""
        try:
            config_path = os.path.join(settings.XRAY_CONFIG_DIR, "config.yaml")
            if os.path.exists(config_path):
                with open(config_path, 'r') as f:
                    config = yaml.safe_load(f)
                    self.config_templates = config.get('templates', {})
                    self.sni_domains = config.get('sni_domains', settings.SNI_DOMAINS)
            else:
                # Создание базовой конфигурации
                await self._create_default_config()
                
        except Exception as e:
            logger.error(f"Ошибка загрузки конфигурации: {e}")
            await self._create_default_config()
    
    async def _create_default_config(self):
        """Создание базовой конфигурации"""
        config = {
            'templates': {
                'vless_reality': {
                    'protocol': 'vless',
                    'security': 'reality',
                    'network': 'tcp'
                }
            },
            'sni_domains': settings.SNI_DOMAINS
        }
        
        os.makedirs(settings.XRAY_CONFIG_DIR, exist_ok=True)
        config_path = os.path.join(settings.XRAY_CONFIG_DIR, "config.yaml")
        
        with open(config_path, 'w') as f:
            yaml.dump(config, f)
        
        self.config_templates = config['templates']
        self.sni_domains = config['sni_domains']
    
    async def _initialize_servers(self):
        """Инициализация серверов из БД"""
        db = SessionLocal()
        try:
            servers = db.query(Server).filter(Server.status == "active").all()
            for server in servers:
                await self._add_server_to_memory(server)
        finally:
            db.close()
    
    async def _add_server_to_memory(self, server: Server):
        """Добавление сервера в память"""
        self.servers[server.server_id] = {
            'id': server.id,
            'host': server.host,
            'port': server.port,
            'uuid': server.uuid,
            'reality_private_key': server.reality_private_key,
            'reality_public_key': server.reality_public_key,
            'reality_short_id': server.reality_short_id,
            'status': server.status,
            'is_healthy': server.is_healthy
        }
        
        # Запуск мониторинга
        await self._start_server_monitoring(server.server_id)
    
    async def _start_server_monitoring(self, server_id: str):
        """Запуск мониторинга сервера"""
        # Здесь можно добавить логику мониторинга
        logger.info(f"Запущен мониторинг сервера: {server_id}")
    
    async def _stop_server_monitoring(self, server_id: str):
        """Остановка мониторинга сервера"""
        logger.info(f"Остановлен мониторинг сервера: {server_id}")
    
    async def _load_sni_domains(self):
        """Загрузка SNI доменов"""
        db = SessionLocal()
        try:
            domains = db.query(SNIDomain).filter(SNIDomain.is_active == True).all()
            self.sni_domains = [domain.domain for domain in domains]
        finally:
            db.close()
    
    async def get_servers_status(self) -> Dict[str, Any]:
        """Получить статус всех серверов"""
        db = SessionLocal()
        try:
            servers = db.query(Server).all()
            status = {
                'total': len(servers),
                'active': len([s for s in servers if s.status == 'active']),
                'healthy': len([s for s in servers if s.is_healthy]),
                'servers': []
            }
            
            for server in servers:
                status['servers'].append({
                    'id': server.server_id,
                    'name': server.name,
                    'status': server.status,
                    'is_healthy': server.is_healthy,
                    'cpu_usage': server.cpu_usage,
                    'memory_usage': server.memory_usage,
                    'connection_count': server.connection_count
                })
            
            return status
        finally:
            db.close()
    
    async def get_server_detailed_status(self, server_id: int) -> Dict[str, Any]:
        """Получить детальный статус сервера"""
        db = SessionLocal()
        try:
            server = db.query(Server).filter(Server.id == server_id).first()
            if not server:
                return {}
            
            # Проверка доступности сервера
            is_reachable = await self._check_server_reachability(server.host, server.port)
            
            # Получение метрик
            metrics = await self._get_server_metrics(server_id)
            
            return {
                'server_id': server.server_id,
                'host': server.host,
                'port': server.port,
                'is_reachable': is_reachable,
                'is_healthy': server.is_healthy,
                'status': server.status,
                'last_health_check': server.last_health_check,
                'metrics': metrics
            }
        finally:
            db.close()
    
    async def _check_server_reachability(self, host: str, port: int) -> bool:
        """Проверка доступности сервера"""
        try:
            # Простая проверка TCP соединения
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((host, port))
            sock.close()
            return result == 0
        except Exception as e:
            logger.error(f"Ошибка проверки доступности {host}:{port}: {e}")
            return False
    
    async def _get_server_metrics(self, server_id: int) -> Dict[str, Any]:
        """Получить метрики сервера"""
        db = SessionLocal()
        try:
            # Получение последних метрик
            metrics = db.query(ServerMetrics).filter(
                ServerMetrics.server_id == server_id
            ).order_by(ServerMetrics.timestamp.desc()).first()
            
            if metrics:
                return {
                    'cpu_usage': metrics.cpu_usage,
                    'memory_usage': metrics.memory_usage,
                    'disk_usage': metrics.disk_usage,
                    'connection_count': metrics.connection_count,
                    'bandwidth_usage': metrics.bandwidth_usage,
                    'timestamp': metrics.timestamp
                }
            else:
                return {
                    'cpu_usage': 0.0,
                    'memory_usage': 0.0,
                    'disk_usage': 0.0,
                    'connection_count': 0,
                    'bandwidth_usage': 0.0,
                    'timestamp': datetime.now()
                }
        finally:
            db.close()
    
    async def get_server_metrics(self, server_id: int, hours: int = 24) -> List[Dict[str, Any]]:
        """Получить метрики сервера за период"""
        db = SessionLocal()
        try:
            since = datetime.now() - timedelta(hours=hours)
            metrics = db.query(ServerMetrics).filter(
                ServerMetrics.server_id == server_id,
                ServerMetrics.timestamp >= since
            ).order_by(ServerMetrics.timestamp.asc()).all()
            
            return [
                {
                    'timestamp': metric.timestamp,
                    'cpu_usage': metric.cpu_usage,
                    'memory_usage': metric.memory_usage,
                    'disk_usage': metric.disk_usage,
                    'connection_count': metric.connection_count,
                    'bandwidth_usage': metric.bandwidth_usage
                }
                for metric in metrics
            ]
        finally:
            db.close()
    
    async def check_server_health(self, server_id: int):
        """Проверка здоровья сервера"""
        db = SessionLocal()
        try:
            server = db.query(Server).filter(Server.id == server_id).first()
            if not server:
                return
            
            # Проверка доступности
            is_reachable = await self._check_server_reachability(server.host, server.port)
            
            # Обновление статуса
            server.is_healthy = is_reachable
            server.last_health_check = datetime.now()
            
            if is_reachable:
                # Получение метрик (здесь можно добавить реальный мониторинг)
                server.cpu_usage = 0.0  # Заглушка
                server.memory_usage = 0.0  # Заглушка
                server.connection_count = 0  # Заглушка
            
            db.commit()
            
            logger.info(f"Проверка здоровья сервера {server.server_id}: {'OK' if is_reachable else 'FAIL'}")
            
        except Exception as e:
            logger.error(f"Ошибка проверки здоровья сервера {server_id}: {e}")
            db.rollback()
        finally:
            db.close()
    
    async def restart_server(self, server_id: int):
        """Перезапуск сервера"""
        db = SessionLocal()
        try:
            server = db.query(Server).filter(Server.id == server_id).first()
            if not server:
                return
            
            # Здесь можно добавить логику перезапуска Xray сервиса
            # Например, через systemctl или docker
            
            logger.info(f"Перезапуск сервера {server.server_id}")
            
            # Обновление статуса
            server.status = "maintenance"
            db.commit()
            
            # Симуляция перезапуска
            await asyncio.sleep(5)
            
            server.status = "active"
            server.is_healthy = True
            server.last_health_check = datetime.now()
            db.commit()
            
            logger.info(f"Сервер {server.server_id} перезапущен")
            
        except Exception as e:
            logger.error(f"Ошибка перезапуска сервера {server_id}: {e}")
            db.rollback()
        finally:
            db.close()
    
    async def generate_config(self, user_id: int, server_id: Optional[int] = None) -> Dict[str, Any]:
        """Генерация конфигурации для пользователя"""
        db = SessionLocal()
        try:
            # Выбор сервера
            if server_id:
                server = db.query(Server).filter(Server.id == server_id).first()
            else:
                # Выбор наименее загруженного сервера
                server = db.query(Server).filter(
                    Server.status == "active",
                    Server.is_healthy == True
                ).order_by(Server.connection_count.asc()).first()
            
            if not server:
                raise Exception("Нет доступных серверов")
            
            # Выбор SNI домена
            sni_domain = await self._get_best_sni_domain()
            
            # Генерация конфигурации
            config_data = await self._create_vless_reality_config(
                server, sni_domain
            )
            
            # Создание записи в БД
            config = Config(
                config_id=f"config-{uuid.uuid4().hex[:8]}",
                user_id=user_id,
                server_id=server.id,
                config_data=json.dumps(config_data),
                config_url=self._generate_vless_url(config_data),
                sni_domain=sni_domain,
                sni_dest=f"{sni_domain}:443"
            )
            
            db.add(config)
            db.commit()
            db.refresh(config)
            
            logger.info(f"Создана конфигурация {config.config_id} для пользователя {user_id}")
            
            return {
                'config_id': config.config_id,
                'config_data': config_data,
                'config_url': config.config_url,
                'server_id': server.server_id,
                'sni_domain': sni_domain
            }
            
        except Exception as e:
            logger.error(f"Ошибка генерации конфигурации: {e}")
            db.rollback()
            raise
        finally:
            db.close()
    
    async def _get_best_sni_domain(self) -> str:
        """Выбор лучшего SNI домена"""
        # Здесь можно добавить логику выбора домена
        # на основе латентности и доступности
        return self.sni_domains[0] if self.sni_domains else "vk.com"
    
    async def _create_vless_reality_config(self, server: Server, sni_domain: str) -> Dict[str, Any]:
        """Создание VLESS + Reality конфигурации"""
        config = {
            "v": "2",
            "ps": f"Xray-{server.name}",
            "add": server.host,
            "port": str(server.port),
            "id": server.uuid,
            "aid": "0",
            "scy": "auto",
            "net": "tcp",
            "type": "none",
            "host": sni_domain,
            "sni": sni_domain,
            "alpn": "",
            "fp": "chrome",
            "security": "reality",
            "pbk": server.reality_public_key,
            "sid": server.reality_short_id,
            "spx": ""
        }
        return config
    
    def _generate_vless_url(self, config_data: Dict[str, Any]) -> str:
        """Генерация VLESS URL"""
        import base64
        
        # Создание строки конфигурации
        config_str = f"vless://{config_data['id']}@{config_data['add']}:{config_data['port']}"
        config_str += f"?encryption=none&security={config_data['security']}"
        config_str += f"&type={config_data['net']}&host={config_data['host']}"
        config_str += f"&sni={config_data['sni']}&pbk={config_data['pbk']}"
        config_str += f"&sid={config_data['sid']}&fp={config_data['fp']}"
        config_str += f"#{config_data['ps']}"
        
        return config_str
