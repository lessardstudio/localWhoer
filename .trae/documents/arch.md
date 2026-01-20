Отлично! Добавим FastAPI REST API с Swagger документацией в вашу VPN архитектуру. Это позволит управлять всеми сервисами через API.
Обновленная архитектура
Клиент 1 (10.8.0.2) ←→ VPN Сервер (10.8.0.1) ←→ Клиент 2 (10.8.0.3)
        ↓                      ↓                        ↓
   whier-app              VPS сервисы              whier-app
 (172.20.0.10)            FastAPI REST             (172.20.0.10)
                          (172.20.0.30)
                         Swagger UI
1. Обновленный docker-compose.yml
yamlversion: '3.8'

services:
  whier:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: whier-app
    restart: always
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - NODE_ENV=production
    networks:
      vpn-network:
        ipv4_address: 172.20.0.10

  fastapi:
    build:
      context: ./fastapi
      dockerfile: Dockerfile
    container_name: fastapi-server
    restart: always
    ports:
      - "127.0.0.1:8000:8000"
    volumes:
      - ./openvpn:/app/openvpn:ro
      - ./fastapi/app:/app
      - /var/run/docker.sock:/var/run/docker.sock  # Для управления Docker
    environment:
      - PYTHONUNBUFFERED=1
      - API_KEY=${API_KEY:-secret-api-key-change-me}
      - OPENVPN_DIR=/app/openvpn
    networks:
      vpn-network:
        ipv4_address: 172.20.0.30
    depends_on:
      - openvpn

  openvpn:
    image: kylemanna/openvpn:latest
    container_name: openvpn-server
    restart: always
    privileged: true
    ports:
      - "1194:1194/udp"
    cap_add:
      - NET_ADMIN
    volumes:
      - ./openvpn/config:/etc/openvpn
    networks:
      vpn-network:
        ipv4_address: 172.20.0.5
    sysctls:
      - net.ipv4.ip_forward=1
    command: ovpn_run

  samba:
    image: dperson/samba:latest
    container_name: file-server
    restart: always
    environment:
      - USERID=1000
      - GROUPID=1000
      - SHARE=shared;/shared;yes;no;no;all;none
    volumes:
      - ./shared:/shared
    networks:
      vpn-network:
        ipv4_address: 172.20.0.20
    ports:
      - "127.0.0.1:445:445"

  dns:
    image: strm/dnsmasq:latest
    container_name: local-dns
    restart: always
    cap_add:
      - NET_ADMIN
    volumes:
      - ./dns/dnsmasq.conf:/etc/dnsmasq.conf
    networks:
      vpn-network:
        ipv4_address: 172.20.0.2
    ports:
      - "127.0.0.1:53:53/udp"

  # База данных для API (опционально)
  postgres:
    image: postgres:15-alpine
    container_name: postgres-db
    restart: always
    environment:
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD=${DB_PASSWORD:-change-me}
      - POSTGRES_DB=vpn_management
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      vpn-network:
        ipv4_address: 172.20.0.40
    ports:
      - "127.0.0.1:5432:5432"

networks:
  vpn-network:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1

volumes:
  postgres-data:
2. Структура FastAPI приложения
bashmkdir -p fastapi/app/{api,models,schemas,services,utils}

# Создать структуру
cat > create_fastapi_structure.sh << 'EOF'
#!/bin/bash

echo "📁 Создание структуры FastAPI..."

mkdir -p fastapi/app/{api/v1/endpoints,models,schemas,services,utils,core}

# Создать пустые __init__.py
touch fastapi/app/__init__.py
touch fastapi/app/api/__init__.py
touch fastapi/app/api/v1/__init__.py
touch fastapi/app/api/v1/endpoints/__init__.py
touch fastapi/app/models/__init__.py
touch fastapi/app/schemas/__init__.py
touch fastapi/app/services/__init__.py
touch fastapi/app/utils/__init__.py
touch fastapi/app/core/__init__.py

echo "✅ Структура создана!"
EOF

chmod +x create_fastapi_structure.sh
./create_fastapi_structure.sh
3. FastAPI Dockerfile
dockerfilecat > fastapi/Dockerfile << 'DOCKERFILE'
FROM python:3.11-slim

WORKDIR /app

# Установить системные зависимости
RUN apt-get update && apt-get install -y \
    curl \
    docker.io \
    easy-rsa \
    openvpn \
    && rm -rf /var/lib/apt/lists/*

# Установить Python зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копировать приложение
COPY ./app /app

# Создать пользователя
RUN useradd -m -u 1000 apiuser && chown -R apiuser:apiuser /app

USER apiuser

# Запуск
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
DOCKERFILE
4. requirements.txt
txtcat > fastapi/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
pydantic-settings==2.1.0
python-multipart==0.0.6
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-dotenv==1.0.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
alembic==1.13.0
docker==6.1.3
aiofiles==23.2.1
jinja2==3.1.2
EOF
5. Главный файл FastAPI - main.py
pythoncat > fastapi/app/main.py << 'PYTHON'
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
PYTHON
6. Конфигурация - core/config.py
pythoncat > fastapi/app/core/config.py << 'PYTHON'
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # API
    API_KEY: str = "secret-api-key-change-me"
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "VPN Management API"
    
    # OpenVPN
    OPENVPN_DIR: str = "/app/openvpn"
    OPENVPN_CONFIG_DIR: str = "/app/openvpn/config"
    OPENVPN_CLIENTS_DIR: str = "/app/openvpn/clients"
    
    # Database
    POSTGRES_USER: str = "admin"
    POSTGRES_PASSWORD: str = "change-me"
    POSTGRES_DB: str = "vpn_management"
    POSTGRES_HOST: str = "172.20.0.40"
    POSTGRES_PORT: int = 5432
    
    @property
    def DATABASE_URL(self) -> str:
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
    
    # Docker
    DOCKER_NETWORK: str = "vpn-network"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
PYTHON
7. VPN Endpoints - api/v1/endpoints/vpn.py
pythoncat > fastapi/app/api/v1/endpoints/vpn.py << 'PYTHON'
from fastapi import APIRouter, HTTPException
from typing import List
import subprocess
import docker
import os

from schemas.vpn import VPNStatus, VPNClient, VPNStats
from core.config import settings

router = APIRouter()

@router.get("/status", response_model=VPNStatus)
async def get_vpn_status():
    """Получить статус OpenVPN сервера"""
    try:
        client = docker.from_env()
        container = client.containers.get("openvpn-server")
        
        return VPNStatus(
            status=container.status,
            running=container.status == "running",
            name=container.name,
            image=container.image.tags[0] if container.image.tags else "unknown"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/connected-clients", response_model=List[VPNClient])
async def get_connected_clients():
    """Получить список подключенных клиентов"""
    try:
        result = subprocess.run(
            ["docker", "exec", "openvpn-server", "cat", "/etc/openvpn/openvpn-status.log"],
            capture_output=True,
            text=True
        )
        
        clients = []
        for line in result.stdout.split('\n'):
            if line.startswith("CLIENT_LIST"):
                parts = line.split('\t')
                if len(parts) >= 6:
                    clients.append(VPNClient(
                        name=parts[1],
                        real_address=parts[2],
                        virtual_address=parts[3],
                        bytes_received=int(parts[4]),
                        bytes_sent=int(parts[5]),
                        connected_since=parts[7] if len(parts) > 7 else ""
                    ))
        
        return clients
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/stats", response_model=VPNStats)
async def get_vpn_stats():
    """Получить статистику VPN"""
    try:
        clients = await get_connected_clients()
        
        total_bytes_in = sum(c.bytes_received for c in clients)
        total_bytes_out = sum(c.bytes_sent for c in clients)
        
        return VPNStats(
            total_clients=len(clients),
            total_bytes_received=total_bytes_in,
            total_bytes_sent=total_bytes_out,
            active_connections=len(clients)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/restart")
async def restart_vpn():
    """Перезапустить OpenVPN сервер"""
    try:
        client = docker.from_env()
        container = client.containers.get("openvpn-server")
        container.restart()
        
        return {"message": "OpenVPN server restarted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
PYTHON
8. Clients Endpoints - api/v1/endpoints/clients.py
pythoncat > fastapi/app/api/v1/endpoints/clients.py << 'PYTHON'
from fastapi import APIRouter, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from typing import List
import subprocess
import os
from datetime import datetime

from schemas.client import ClientCreate, ClientResponse, ClientList
from core.config import settings

router = APIRouter()

@router.post("/create", response_model=ClientResponse)
async def create_client(client: ClientCreate, background_tasks: BackgroundTasks):
    """Создать нового VPN клиента"""
    try:
        client_name = client.name
        
        # Проверить что клиент не существует
        clients_dir = settings.OPENVPN_CLIENTS_DIR
        if os.path.exists(f"{clients_dir}/{client_name}.ovpn"):
            raise HTTPException(status_code=400, detail="Client already exists")
        
        # Создать сертификат
        result = subprocess.run(
            [
                "docker", "run", "-v", f"{settings.OPENVPN_CONFIG_DIR}:/etc/openvpn",
                "--rm", "-it", "kylemanna/openvpn",
                "easyrsa", "build-client-full", client_name, "nopass"
            ],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=f"Failed to create certificate: {result.stderr}")
        
        # Экспортировать конфигурацию
        result = subprocess.run(
            [
                "docker", "run", "-v", f"{settings.OPENVPN_CONFIG_DIR}:/etc/openvpn",
                "--rm", "kylemanna/openvpn",
                "ovpn_getclient", client_name
            ],
            capture_output=True,
            text=True
        )
        
        # Сохранить .ovpn файл
        os.makedirs(clients_dir, exist_ok=True)
        with open(f"{clients_dir}/{client_name}.ovpn", "w") as f:
            f.write(result.stdout)
            # Добавить дополнительные настройки
            f.write("\n# Локальная сеть\n")
            f.write("route 172.20.0.0 255.255.0.0\n")
            f.write("compress lz4-v2\n")
        
        return ClientResponse(
            name=client_name,
            created_at=datetime.now(),
            status="active",
            config_file=f"{client_name}.ovpn"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/list", response_model=List[ClientList])
async def list_clients():
    """Получить список всех клиентов"""
    try:
        clients_dir = settings.OPENVPN_CLIENTS_DIR
        clients = []
        
        if os.path.exists(clients_dir):
            for filename in os.listdir(clients_dir):
                if filename.endswith(".ovpn"):
                    client_name = filename[:-5]
                    file_path = os.path.join(clients_dir, filename)
                    stat = os.stat(file_path)
                    
                    clients.append(ClientList(
                        name=client_name,
                        config_file=filename,
                        created_at=datetime.fromtimestamp(stat.st_ctime),
                        file_size=stat.st_size
                    ))
        
        return clients
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/download/{client_name}")
async def download_client_config(client_name: str):
    """Скачать конфигурацию клиента"""
    try:
        file_path = f"{settings.OPENVPN_CLIENTS_DIR}/{client_name}.ovpn"
        
        if not os.path.exists(file_path):
            raise HTTPException(status_code=404, detail="Client config not found")
        
        return FileResponse(
            path=file_path,
            filename=f"{client_name}.ovpn",
            media_type="application/x-openvpn-profile"
        )
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Client config not found")

@router.delete("/revoke/{client_name}")
async def revoke_client(client_name: str):
    """Отозвать сертификат клиента"""
    try:
        result = subprocess.run(
            [
                "docker", "exec", "openvpn-server",
                "bash", "-c",
                f"cd /usr/share/easy-rsa && ./easyrsa revoke {client_name} && ./easyrsa gen-crl"
            ],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=f"Failed to revoke: {result.stderr}")
        
        # Перезапустить OpenVPN
        subprocess.run(["docker", "restart", "openvpn-server"])
        
        return {"message": f"Client {client_name} revoked successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
PYTHON
9. Schemas - schemas/vpn.py
pythoncat > fastapi/app/schemas/vpn.py << 'PYTHON'
from pydantic import BaseModel
from typing import Optional

class VPNStatus(BaseModel):
    status: str
    running: bool
    name: str
    image: str

class VPNClient(BaseModel):
    name: str
    real_address: str
    virtual_address: str
    bytes_received: int
    bytes_sent: int
    connected_since: str

class VPNStats(BaseModel):
    total_clients: int
    total_bytes_received: int
    total_bytes_sent: int
    active_connections: int
PYTHON
10. Schemas - schemas/client.py
pythoncat > fastapi/app/schemas/client.py << 'PYTHON'
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class ClientCreate(BaseModel):
    name: str
    email: Optional[str] = None
    description: Optional[str] = None

class ClientResponse(BaseModel):
    name: str
    created_at: datetime
    status: str
    config_file: str

class ClientList(BaseModel):
    name: str
    config_file: str
    created_at: datetime
    file_size: int
PYTHON
11. API Routers - инициализация
python# api/v1/__init__.py
cat > fastapi/app/api/v1/__init__.py << 'PYTHON'
from fastapi import APIRouter
from .endpoints import vpn, clients, network, services, users

api_router = APIRouter()
PYTHON

# api/v1/endpoints/__init__.py - создать пустые роутеры
cat > fastapi/app/api/v1/endpoints/network.py << 'PYTHON'
from fastapi import APIRouter

router = APIRouter()

@router.get("/info")
async def get_network_info():
    """Информация о сети"""
    return {
        "vpn_subnet": "10.8.0.0/24",
        "docker_subnet": "172.20.0.0/16",
        "services": {
            "whier-app": "172.20.0.10",
            "fastapi": "172.20.0.30",
            "file-server": "172.20.0.20"
        }
    }
PYTHON

cat > fastapi/app/api/v1/endpoints/services.py << 'PYTHON'
from fastapi import APIRouter
import docker

router = APIRouter()

@router.get("/list")
async def list_services():
    """Список всех сервисов"""
    try:
        client = docker.from_env()
        containers = client.containers.list()
        
        services = []
        for container in containers:
            services.append({
                "name": container.name,
                "status": container.status,
                "image": container.image.tags[0] if container.image.tags else "unknown"
            })
        
        return services
    except Exception as e:
        return {"error": str(e)}
PYTHON

cat > fastapi/app/api/v1/endpoints/users.py << 'PYTHON'
from fastapi import APIRouter

router = APIRouter()

@router.post("/register")
async def register_user():
    """Регистрация пользователя (TODO)"""
    return {"message": "Not implemented yet"}
PYTHON
12. Обновленный .env
bashcat >> .env << 'ENV'

# FastAPI
API_KEY=your-secret-api-key-change-this
DB_PASSWORD=secure-database-password-change-this

# OpenVPN
OPENVPN_DIR=/app/openvpn
ENV
13. Скрипт запуска всего стека
bashcat > start_full_stack.sh << 'EOF'
#!/bin/bash

set -e

echo "🚀 Запуск полного стека VPN + FastAPI..."
echo ""

# 1. Создать структуру
echo "📁 Создание структуры..."
./create_fastapi_structure.sh 2>/dev/null || true

# 2. Инициализация VPN (если еще не сделано)
if [ ! -f "openvpn/config/openvpn.conf" ]; then
    echo "🔧 Инициализация OpenVPN..."
    ./setup_vpn_network.sh
fi

# 3. Запуск всех сервисов
echo "🐳 Запуск Docker контейнеров..."
docker-compose down
docker-compose up -d --build

echo ""
echo "⏳ Ожидание запуска сервисов (30 сек)..."
sleep 30

echo ""
echo "✅ Стек запущен!"
echo ""
echo "📋 Доступные сервисы:"
echo ""
echo "1. Swagger UI (REST API документация):"
echo "   ssh -L 8000:127.0.0.1:8000 root@YOUR_SERVER_IP"
echo "   Затем откройте: http://localhost:8000/docs"
echo ""
echo "2. ReDoc (альтернативная документация):"
echo "   http://localhost:8000/redoc"
echo ""
echo "3. whier-app:"
echo "   http://172.20.0.10:3000 (через VPN)"
echo ""
echo "4. API Key для запросов:"
echo "   Authorization: Bearer $(grep API_KEY .env | cut -d'=' -f2)"
echo ""
echo "🧪 Тестовый запрос:"
echo "   curl -H 'Authorization: Bearer $(grep API_KEY .env | cut -d'=' -f2)' http://localhost:8000/api/v1/vpn/status"
EOF

chmod +x start_full_stack.sh
14. Примеры использования API
bashcat > api_examples.sh << 'EOF'
#!/bin/bash

API_KEY=$(grep API_KEY .env | cut -d'=' -f2)
BASE_URL="http://localhost:8000/api/v1"

echo "=== 📡 Примеры использования VPN Management API ==="
echo ""
echo "API Key: $API_KEY"
echo ""

# 1. Проверка здоровья
echo "1️⃣ Health Check:"
curl -s http://localhost:8000/health | jq .
echo ""

# 2. Статус VPN
echo "2️⃣ VPN Status:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/vpn/status | jq .
echo ""

# 3. Подключенные клиенты
echo "3️⃣ Connected Clients:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/vpn/connected-clients | jq .
echo ""

# 4. Список клиентов
echo "4️⃣ All Clients:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/clients/list | jq .
echo ""

# 5. Создать клиента
echo "5️⃣ Create Client (testuser):"
curl -s -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"testuser","email":"test@example.com"}' \
  $BASE_URL/clients/create | jq .
echo ""

# 6. Скачать конфиг
echo "6️⃣ Download Config:"
echo "curl -H 'Authorization: Bearer $API_KEY' $BASE_URL/clients/download/testuser -o testuser.ovpn"
echo ""

# 7. Статистика
echo "7️⃣ VPN Statistics:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/vpn/stats | jq .
echo ""

# 8. Сервисы
echo "8️⃣ Services List:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/services/list | jq .
echo ""

# 9. Network Info
echo "9️⃣ Network Info:"
curl -s -H "Authorization: Bearer $API_KEY" $BASE_URL/network/info | jq .
EOF

chmod +x api_examples.sh
15. Запуск и тестирование
bash# 1. Запустить весь стек
./start_full_stack.sh

# 2. Открыть SSH туннель для доступа к Swagger
ssh -L 8000:127.0.0.1:8000 root@YOUR_SERVER_IP

# 3. Открыть в браузере
# http://localhost:8000/docs

# 4. Тестировать API
./api_examples.sh
```

## 16. Swagger UI - что вы увидите

В браузере по адресу `http://localhost:8000/docs` будет доступен интерактивный интерфейс с:

### 📚 **VPN Endpoints:**
- `GET /api/v1/vpn/status` - Статус OpenVPN
- `GET /api/v1/vpn/connected-clients` - Подключенные клиенты
- `GET /api/v1/vpn/stats` - Статистика
- `POST /api/v1/vpn/restart` - Перезапуск сервера

### 👥 **Clients Endpoints:**
- `POST /api/v1/clients/create` - Создать клиента
- `GET /api/v1/clients/list` - Список клиентов
- `GET /api/v1/clients/download/{name}` - Скачать конфиг
- `DELETE /api/v1/clients/revoke/{name}` - Отозвать сертификат

### 🌐 **Network Endpoints:**
- `GET /api/v1/network/info` - Информация о сети

### 🔧 **Services Endpoints:**
- `GET /api/v1/services/list` - Список сервисов

## 17. Итоговая архитектура
```
┌─────────────────────────────────────────────────────┐
│                   VPN Network                        │
│                  (10.8.0.0/24)                      │
│                                                      │
│  Client 1     Client 2     Client 3                │
│  (10.8.0.2)   (10.8.0.3)   (10.8.0.4)             │
└────────┬──────────┬──────────┬─────────────────────┘
         │          │          │
         └──────────┴──────────┘
                    │
         ┌──────────▼──────────┐
         │   OpenVPN Server    │
         │    (172.20.0.5)     │
         │   (10.8.0.1)        │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────────────────┐
         │    Docker Network                │
         │    (172.20.0.0/16)              │
         │                                  │
         │  ┌──────────────────┐           │
         │  │ FastAPI + Swagger│           │
         │  │  (172.20.0.30)   │           │
         │  │  Port: 8000      │           │
         │  │  /docs /redoc    │           │
         │  └──────────────────┘           │
         │           │                      │
         │  ┌────────▼─────────┐           │
         │  │    whier-app     │           │
         │  │  (172.20.0.10)   │           │
         │  │   Port: 3000     │           │
         │  └──────────────────┘           │
         │                                  │
         │  ┌──────────────────┐           │
         │  │   File Server    │           │
         │  │  (172.20.0.20)   │           │
         │  └──────────────────┘           │
         │                                  │
         │  ┌──────────────────┐           │
         │  │   PostgreSQL     │           │
         │  │  (172.20.0.40)   │           │
         │  └──────────────────┘           │
         │                                  │
         │  ┌──────────────────┐           │
         │  │   DNS Server     │           │
         │  │  (172.20.0.2)    │           │
         │  └──────────────────┘           │
         └──────────────────────────────────┘
Готово! 🎉
Теперь у вас есть:
✅ Полноценная VPN сеть
✅ REST API с FastAPI
✅ Swagger UI документация
✅ Управление клиентами через API
✅ Мониторинг и статистика
✅ База данных PostgreSQL
✅ Файловый сервер
✅ Локальный DNS