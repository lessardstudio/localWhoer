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
