from fastapi import APIRouter, Depends
from pydantic import BaseModel

from deps import get_current_user, sb_user
from services import consultar_buro, pre_evaluar

router = APIRouter(tags=["evaluacion"])


class PreEvalBody(BaseModel):
    numero_documento: str | None = None
    nombres: str | None = None
    tipo_negocio: str | None = None
    ingresos_estimados: float | None = None
    monto_solicitado: float
    plazo_meses: int | None = 12
    destino_credito: str | None = None


class BuroBody(BaseModel):
    dni: str
    consentimiento: bool = True


@router.post("/pre-evaluar")
def pre_eval(body: PreEvalBody, _user=Depends(get_current_user)):
    return pre_evaluar(body.model_dump())


@router.post("/buro/consulta")
def buro(body: BuroBody, user=Depends(get_current_user), sb=Depends(sb_user)):
    result = consultar_buro(body.dni.strip())
    try:
        sb.table("consultas_buro").insert(
            {
                "asesor_id": user["id"],
                "documento": body.dni,
                "calificacion_sbs": result["calificacion_sbs"],
                "entidades_con_deuda": result["entidades_con_deuda"],
                "deuda_total_pen": result["deuda_total"],
                "mayor_deuda": result["mayor_deuda"],
                "dias_mayor_mora": result["dias_mayor_mora"],
                "consentimiento_firmado": body.consentimiento,
            }
        ).execute()
    except Exception:
        pass
    return result
