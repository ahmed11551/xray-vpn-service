from typing import Optional, Dict, Any

class UserCreate:
    """Схема создания пользователя"""
    
    def __init__(self, **kwargs):
        self.telegram_id = kwargs.get('telegram_id')
        self.username = kwargs.get('username')
        self.first_name = kwargs.get('first_name')
        self.last_name = kwargs.get('last_name')
        self.max_devices = kwargs.get('max_devices', 3)
