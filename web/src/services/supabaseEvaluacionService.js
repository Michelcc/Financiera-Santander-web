/** Lógica de pre-evaluación y buró (misma regla que Core Mobile API). */

function cuotaFrancesa(monto, plazo, tea = 43.92) {
  if (monto <= 0 || plazo <= 0) return 0
  const tep = Math.pow(1 + tea / 100, 1 / 12) - 1
  if (tep === 0) return monto / plazo
  const factor = Math.pow(1 + tep, plazo)
  return (monto * tep * factor) / (factor - 1)
}

export function preEvaluarSupabase(payload) {
  const ingresos = Number(payload.ingresos_estimados) || 0
  const monto = Number(payload.monto_solicitado) || 0
  const plazo = Number(payload.plazo_meses) || 12
  const cuota = cuotaFrancesa(monto, plazo)
  const ratio = ingresos > 0 ? cuota / ingresos : 999

  let puntaje = 85
  if (ingresos <= 0) puntaje = 40
  else if (ratio > 0.5) puntaje = 35
  else if (ratio > 0.35) puntaje = 55
  else if (ratio > 0.25) puntaje = 72
  if (monto > ingresos * 12) puntaje -= 15
  puntaje = Math.max(0, Math.min(100, puntaje))

  if (puntaje >= 70) {
    return { calificacion: 'APTO', puntaje, motivo: 'Capacidad de pago compatible.', cuota_estimada: cuota }
  }
  if (puntaje >= 45) {
    return { calificacion: 'REVISAR', puntaje, motivo: 'Relación cuota/ingreso elevada.', cuota_estimada: cuota }
  }
  return { calificacion: 'NO_PROCEDE', puntaje, motivo: 'Ingresos insuficientes.', cuota_estimada: cuota }
}

export function consultarBuroSupabase({ dni }) {
  const doc = String(dni || '').trim()
  if (doc.endsWith('999') || doc === '00000000') {
    return {
      calificacion_sbs: 'Perdida',
      entidades_con_deuda: 2,
      deuda_total: 15200,
      mayor_deuda: 12000,
      dias_mayor_mora: 180,
      en_lista_negra: true,
      motivo_bloqueo: 'Lista de prevención de fraude',
      interpretacion: 'Cliente inhabilitado.',
    }
  }
  const last = parseInt(doc.slice(-1), 10) || 5
  let rating = 'Normal'
  let debt = 4500
  let mora = 0
  if (last === 3) { rating = 'CPP'; debt = 2500; mora = 15 }
  else if (last === 7) { rating = 'Deficiente'; debt = 8900; mora = 45 }
  else if (last === 0) { rating = 'Dudoso'; debt = 12000; mora = 85 }
  return {
    calificacion_sbs: rating,
    entidades_con_deuda: last % 2 ? 1 : 2,
    deuda_total: debt,
    mayor_deuda: debt * 0.7,
    dias_mayor_mora: mora,
    en_lista_negra: false,
    motivo_bloqueo: null,
    interpretacion: mora ? `Mora máxima ${mora} días.` : 'Sin mora reportada.',
  }
}
