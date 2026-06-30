from math import pow
from typing import Any


def map_cliente(row: dict, visita: dict | None = None) -> dict:
    return {
        "id": row["id"],
        "cliente_id": row["id"],
        "cliente_nombre": row.get("nombre"),
        "documento": row.get("documento"),
        "telefono": row.get("telefono"),
        "negocio_nombre": row.get("negocio_nombre"),
        "tipo_gestion": row.get("tipo_gestion"),
        "prioridad": row.get("prioridad") or 3,
        "score_prioridad": row.get("score_final") or row.get("score_transaccional") or 500,
        "score_final": row.get("score_final"),
        "segmento": row.get("segmento"),
        "mora_dias": row.get("mora_dias") or 0,
        "monto_credito": row.get("monto_preaprobado") or row.get("hipotesis_credito") or 0,
        "estado_visita": (visita or {}).get("resultado") or (visita or {}).get("estado_visita") or "pendiente",
        "latitud": row.get("latitud"),
        "longitud": row.get("longitud"),
    }


def map_solicitud(row: dict) -> dict:
    dp = row.get("datos_personales") or {}
    cond = row.get("condiciones") or {}
    if isinstance(dp, str):
        dp = {}
    if isinstance(cond, str):
        cond = {}
    monto = cond.get("monto") or row.get("monto_aprobado") or 0
    estado = (row.get("estado") or "borrador").lower()
    return {
        "id": row["id"],
        "cliente_id": row.get("cliente_id"),
        "documento": row.get("documento_cliente") or dp.get("documento"),
        "cliente_nombre": dp.get("nombre") or dp.get("nombres") or "Cliente",
        "estado": estado,
        "monto": monto,
        "monto_solicitado": monto,
        "monto_aprobado": row.get("monto_aprobado"),
        "plazo": row.get("plazo_aprobado") or cond.get("plazo") or 6,
        "cuota_mensual": row.get("cuota_mensual"),
        "segmento": row.get("segmento"),
        "score_final": row.get("score_final"),
        "created_at": row.get("created_at"),
        "expediente_numero": row.get("expediente_numero"),
        "numero_expediente": row.get("expediente_numero") or row["id"],
        "condiciones": cond,
    }


def cuota_francesa(monto: float, plazo: int, tea: float = 43.92) -> float:
    if monto <= 0 or plazo <= 0:
        return 0.0
    tep = pow(1 + tea / 100, 1 / 12) - 1
    if tep == 0:
        return round(monto / plazo, 2)
    factor = pow(1 + tep, plazo)
    return round(monto * (tep * factor) / (factor - 1), 2)


def pre_evaluar(payload: dict[str, Any]) -> dict:
    ingresos = float(payload.get("ingresos_estimados") or 0)
    monto = float(payload.get("monto_solicitado") or 0)
    plazo = int(payload.get("plazo_meses") or 12)
    cuota = cuota_francesa(monto, plazo)
    ratio = (cuota / ingresos) if ingresos > 0 else 999

    puntaje = 85
    if ingresos <= 0:
        puntaje = 40
    elif ratio > 0.5:
        puntaje = 35
    elif ratio > 0.35:
        puntaje = 55
    elif ratio > 0.25:
        puntaje = 72

    if monto > ingresos * 12:
        puntaje -= 15

    puntaje = max(0, min(100, puntaje))

    if puntaje >= 70:
        cal, motivo = "APTO", "Capacidad de pago compatible con el monto solicitado."
    elif puntaje >= 45:
        cal, motivo = "REVISAR", "Relación cuota/ingreso elevada. Requiere visita y sustento."
    else:
        cal, motivo = "NO_PROCEDE", "Ingresos insuficientes para el monto y plazo solicitados."

    return {
        "calificacion": cal,
        "puntaje": puntaje,
        "motivo": motivo,
        "cuota_estimada": cuota,
        "ratio_cuota_ingreso": round(ratio, 4) if ingresos else None,
    }


def consultar_buro(dni: str) -> dict:
    if dni.endswith("999") or dni == "00000000":
        return {
            "calificacion_sbs": "Perdida",
            "entidades_con_deuda": 2,
            "deuda_total": 15200.0,
            "mayor_deuda": 12000.0,
            "dias_mayor_mora": 180,
            "en_lista_negra": True,
            "motivo_bloqueo": "Encontrado en lista de prevención de fraude Santander",
            "interpretacion": "Cliente inhabilitado para originación.",
        }

    last = int(dni[-1]) if dni[-1].isdigit() else 5
    rating = "Normal"
    debt = 4500.0
    mora = 0
    if last == 3:
        rating, debt, mora = "CPP", 2500.0, 15
    elif last == 7:
        rating, debt, mora = "Deficiente", 8900.0, 45
    elif last == 0:
        rating, debt, mora = "Dudoso", 12000.0, 85

    return {
        "calificacion_sbs": rating,
        "entidades_con_deuda": 1 if last % 2 else 2,
        "deuda_total": debt,
        "mayor_deuda": debt * 0.7,
        "dias_mayor_mora": mora,
        "en_lista_negra": False,
        "motivo_bloqueo": None,
        "interpretacion": f"Posición SBS {rating}. {'Sin mora reportada.' if mora == 0 else f'Mora máxima {mora} días.'}",
    }
