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
