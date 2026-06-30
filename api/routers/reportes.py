from fastapi import APIRouter, Depends

from deps import get_current_user, sb_user

router = APIRouter(prefix="/reportes", tags=["reportes"])


@router.get("/productividad")
def productividad(user=Depends(get_current_user), sb=Depends(sb_user)):
    res = sb.rpc("productividad_asesores").execute()
    rows = res.data or []
    return [
        {
            "asesor_nombre": r.get("asesor_nombre"),
            "codigo": r.get("codigo"),
            "enviadas": int(r.get("enviadas") or 0),
            "aprobadas": int(r.get("aprobadas") or 0),
            "monto_total": float(r.get("monto_total") or 0),
        }
        for r in rows
    ]
