import { clientWithJWT, getUserFromRequest } from './_lib/supabase.js'
import { CORS, error, mapCliente } from './_lib/helpers.js'

export default async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    return res.setHeader('Access-Control-Allow-Origin', '*')
      .setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
      .setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      .status(204).end()
  }
  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v))

  const auth = await getUserFromRequest(req)
  if (!auth) return error(res, 'Token requerido', 401)

  const { user, token } = auth
  const sb = clientWithJWT(token)

  // POST /api/cartera/:cartera_id/visita
  const { cartera_id } = req.query
  if (cartera_id) {
    if (req.method !== 'POST') return error(res, 'Método no permitido', 405)
    const { resultado, observacion, latitud, longitud } = req.body || {}
    if (!resultado) return error(res, 'resultado requerido', 400)

    const visitId = `vis_${cartera_id}_${Date.now()}`
    const { error: upsertErr } = await sb.from('visitas').upsert({
      id: visitId,
      asesor_id: user.id,
      cliente_id: cartera_id,
      resultado,
      observacion: observacion || '',
      latitud: latitud ?? null,
      longitud: longitud ?? null,
    })

    if (upsertErr) return error(res, upsertErr.message, 500)
    return res.status(200).json({ ok: true, id: visitId })
  }

  // GET /api/cartera
  if (req.method === 'GET') {
    const hoy = new Date().toISOString().slice(0, 10)

    // Intentar función RPC primero
    let rows = []
    try {
      const { data: rpcData } = await sb.rpc('get_mi_cartera')
      if (rpcData?.length) rows = rpcData
    } catch (_) { /* fallback a tabla directa */ }

    if (!rows.length) {
      const { data: clientes } = await sb
        .from('clientes')
        .select('*')
        .eq('asesor_id', user.id)
        .order('prioridad')
      rows = clientes || []

      // Si no tiene cartera asignada, devolver lista general
      if (!rows.length) {
        const { data: all } = await sb.from('clientes').select('*').order('prioridad').limit(100)
        rows = all || []
      }
    }

    const { data: visitas } = await sb
      .from('visitas')
      .select('cliente_id, resultado, created_at')
      .eq('asesor_id', user.id)
      .gte('created_at', `${hoy}T00:00:00`)

    const visitaMap = {}
    for (const v of visitas || []) visitaMap[v.cliente_id] = v

    return res.status(200).json(rows.map((c) => mapCliente(c, visitaMap[c.id])))
  }

  return error(res, 'Método no permitido', 405)
}
