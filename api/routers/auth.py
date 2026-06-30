from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from deps import codigo_to_email, get_current_user, sb_user
from supabase_client import get_anon_client

router = APIRouter(prefix="/auth", tags=["auth"])


class LoginBody(BaseModel):
    codigo_empleado: str
    password: str


@router.post("/login")
def login(body: LoginBody):
    email = codigo_to_email(body.codigo_empleado)
    sb = get_anon_client()
    try:
        res = sb.auth.sign_in_with_password({"email": email, "password": body.password})
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Credenciales inválidas: {e}") from e

    session = res.session
    user = res.user
    if not session or not user:
        raise HTTPException(status_code=401, detail="Credenciales inválidas")

    perfil_res = (
        sb.table("perfiles_asesor")
        .select("*")
        .eq("id", user.id)
        .limit(1)
        .execute()
    )
    row = (perfil_res.data or [{}])[0] if perfil_res.data else {}
    codigo = row.get("codigo") or body.codigo_empleado.strip().upper()
    nombre = row.get("nombre") or f"Asesor {codigo}"
    parts = nombre.split(" ", 1)

    return {
        "access_token": session.access_token,
        "token_type": "bearer",
        "asesor": {
            "id": user.id,
            "codigo_empleado": codigo,
            "nombres": parts[0],
            "apellidos": parts[1] if len(parts) > 1 else "",
            "perfil": (user.user_metadata or {}).get("role", "Operador"),
            "agencia_id": row.get("sucursal"),
        },
    }
