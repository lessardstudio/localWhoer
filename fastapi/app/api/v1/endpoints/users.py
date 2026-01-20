from fastapi import APIRouter

router = APIRouter()

@router.post("/register")
async def register_user():
    """Регистрация пользователя (TODO)"""
    return {"message": "Not implemented yet"}
