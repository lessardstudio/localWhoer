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
        # Используем docker exec к существующему контейнеру вместо docker run, 
        # чтобы избежать проблем с монтированием путей с хоста (DooD)
        print(f"Creating certificate for {client_name}...")
        
        cmd_gen = [
            "docker", "exec", "openvpn-server",
            "easyrsa", "build-client-full", client_name, "nopass"
        ]
        
        result = subprocess.run(cmd_gen, capture_output=True, text=True)
        
        if result.returncode != 0:
            error_msg = f"Stderr: {result.stderr}\nStdout: {result.stdout}"
            print(f"Error creating cert: {error_msg}")
            raise HTTPException(status_code=500, detail=f"Failed to create certificate. Output: {error_msg}")
        
        # Экспортировать конфигурацию
        print(f"Exporting config for {client_name}...")
        cmd_export = [
            "docker", "exec", "openvpn-server",
            "ovpn_getclient", client_name
        ]
        
        result = subprocess.run(cmd_export, capture_output=True, text=True)
        
        if result.returncode != 0:
            error_msg = f"Stderr: {result.stderr}\nStdout: {result.stdout}"
            print(f"Error exporting config: {error_msg}")
            raise HTTPException(status_code=500, detail=f"Failed to export config. Output: {error_msg}")
        
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
        
    except HTTPException as he:
        raise he
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal Error: {str(e)}")

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
        # Используем docker exec (уже было правильно)
        result = subprocess.run(
            [
                "docker", "exec", "openvpn-server",
                "bash", "-c",
                f"easyrsa revoke {client_name} && easyrsa gen-crl"
            ],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=f"Failed to revoke: {result.stderr or result.stdout}")
        
        # Перезапустить OpenVPN
        subprocess.run(["docker", "restart", "openvpn-server"])
        
        return {"message": f"Client {client_name} revoked successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
