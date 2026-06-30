from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import settings
from supabase_client import get_anon_client, client_with_jwt

security = HTTPBearer(auto_error=False)


def codigo_to_email(codigo: str) -> str:
    clean = codigo.strip().lower().replace(" ", "")
    return f"{clean}@asesor.santander.pe"


def documento_to_email(documento: str) -> str:
    clean = documento.strip().split("@")[0]
    return f"{clean}@cliente.santander.pe"


async def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(security),
):
    if not creds or not creds.credentials:
        raise HTTPException(status_code=401, detail="Token requerido")

    token = creds.credentials
    sb = get_anon_client()
    try:
        res = sb.auth.get_user(token)
        user = res.user
        if not user:
            raise HTTPException(status_code=401, detail="Sesión inválida")
        return {"id": user.id, "email": user.email, "token": token, "meta": user.user_metadata or {}}
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="Sesión expirada")


def sb_user(user: dict = Depends(get_current_user)):
    return client_with_jwt(user["token"])
