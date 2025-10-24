from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse, PlainTextResponse
import qrcode
import io
import base64
from typing import Optional

app = FastAPI(title="Xray VPN API", description="API для получения конфигураций VPN")

# Данные сервера
SERVER_CONFIG = {
    "ip": "89.188.113.58",
    "port": "443",
    "uuid": "2227fcce-08c2-473f-87a1-4d9595972646",
    "public_key": "-TL01QWTd3nVXR4qdfnAea5JgUcEzwa_qvpw9KGtTRc",
    "server_name": "www.microsoft.com"
}

@app.get("/")
async def root():
    """Главная страница"""
    return {
        "message": "Xray VPN Service API",
        "version": "1.0.0",
        "endpoints": {
            "config": "/api/config/{user_id}/vless",
            "qr": "/api/config/{user_id}/qr",
            "json": "/api/config/{user_id}/json"
        }
    }

@app.get("/api/config/{user_id}/vless")
async def get_vless_config(user_id: int):
    """Получение VLESS конфигурации для пользователя"""
    try:
        vless_url = generate_vless_url(user_id)
        return PlainTextResponse(vless_url)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/config/{user_id}/qr")
async def get_qr_code(user_id: int):
    """Получение QR кода для конфигурации"""
    try:
        vless_url = generate_vless_url(user_id)
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(vless_url)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Конвертируем в base64
        buffer = io.BytesIO()
        img.save(buffer, format='PNG')
        img_str = base64.b64encode(buffer.getvalue()).decode()
        
        return JSONResponse({
            "qr_code": f"data:image/png;base64,{img_str}",
            "vless_url": vless_url
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/config/{user_id}/json")
async def get_json_config(user_id: int):
    """Получение JSON конфигурации"""
    try:
        config = {
            "v": "2",
            "ps": f"XrayVPN-{user_id}",
            "add": SERVER_CONFIG["ip"],
            "port": SERVER_CONFIG["port"],
            "id": SERVER_CONFIG["uuid"],
            "aid": "0",
            "scy": "auto",
            "net": "tcp",
            "type": "none",
            "host": "",
            "path": "",
            "tls": "reality",
            "sni": SERVER_CONFIG["server_name"],
            "alpn": "",
            "fp": "chrome",
            "pbk": SERVER_CONFIG["public_key"],
            "sid": "",
            "spx": ""
        }
        return JSONResponse(config)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def generate_vless_url(user_id: int) -> str:
    """Генерация VLESS URL для пользователя"""
    config = SERVER_CONFIG
    vless_url = f"vless://{config['uuid']}@{config['ip']}:{config['port']}?encryption=none&security=reality&sni={config['server_name']}&pbk={config['public_key']}&fp=chrome&type=tcp&headerType=none&flow=#XrayVPN-{user_id}"
    return vless_url

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "xray-vpn-api"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
