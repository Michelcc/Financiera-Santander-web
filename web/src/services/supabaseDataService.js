import { supabase } from '../lib/supabase.js'

function mapCliente(row, visita = null) {
  return {
    id: row.id,
    cliente_id: row.id,
    cliente_nombre: row.nombre,
    documento: row.documento,
    telefono: row.telefono,
    negocio_nombre: row.negocio_nombre,
    tipo_gestion: row.tipo_gestion,
    prioridad: row.prioridad ?? 3,
    score_prioridad: row.score_final ?? row.score_transaccional ?? 500,
    score_final: row.score_final,
    segmento: row.segmento,
    mora_dias: row.mora_dias ?? 0,
    monto_credito: row.monto_preaprobado ?? row.hipotesis_credito ?? 0,
    estado_visita: visita?.resultado ?? visita?.estado_visita ?? 'pendiente',
    latitud: row.latitud,
    longitud: row.longitud,
  }
}

function mapSolicitud(row) {
  const dp = row.datos_personales ?? {}
  const cond = row.condiciones ?? {}
  const montoSol = cond.monto ?? row.monto_aprobado ?? 0
  return {
    id: row.id,
    cliente_id: row.cliente_id,
    documento: row.documento_cliente ?? dp.documento,
    cliente_nombre: dp.nombre ?? dp.nombres ?? 'Cliente',
    estado: (row.estado ?? 'borrador').toLowerCase(),
    monto: montoSol,
    monto_solicitado: montoSol,
    monto_aprobado: row.monto_aprobado ?? null,
    plazo: row.plazo_aprobado ?? cond.plazo ?? 6,
    cuota_mensual: row.cuota_mensual,
    segmento: row.segmento,
    score_final: row.score_final,
    created_at: row.created_at,
    expediente_numero: row.expediente_numero,
    numero_expediente: row.expediente_numero ?? row.id,
    condiciones: cond,
  }
}

async function currentAsesorId() {
  const { data } = await supabase.auth.getUser()
  return data.user?.id ?? null
}

/** Cartera del asesor autenticado desde Supabase (misma BD que apps móviles). */
export async function listarCarteraSupabase() {
  const asesorId = await currentAsesorId()
  if (!asesorId) return []

  const { data: clientes, error } = await supabase
    .from('clientes')
    .select('*')
    .eq('asesor_id', asesorId)
    .order('prioridad')

  if (error) throw error
  if (!clientes?.length) return []

  const ids = clientes.map((c) => c.id)
  const hoy = new Date().toISOString().slice(0, 10)
  const { data: visitas } = await supabase
    .from('visitas')
    .select('cliente_id, resultado, created_at')
    .eq('asesor_id', asesorId)
    .gte('created_at', `${hoy}T00:00:00`)

  const visitaMap = {}
  for (const v of visitas ?? []) {
    visitaMap[v.cliente_id] = v
  }

  return clientes.map((c) => mapCliente(c, visitaMap[c.id]))
}

export async function marcarVisitaSupabase(carteraId, payload) {
  const asesorId = await currentAsesorId()
  if (!asesorId) throw new Error('Sesión expirada')

  const visitId = `vis_${carteraId}_${Date.now()}`
  const { error } = await supabase.from('visitas').upsert({
    id: visitId,
    asesor_id: asesorId,
    cliente_id: carteraId,
    resultado: payload.resultado,
    observacion: payload.observacion ?? '',
    latitud: payload.latitud ?? null,
    longitud: payload.longitud ?? null,
  })
  if (error) throw error
  return { ok: true, id: visitId }
}

export async function listarSolicitudesSupabase() {
  const asesorId = await currentAsesorId()
  if (!asesorId) return []

  const { data, error } = await supabase
    .from('solicitudes')
    .select('*')
    .eq('asesor_id', asesorId)
    .order('created_at', { ascending: false })

  if (error) throw error
  return (data ?? []).map(mapSolicitud)
}

export async function listarClientesMoraSupabase() {
  const asesorId = await currentAsesorId()
  if (!asesorId) return []

  const { data, error } = await supabase
    .from('clientes')
    .select('*')
    .eq('asesor_id', asesorId)
    .gt('mora_dias', 0)
    .order('mora_dias', { ascending: false })

  if (error) throw error
  return (data ?? []).map((c) => ({
    ...mapCliente(c),
    deuda_total: c.deuda_total ?? 0,
    dias_mora: c.mora_dias ?? 0,
  }))
}

export async function getFichaClienteSupabase(clienteId) {
  const { data: cliente, error } = await supabase
    .from('clientes')
    .select('*')
    .eq('id', clienteId)
    .maybeSingle()

  if (error) throw error
  if (!cliente) throw new Error('Cliente no encontrado')

  const { data: creditos } = await supabase
    .from('creditos')
    .select('*')
    .eq('cliente_id', clienteId)

  const { data: solicitudes } = await supabase
    .from('solicitudes')
    .select('*')
    .eq('cliente_id', clienteId)
    .order('created_at', { ascending: false })
    .limit(5)

  return {
    cliente: mapCliente(cliente),
    creditos: creditos ?? [],
    solicitudes: (solicitudes ?? []).map(mapSolicitud),
    oferta: {
      monto_preaprobado: cliente.monto_preaprobado,
      plazo: cliente.plazo_preaprobado,
      tasa: cliente.tasa_preaprobada,
      segmento: cliente.segmento,
    },
  }
}

export async function getEcosistemaStats() {
  const asesorId = await currentAsesorId()

  const counts = {}
  const tables = [
    'clientes',
    'solicitudes',
    'visitas',
    'prospectos',
    'sync_queue',
    'creditos',
    'perfiles_cliente',
  ]

  for (const tabla of tables) {
    let q = supabase.from(tabla).select('*', { count: 'exact', head: true })
    if (asesorId && ['clientes', 'solicitudes', 'visitas', 'prospectos', 'sync_queue'].includes(tabla)) {
      q = q.eq('asesor_id', asesorId)
    }
    const { count, error } = await q
    counts[tabla] = error ? '—' : (count ?? 0)
  }

  const { count: pendientesSync } = await supabase
    .from('sync_queue')
    .select('*', { count: 'exact', head: true })
    .eq('procesado', false)

  return { counts, pendientesSync: pendientesSync ?? 0 }
}

export async function pingSupabase() {
  const { error } = await supabase.from('perfiles_asesor').select('id').limit(1)
  return !error
}

function normalizeSolicitudCreada(data) {
  if (!data || typeof data !== 'object') return data
  return {
    id: data.id,
    numero_expediente: data.numero_expediente ?? data.expediente_numero ?? data.id,
    expediente_numero: data.expediente_numero ?? data.numero_expediente ?? data.id,
    estado: (data.estado ?? 'enviado').toLowerCase(),
    cuota_mensual: data.cuota_mensual,
  }
}

export async function crearSolicitudSupabase(payload) {
  const params = {
    p_documento: payload.numero_documento,
    p_nombres: [payload.nombres, payload.apellidos].filter(Boolean).join(' ').trim(),
    p_monto: payload.monto_solicitado,
    p_plazo: payload.plazo_meses,
    p_telefono: payload.telefono ?? null,
    p_tipo_negocio: payload.tipo_negocio ?? null,
    p_nombre_negocio: payload.nombre_negocio ?? null,
    p_destino: payload.destino_credito ?? null,
    p_tea: payload.tea_referencial ? Number(payload.tea_referencial) : 43.92,
  }
  const { data, error } = await supabase.rpc('crear_solicitud_desde_asesor', params)
  if (error) {
    throw new Error(
      error.message?.includes('Could not find the function')
        ? 'Falta la función en Supabase. Ejecute supabase_solicitudes_web.sql en el SQL Editor.'
        : error.message,
    )
  }
  return normalizeSolicitudCreada(data)
}

export async function resolverSolicitudSupabase(id, decision, opts = {}) {
  const { error } = await supabase.rpc('resolver_solicitud', {
    p_solicitud_id: id,
    p_decision: decision,
    p_monto_aprobado: opts.monto ?? null,
    p_plazo: opts.plazo ?? null,
    p_motivo: opts.motivo ?? null,
  })
  if (error) throw error
  return { ok: true }
}

export async function listarNotasSupabase(solicitudId) {
  const { data, error } = await supabase
    .from('solicitudes_notas_internas')
    .select('*')
    .eq('solicitud_id', solicitudId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []).map((n) => ({
    contenido: n.nota,
    created_at: n.created_at,
  }))
}

export async function agregarNotaSupabase(solicitudId, contenido) {
  const asesorId = await currentAsesorId()
  if (!asesorId) throw new Error('Sesión expirada')
  const { error } = await supabase.from('solicitudes_notas_internas').insert({
    solicitud_id: solicitudId,
    asesor_id: asesorId,
    nota: contenido,
  })
  if (error) throw error
  return { ok: true }
}

export async function listarNotificacionesSupabase(perfil = 'operador') {
  const asesorId = await currentAsesorId()
  if (!asesorId) return []

  const isSupervisor = ['supervisor', 'administrador', 'super operador'].includes(
    String(perfil).toLowerCase(),
  )

  let q = supabase
    .from('notificaciones_supervisor')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(50)

  if (isSupervisor) {
    q = q.in('audiencia', ['supervisor', 'todos'])
  } else {
    q = q.eq('asesor_id', asesorId).in('audiencia', ['asesor', 'todos'])
  }

  const { data, error } = await q
  if (error) throw error
  return data ?? []
}

export async function marcarNotificacionLeidaSupabase(id) {
  const { error } = await supabase
    .from('notificaciones_supervisor')
    .update({ leida: true })
    .eq('id', id)
  if (error) throw error
}

export async function productividadSupabase() {
  const { data, error } = await supabase.rpc('productividad_asesores')
  if (!error && data?.length) {
    return (data ?? []).map((r) => ({
      asesor_nombre: r.asesor_nombre,
      codigo: r.codigo,
      enviadas: Number(r.enviadas ?? 0),
      aprobadas: Number(r.aprobadas ?? 0),
      monto_total: Number(r.monto_total ?? 0),
    }))
  }

  const { data: asesores, error: errA } = await supabase
    .from('perfiles_asesor')
    .select('id, nombre, codigo')

  if (errA) throw errA

  const inicioMes = new Date()
  inicioMes.setDate(1)
  inicioMes.setHours(0, 0, 0, 0)

  const { data: solicitudes, error: errS } = await supabase
    .from('solicitudes')
    .select('asesor_id, estado, monto_aprobado, created_at')
    .gte('created_at', inicioMes.toISOString())

  if (errS) throw errS

  const map = new Map()
  for (const a of asesores ?? []) {
    map.set(a.id, {
      asesor_nombre: a.nombre,
      codigo: a.codigo,
      enviadas: 0,
      aprobadas: 0,
      monto_total: 0,
    })
  }

  for (const s of solicitudes ?? []) {
    const row = map.get(s.asesor_id)
    if (!row) continue
    const est = (s.estado ?? '').toLowerCase()
    if (est.includes('enviad') || est.includes('pendient') || est.includes('borrador')) {
      row.enviadas += 1
    }
    if (est.includes('aprob') || est.includes('desembols')) {
      row.aprobadas += 1
    }
    if (est.includes('desembols')) {
      row.monto_total += Number(s.monto_aprobado ?? 0)
    }
  }

  return [...map.values()]
}

/** Suscripción Realtime — devuelve función unsubscribe */
export function suscribirTabla(tabla, onChange) {
  const channel = supabase
    .channel(`rt-${tabla}-${Date.now()}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: tabla }, onChange)
    .subscribe()
  return () => {
    supabase.removeChannel(channel)
  }
}
