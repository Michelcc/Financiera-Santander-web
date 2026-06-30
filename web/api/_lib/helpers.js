/**
 * Helpers reutilizables para todas las funciones serverless.
 */

/** Cabeceras CORS estándar */
export const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
}

/** Respuesta JSON con CORS */
export function json(res, data, status = 200) {
  return res.status(status).json(data)
}

/** Respuesta de error */
export function error(res, message, status = 400) {
  return res.status(status).json({ error: message })
}

/** Mapea fila de cliente a formato del frontend */
export function mapCliente(row, visita = null) {
  return {
    id: row.id,
    cliente_id: row.id,
    cliente_nombre: row.nombre ?? null,
    documento: row.documento ?? null,
    telefono: row.telefono ?? null,
    negocio_nombre: row.negocio_nombre ?? null,
    tipo_gestion: row.tipo_gestion ?? null,
    prioridad: row.prioridad ?? 3,
    score_prioridad: row.score_final ?? row.score_transaccional ?? 500,
    score_final: row.score_final ?? null,
    segmento: row.segmento ?? null,
    mora_dias: row.mora_dias ?? 0,
    monto_credito: row.monto_preaprobado ?? row.hipotesis_credito ?? 0,
    estado_visita: visita?.resultado ?? visita?.estado_visita ?? 'pendiente',
    latitud: row.latitud ?? null,
    longitud: row.longitud ?? null,
  }
}

/** Mapea fila de solicitud a formato del frontend */
export function mapSolicitud(row) {
  const dp = (typeof row.datos_personales === 'object' && row.datos_personales) ? row.datos_personales : {}
  const cond = (typeof row.condiciones === 'object' && row.condiciones) ? row.condiciones : {}
  const monto = cond.monto ?? row.monto_aprobado ?? 0
  return {
    id: row.id,
    cliente_id: row.cliente_id ?? null,
    documento: row.documento_cliente ?? dp.documento ?? null,
    cliente_nombre: dp.nombre ?? dp.nombres ?? 'Cliente',
    estado: (row.estado ?? 'borrador').toLowerCase(),
    monto,
    monto_solicitado: monto,
    monto_aprobado: row.monto_aprobado ?? null,
    plazo: row.plazo_aprobado ?? cond.plazo ?? 6,
    cuota_mensual: row.cuota_mensual ?? null,
    segmento: row.segmento ?? null,
    score_final: row.score_final ?? null,
    created_at: row.created_at ?? null,
    expediente_numero: row.expediente_numero ?? null,
    numero_expediente: row.expediente_numero ?? row.id,
    condiciones: cond,
  }
}

/** Cálculo cuota francesa */
export function cuotaFrancesa(monto, plazo, tea = 43.92) {
  if (monto <= 0 || plazo <= 0) return 0
  const tep = Math.pow(1 + tea / 100, 1 / 12) - 1
  if (tep === 0) return Math.round((monto / plazo) * 100) / 100
  const factor = Math.pow(1 + tep, plazo)
  return Math.round((monto * (tep * factor)) / (factor - 1) * 100) / 100
}

/** Pre-evaluación crediticia */
export function preEvaluar(payload) {
  const ingresos = parseFloat(payload.ingresos_estimados || 0)
  const monto = parseFloat(payload.monto_solicitado || 0)
  const plazo = parseInt(payload.plazo_meses || 12)
  const cuota = cuotaFrancesa(monto, plazo)
  const ratio = ingresos > 0 ? cuota / ingresos : 999

  let puntaje = 85
  if (ingresos <= 0) puntaje = 40
  else if (ratio > 0.5) puntaje = 35
  else if (ratio > 0.35) puntaje = 55
  else if (ratio > 0.25) puntaje = 72
  if (monto > ingresos * 12) puntaje -= 15
  puntaje = Math.max(0, Math.min(100, puntaje))

  let calificacion, motivo
  if (puntaje >= 70) { calificacion = 'APTO'; motivo = 'Capacidad de pago compatible con el monto solicitado.' }
  else if (puntaje >= 45) { calificacion = 'REVISAR'; motivo = 'Relación cuota/ingreso elevada. Requiere visita y sustento.' }
  else { calificacion = 'NO_PROCEDE'; motivo = 'Ingresos insuficientes para el monto y plazo solicitados.' }

  return {
    calificacion,
    puntaje,
    motivo,
    cuota_estimada: cuota,
    ratio_cuota_ingreso: ingresos ? Math.round(ratio * 10000) / 10000 : null,
  }
}

/** Consulta buró simulada */
export function consultarBuro(dni) {
  if (dni.endsWith('999') || dni === '00000000') {
    return {
      calificacion_sbs: 'Perdida', entidades_con_deuda: 2, deuda_total: 15200.0,
      mayor_deuda: 12000.0, dias_mayor_mora: 180, en_lista_negra: true,
      motivo_bloqueo: 'Encontrado en lista de prevención de fraude Santander',
      interpretacion: 'Cliente inhabilitado para originación.',
    }
  }
  const last = /\d$/.test(dni) ? parseInt(dni.slice(-1)) : 5
  let rating = 'Normal', debt = 4500.0, mora = 0
  if (last === 3) { rating = 'CPP'; debt = 2500.0; mora = 15 }
  else if (last === 7) { rating = 'Deficiente'; debt = 8900.0; mora = 45 }
  else if (last === 0) { rating = 'Dudoso'; debt = 12000.0; mora = 85 }
  return {
    calificacion_sbs: rating,
    entidades_con_deuda: last % 2 ? 1 : 2,
    deuda_total: debt,
    mayor_deuda: debt * 0.7,
    dias_mayor_mora: mora,
    en_lista_negra: false,
    motivo_bloqueo: null,
    interpretacion: `Posición SBS ${rating}. ${mora === 0 ? 'Sin mora reportada.' : `Mora máxima ${mora} días.`}`,
  }
}
