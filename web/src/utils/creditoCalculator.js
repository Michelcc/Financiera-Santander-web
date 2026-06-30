/** Tarifario Crédito Empresarial — Microempresa (PDF enunciados). */
export const TEA_CON_SEGURO = 0.4092
export const TEA_SIN_SEGURO = 0.4392

export const ESTADOS_EXPEDIENTE = [
  'borrador',
  'enviado',
  'recibido_comite',
  'en_evaluacion',
  'aprobado',
  'condicionado',
  'rechazado',
  'desembolsado',
]

export const PASOS_FLUJO = [
  { paso: 1, rol: 'Cliente', titulo: 'Registrar solicitud', app: 'App Clientes' },
  { paso: 2, rol: 'Core', titulo: 'Recepción y cola sync', app: 'API / Supabase' },
  { paso: 3, rol: 'Asesor', titulo: 'Cartera NUEVA_SOLICITUD', app: 'App FVentas / Web' },
  { paso: 4, rol: 'Asesor', titulo: 'Visita en campo (GPS)', app: 'App FVentas' },
  { paso: 5, rol: 'Asesor', titulo: 'Pre-evaluación + buró', app: 'App FVentas / Web' },
  { paso: 6, rol: 'Asesor', titulo: 'Documentos y firma', app: 'App FVentas' },
  { paso: 7, rol: 'Core', titulo: 'Promover a comité', app: 'sync_outbox → núcleo' },
  { paso: 8, rol: 'Comité', titulo: 'Decisión y desembolso', app: 'Front Banking / Core' },
]

/** TEM = (1 + TEA)^(1/12) − 1 */
export function teaToTem(tea) {
  return Math.pow(1 + tea, 1 / 12) - 1
}

/** Cuota fija — amortización francesa. */
export function calcularCuota(monto, plazoMeses, tea, conSeguro = false) {
  const teaAplicada = conSeguro ? TEA_CON_SEGURO : TEA_SIN_SEGURO
  const tasa = tea ?? teaAplicada
  const tem = teaToTem(tasa)
  if (plazoMeses <= 0 || monto <= 0) return 0
  if (tem === 0) return monto / plazoMeses
  const factor = Math.pow(1 + tem, plazoMeses)
  return (monto * tem * factor) / (factor - 1)
}

/** Cronograma completo cuotas iguales. */
export function generarCronograma(monto, plazoMeses, tea, conSeguro, fechaDesembolso, diaPago) {
  const cuota = calcularCuota(monto, plazoMeses, tea, conSeguro)
  const tem = teaToTem(tea ?? (conSeguro ? TEA_CON_SEGURO : TEA_SIN_SEGURO))
  let saldo = monto
  const filas = []
  const base = fechaDesembolso ? new Date(fechaDesembolso) : new Date()

  for (let n = 1; n <= plazoMeses; n++) {
    const interes = saldo * tem
    const capital = cuota - interes
    saldo = Math.max(0, saldo - capital)

    const fecha = new Date(base)
    fecha.setMonth(fecha.getMonth() + n)
    fecha.setDate(diaPago ?? 3)

    filas.push({
      n,
      fecha: fecha.toISOString().slice(0, 10),
      cuota: round2(cuota),
      capital: round2(capital),
      interes: round2(interes),
      saldo: round2(saldo),
    })
  }
  return filas
}

function round2(n) {
  return Math.round(n * 100) / 100
}

/** Buró simulado por último dígito del DNI (PDF). */
export function buroPorDocumento(documento) {
  const doc = String(documento)
  if (doc.endsWith('999') || doc === '00000000') {
    return { sbs: 'PERDIDA', entidades: 4, deuda: 40000, mora: 210, inhabilitado: true }
  }
  const d = parseInt(doc.slice(-1), 10)
  if (d === 0) return { sbs: 'DUDOSO', entidades: 3, deuda: 25000, mora: 95 }
  if (d === 3) return { sbs: 'CPP', entidades: 1, deuda: 9000, mora: 20 }
  if (d === 4) return { sbs: 'NORMAL', entidades: 2, deuda: 14000, mora: 0 }
  if (d === 6) return { sbs: 'NORMAL', entidades: 0, deuda: 0, mora: 0 }
  if (d === 7) return { sbs: 'DEFICIENTE', entidades: 2, deuda: 16000, mora: 45 }
  if (d === 8) return { sbs: 'CPP', entidades: 2, deuda: 18000, mora: 15 }
  if (d === 1) return { sbs: 'NORMAL', entidades: 1, deuda: 4500, mora: 0 }
  if (d === 2) return { sbs: 'NORMAL', entidades: 2, deuda: 12000, mora: 0 }
  if (d === 5) return { sbs: 'NORMAL', entidades: 2, deuda: 12000, mora: 0 }
  if (d === 9) return { sbs: 'NORMAL', entidades: 2, deuda: 12000, mora: 0 }
  return { sbs: 'NORMAL', entidades: 1, deuda: 6000, mora: 0 }
}

export function preEvaluacionCapacidad(ingreso, gasto, cuota) {
  const disponible = ingreso - gasto
  if (disponible <= 0) return { resultado: 'NO_PROCEDE', puntaje: 40 }
  const ratio = cuota / disponible
  if (ratio > 0.5) return { resultado: 'REVISAR', puntaje: 60 }
  if (ratio > 0.35) return { resultado: 'APTO', puntaje: 75 }
  return { resultado: 'APTO', puntaje: 85 }
}
