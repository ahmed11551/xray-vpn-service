#!/usr/bin/env python3
"""
Скрипт для генерации Reality ключей для Xray серверов
"""

import subprocess
import json
import uuid
import logging
import sys
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def generate_reality_keys():
    """Генерация Reality ключей"""
    try:
        # Проверка наличия xray
        result = subprocess.run(['xray', '--version'], 
                              capture_output=True, text=True)
        if result.returncode != 0:
            logger.error("Xray не установлен или недоступен")
            return None
        
        # Генерация ключей
        result = subprocess.run(['xray', 'x25519'], 
                              capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"Ошибка генерации ключей: {result.stderr}")
            return None
        
        # Парсинг вывода
        output = result.stdout.strip()
        lines = output.split('\n')
        
        private_key = None
        public_key = None
        
        for line in lines:
            if 'Private key:' in line:
                private_key = line.split('Private key:')[1].strip()
            elif 'Public key:' in line:
                public_key = line.split('Public key:')[1].strip()
        
        if not private_key or not public_key:
            logger.error("Не удалось извлечь ключи из вывода")
            return None
        
        # Генерация короткого ID
        short_id = uuid.uuid4().hex[:8]
        
        return {
            'private_key': private_key,
            'public_key': public_key,
            'short_id': short_id
        }
        
    except FileNotFoundError:
        logger.error("Xray не найден в PATH")
        return None
    except Exception as e:
        logger.error(f"Ошибка генерации ключей: {e}")
        return None

def generate_server_config(server_id, host, port, keys):
    """Генерация конфигурации сервера"""
    config = {
        "log": {
            "loglevel": "info",
            "access": "/var/log/xray/access.log",
            "error": "/var/log/xray/error.log"
        },
        "inbounds": [
            {
                "port": port,
                "protocol": "vless",
                "settings": {
                    "clients": [
                        {
                            "id": str(uuid.uuid4()),
                            "level": 0
                        }
                    ],
                    "decryption": "none"
                },
                "streamSettings": {
                    "network": "tcp",
                    "security": "reality",
                    "realitySettings": {
                        "show": False,
                        "dest": "www.vk.com:443",
                        "xver": 0,
                        "serverNames": [
                            "www.vk.com",
                            "vk.com"
                        ],
                        "privateKey": keys['private_key'],
                        "shortIds": [
                            keys['short_id']
                        ]
                    }
                }
            }
        ],
        "outbounds": [
            {
                "protocol": "freedom",
                "settings": {}
            },
            {
                "protocol": "blackhole",
                "settings": {},
                "tag": "blocked"
            }
        ],
        "routing": {
            "rules": [
                {
                    "type": "field",
                    "ip": [
                        "0.0.0.0/8",
                        "10.0.0.0/8",
                        "100.64.0.0/10",
                        "127.0.0.0/8",
                        "169.254.0.0/16",
                        "172.16.0.0/12",
                        "192.0.0.0/24",
                        "192.0.2.0/24",
                        "192.168.0.0/16",
                        "198.18.0.0/15",
                        "198.51.100.0/24",
                        "203.0.113.0/24",
                        "::1/128",
                        "fc00::/7",
                        "fe80::/10"
                    ],
                    "outboundTag": "blocked"
                },
                {
                    "type": "field",
                    "outboundTag": "blocked",
                    "protocol": [
                        "bittorrent"
                    ]
                }
            ]
        }
    }
    
    return config

def save_config(config, filename):
    """Сохранение конфигурации в файл"""
    try:
        with open(filename, 'w') as f:
            json.dump(config, f, indent=2)
        logger.info(f"Конфигурация сохранена в {filename}")
    except Exception as e:
        logger.error(f"Ошибка сохранения конфигурации: {e}")

def main():
    """Основная функция"""
    logger.info("Генерация Reality ключей и конфигураций...")
    
    # Генерация ключей
    keys = generate_reality_keys()
    if not keys:
        logger.error("Не удалось сгенерировать ключи")
        sys.exit(1)
    
    logger.info("Reality ключи сгенерированы:")
    logger.info(f"Private key: {keys['private_key']}")
    logger.info(f"Public key: {keys['public_key']}")
    logger.info(f"Short ID: {keys['short_id']}")
    
    # Генерация конфигураций для серверов
    servers = [
        {"id": "server-1", "host": "xray1.example.com", "port": 443},
        {"id": "server-2", "host": "xray2.example.com", "port": 443},
        {"id": "server-3", "host": "xray3.example.com", "port": 443}
    ]
    
    for server in servers:
        config = generate_server_config(
            server['id'], 
            server['host'], 
            server['port'], 
            keys
        )
        
        filename = f"xray/{server['id']}.json"
        save_config(config, filename)
    
    logger.info("Генерация завершена успешно!")

if __name__ == "__main__":
    main()
