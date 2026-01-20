from fastapi import APIRouter
from .endpoints import vpn, clients, network, services, users

api_router = APIRouter()
