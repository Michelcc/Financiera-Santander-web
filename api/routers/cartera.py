from datetime import date

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from deps import get_current_user, sb_user
from services import map_cliente

router = APIRouter(tags=["cartera"])


class VisitaBody(BaseModel):
    resultado: str
    observacion: str | None = None
    latitud: float | None = None
    longitud: float | None = None


@router.get("/cartera")
def listar_cartera(user=Depends(get_current_user), sb=Depends(sb_user)):
    try:
        res = sb.rpc("get_mi_cartera").execute()
        rows = res.data or []
        if rows:
            hoy = date.today().isoformat()
            visitas = (
                sb.table("visitas")
                .select("cliente_id, resultado, created_at")
                .eq("asesor_id", user["id"])
                .gte("created_at", f"{hoy}T00:00:00")
                .execute()
            )
            visita_map = {v["cliente_id"]: v for v in (visitas.data or [])}
            return [map_cliente(c, visita_map.get(c["id"])) for c in rows]
    except Exception:
        pass

    asesor_id = user["id"]
    clientes = (
        sb.table("clientes")
        .select("*")
        .eq("asesor_id", asesor_id)
        .order("prioridad")
        .execute()
    )
    rows = clientes.data or []
    if not rows:
        clientes = (
            sb.table("clientes")
            .select("*")
            .order("prioridad")
            .limit(100)
            .execute()
        )
        rows = clientes.data or []

    hoy = date.today().isoformat()
    visitas = (
        sb.table("visitas")
        .select("cliente_id, resultado, created_at")
        .eq("asesor_id", asesor_id)
        .gte("created_at", f"{hoy}T00:00:00")
        .execute()
    )
    visita_map = {v["cliente_id"]: v for v in (visitas.data or [])}
    return [map_cliente(c, visita_map.get(c["id"])) for c in rows]


@router.post("/cartera/{cartera_id}/visita")
def marcar_visita(
    cartera_id: str,
    body: VisitaBody,
    user=Depends(get_current_user),
    sb=Depends(sb_user),
):
    visit_id = f"vis_{cartera_id}_{int(date.today().strftime('%Y%m%d'))}"
    sb.table("visitas").upsert(
        {
            "id": visit_id,
            "asesor_id": user["id"],
            "cliente_id": cartera_id,
            "resultado": body.resultado,
            "observacion": body.observacion or "",
            "latitud": body.latitud,
            "longitud": body.longitud,
        }
    ).execute()
    return {"ok": True, "id": visit_id}
