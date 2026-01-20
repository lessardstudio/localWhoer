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
