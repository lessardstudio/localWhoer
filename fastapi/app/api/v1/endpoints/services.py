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
