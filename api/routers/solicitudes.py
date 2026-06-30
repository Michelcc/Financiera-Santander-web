from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from deps import get_current_user, sb_user
from services import map_cliente, map_solicitud

router = APIRouter(tags=["solicitudes"])


class SolicitudBody(BaseModel):
    numero_documento: str
    nombres: str
    apellidos: str = ""
    telefono: str | None = None
    tipo_negocio: str | None = None
    nombre_negocio: str | None = None
    ingresos_estimados: float | None = None
    monto_solicitado: float
    plazo_meses: int = 12
    destino_credito: str | None = None
    tea_referencial: float = 43.92


class ResolverBody(BaseModel):
    decision: str
    monto: float | None = None
    plazo: int | None = None
    motivo: str | None = None


class NotaBody(BaseModel):
    contenido: str


@router.get("/solicitudes")
def listar(user=Depends(get_current_user), sb=Depends(sb_user)):
    res = (
        sb.table("solicitudes")
        .select("*")
        .eq("asesor_id", user["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return [map_solicitud(r) for r in (res.data or [])]


@router.post("/solicitudes")
def crear(body: SolicitudBody, user=Depends(get_current_user), sb=Depends(sb_user)):
    nombre = f"{body.nombres} {body.apellidos}".strip()
    res = sb.rpc(
        "crear_solicitud_desde_asesor",
        {
            "p_documento": body.numero_documento.strip(),
            "p_nombres": nombre,
            "p_monto": body.monto_solicitado,
            "p_plazo": body.plazo_meses,
            "p_telefono": body.telefono,
            "p_tipo_negocio": body.tipo_negocio,
            "p_nombre_negocio": body.nombre_negocio,
            "p_destino": body.destino_credito,
            "p_tea": body.tea_referencial,
        },
    ).execute()
    data = res.data or {}
    return {
        "numero_expediente": data.get("expediente_numero") or data.get("id"),
        "estado": "enviado",
        "id": data.get("id"),
    }


@router.post("/solicitudes/{solicitud_id}/resolver")
def resolver(
    solicitud_id: str,
    body: ResolverBody,
    user=Depends(get_current_user),
    sb=Depends(sb_user),
):
    sb.rpc(
        "resolver_solicitud",
        {
            "p_solicitud_id": solicitud_id,
            "p_decision": body.decision.upper(),
            "p_monto_aprobado": body.monto,
            "p_plazo": body.plazo,
            "p_motivo": body.motivo,
        },
    ).execute()
    return {"ok": True}


@router.get("/solicitudes/{solicitud_id}/notas")
def listar_notas(solicitud_id: str, user=Depends(get_current_user), sb=Depends(sb_user)):
    res = (
        sb.table("solicitudes_notas_internas")
        .select("*")
        .eq("solicitud_id", solicitud_id)
        .order("created_at", desc=True)
        .execute()
    )
    return [{"contenido": n["nota"], "created_at": n["created_at"]} for n in (res.data or [])]


@router.post("/solicitudes/{solicitud_id}/notas")
def agregar_nota(
    solicitud_id: str,
    body: NotaBody,
    user=Depends(get_current_user),
    sb=Depends(sb_user),
):
    sb.table("solicitudes_notas_internas").insert(
        {
            "solicitud_id": solicitud_id,
            "asesor_id": user["id"],
            "nota": body.contenido,
        }
    ).execute()
    return {"ok": True}


@router.get("/clientes/{cliente_id}/ficha")
def ficha_cliente(cliente_id: str, user=Depends(get_current_user), sb=Depends(sb_user)):
    cliente = (
        sb.table("clientes").select("*").eq("id", cliente_id).limit(1).execute()
    )
    if not cliente.data:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    c = cliente.data[0]
    creditos = sb.table("creditos").select("*").eq("cliente_id", cliente_id).execute()
    solicitudes = (
        sb.table("solicitudes")
        .select("*")
        .eq("cliente_id", cliente_id)
        .order("created_at", desc=True)
        .limit(5)
        .execute()
    )
    return {
        "cliente": map_cliente(c),
        "creditos": creditos.data or [],
        "solicitudes": [map_solicitud(s) for s in (solicitudes.data or [])],
        "oferta": {
            "monto_preaprobado": c.get("monto_preaprobado"),
            "plazo": c.get("plazo_preaprobado"),
            "tasa": c.get("tasa_preaprobada"),
            "segmento": c.get("segmento"),
        },
    }
