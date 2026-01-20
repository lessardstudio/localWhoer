from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import FileResponse
import os

from api.v1 import vpn, clients, network, services, users
from core.config import settings

# Инициализация приложения
app = FastAPI(
    title="VPN Management API",
    description="REST API для управления корпоративной VPN сетью",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене указать конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()

def verify_api_key(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Проверка API ключа"""
    if credentials.credentials != settings.API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    return credentials.credentials

# Подключение роутеров
app.include_router(
    vpn.router,
    prefix="/api/v1/vpn",
    tags=["VPN"],
    dependencies=[Depends(verify_api_key)]
)

app.include_router(
    clients.router,
    prefix="/api/v1/clients",
    tags=["Clients"],
    dependencies=[Depends(verify_api_key)]
)

app.include_router(
    network.router,
    prefix="/api/v1/network",
    tags=["Network"],
    dependencies=[Depends(verify_api_key)]
)

app.include_router(
    services.router,
    prefix="/api/v1/services",
    tags=["Services"],
    dependencies=[Depends(verify_api_key)]
)

app.include_router(
    users.router,
    prefix="/api/v1/users",
    tags=["Users"],
)

# Главная страница
@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "VPN Management API",
        "version": "1.0.0",
        "docs": "/docs",
        "status": "running"
    }

# Health check
@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "services": {
            "api": "running",
            "openvpn": "running",
            "database": "running"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
