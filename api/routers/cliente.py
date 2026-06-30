"""Rutas app clientes — guía mobile_backend_core_andino_fastapi (/cliente/*)."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from deps import documento_to_email, get_current_user, sb_user
from supabase_client import get_anon_client

router = APIRouter(prefix="/cliente", tags=["Cliente (App)"])


class LoginClienteBody(BaseModel):
    numero_documento: str
    password: str


class OperacionBody(BaseModel):
    cod_cuenta_origen: str
    cod_cuenta_destino: str | None = None
    tipo: str
    monto: float
    moneda: str = "PEN"


def _map_perfil(row: dict) -> dict:
    nombre = row.get("nombre") or ""
    parts = nombre.split(" ", 1)
    return {
        "id": row.get("id"),
        "nombres": parts[0],
        "apellidos": parts[1] if len(parts) > 1 else "",
        "numero_documento": row.get("documento"),
        "telefono": row.get("telefono"),
        "email": row.get("email"),
    }


@router.post("/login")
def login_cliente(body: LoginClienteBody):
    email = documento_to_email(body.numero_documento)
    sb = get_anon_client()
    try:
        res = sb.auth.sign_in_with_password({"email": email, "password": body.password})
    except Exception as e:
        raise HTTPException(status_code=401, detail="Credenciales inválidas") from e

    session = res.session
    user = res.user
    if not session or not user:
        raise HTTPException(status_code=401, detail="Credenciales inválidas")

    perfil_res = (
        sb.table("perfiles_cliente").select("*").eq("id", user.id).limit(1).execute()
    )
    row = (perfil_res.data or [{}])[0]
    return {
        "access_token": session.access_token,
        "token_type": "bearer",
        "cliente": _map_perfil(row),
    }


@router.get("/perfil")
def perfil_cliente(user=Depends(get_current_user), sb=Depends(sb_user)):
    res = sb.table("perfiles_cliente").select("*").eq("id", user["id"]).limit(1).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Perfil no encontrado")
    return _map_perfil(res.data[0])


@router.get("/cuentas")
def cuentas_cliente(user=Depends(get_current_user), sb=Depends(sb_user)):
    try:
        sb.rpc("ensure_productos_cliente", {"p_user_id": user["id"]}).execute()
    except Exception:
        pass
    res = sb.table("cuentas_ahorro").select("*").eq("cliente_user_id", user["id"]).execute()
    return res.data or []


@router.get("/tarjetas")
def tarjetas_cliente(user=Depends(get_current_user), sb=Depends(sb_user)):
    try:
        sb.rpc("ensure_productos_cliente", {"p_user_id": user["id"]}).execute()
    except Exception:
        pass
    res = sb.table("tarjetas_cliente").select("*").eq("cliente_user_id", user["id"]).execute()
    return res.data or []


@router.get("/movimientos")
def movimientos_cliente(limit: int = 20, user=Depends(get_current_user), sb=Depends(sb_user)):
    res = (
        sb.table("movimientos_cliente")
        .select("*")
        .eq("cliente_user_id", user["id"])
        .order("fecha_operacion", desc=True)
        .limit(limit)
        .execute()
    )
    return res.data or []


@router.get("/creditos")
def creditos_cliente(user=Depends(get_current_user), sb=Depends(sb_user)):
    res = sb.table("creditos").select("*").eq("cliente_user_id", user["id"]).execute()
    return res.data or []


@router.get("/notificaciones")
def notificaciones_cliente(user=Depends(get_current_user), sb=Depends(sb_user)):
    res = (
        sb.table("notificaciones_cliente")
        .select("*")
        .eq("cliente_user_id", user["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


@router.post("/operaciones")
def crear_operacion(body: OperacionBody, user=Depends(get_current_user), sb=Depends(sb_user)):
    try:
        res = sb.rpc(
            "registrar_operacion_cliente",
            {
                "p_cod_cuenta_origen": body.cod_cuenta_origen,
                "p_cod_cuenta_destino": body.cod_cuenta_destino or body.cod_cuenta_origen,
                "p_tipo": body.tipo,
                "p_monto": body.monto,
                "p_concepto": f"Operación {body.tipo}",
            },
        ).execute()
        return res.data or {"ok": True}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
