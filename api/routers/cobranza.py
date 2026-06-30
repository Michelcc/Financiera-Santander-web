from fastapi import APIRouter, Depends
from pydantic import BaseModel

from deps import get_current_user, sb_user
from services import map_cliente

router = APIRouter(prefix="/cobranza", tags=["cobranza"])


class AccionBody(BaseModel):
    cliente_id: str
    tipo: str
    observacion: str | None = None
    compromiso_fecha: str | None = None
    compromiso_monto: float | None = None
    latitud: float | None = None
    longitud: float | None = None


@router.get("/mora")
def listar_mora(user=Depends(get_current_user), sb=Depends(sb_user)):
    res = (
        sb.table("clientes")
        .select("*")
        .eq("asesor_id", user["id"])
        .gt("mora_dias", 0)
        .order("mora_dias", desc=True)
        .execute()
    )
    out = []
    for c in res.data or []:
        row = map_cliente(c)
        row["deuda_total"] = c.get("deuda_total") or 0
        row["dias_mora"] = c.get("mora_dias") or 0
        out.append(row)
    return out


@router.post("/accion")
def registrar_accion(body: AccionBody, user=Depends(get_current_user), sb=Depends(sb_user)):
    import time

    action_id = f"cob_{body.cliente_id}_{int(time.time())}"
    sb.table("acciones_cobranza").upsert(
        {
            "id": action_id,
            "asesor_id": user["id"],
            "cliente_id": body.cliente_id,
            "tipo": body.tipo,
            "observacion": body.observacion or "",
            "compromiso_fecha": body.compromiso_fecha,
            "compromiso_monto": body.compromiso_monto or 0,
            "latitud": body.latitud,
            "longitud": body.longitud,
        }
    ).execute()
    return {"ok": True, "id": action_id}
