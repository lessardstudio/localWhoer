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
