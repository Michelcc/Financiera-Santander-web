from fastapi import APIRouter, Depends

from deps import get_current_user, sb_user

router = APIRouter(prefix="/alertas", tags=["alertas"])


def _is_supervisor(meta: dict) -> bool:
    role = str(meta.get("role", "")).lower()
    return role in ("supervisor", "administrador", "super operador")


@router.get("")
def listar(user=Depends(get_current_user), sb=Depends(sb_user)):
    q = sb.table("notificaciones_supervisor").select("*").order("created_at", desc=True).limit(50)
    if _is_supervisor(user.get("meta") or {}):
        q = q.in_("audiencia", ["supervisor", "todos"])
    else:
        q = q.eq("asesor_id", user["id"]).in_("audiencia", ["asesor", "todos"])
    return (q.execute().data or [])


@router.patch("/{alerta_id}/leida")
def marcar_leida(alerta_id: str, user=Depends(get_current_user), sb=Depends(sb_user)):
    sb.table("notificaciones_supervisor").update({"leida": True}).eq("id", alerta_id).execute()
    return {"ok": True}
