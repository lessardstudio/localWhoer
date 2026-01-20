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
