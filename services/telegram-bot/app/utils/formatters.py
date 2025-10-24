from typing import Optional, Dict, Any

def format_user_info(user: Optional[Dict[str, Any]]) -> str:
    """Форматирование информации о пользователе"""
    if not user:
        return "Пользователь не найден"
    
    return f"""
🆔 ID: {user.get('telegram_id', 'Не указано')}
👤 Имя: {user.get('first_name', 'Не указано')}
📱 Username: @{user.get('username', 'Не указано')}
📅 Регистрация: {user.get('created_at', 'Не указано')}
🔹 Устройств: {user.get('device_count', 0)}/{user.get('max_devices', 3)}
🔹 Статус: {'✅ Активен' if user.get('is_active') else '❌ Заблокирован'}
🔹 Премиум: {'✅ Да' if user.get('is_premium') else '❌ Нет'}
    """
