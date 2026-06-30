import { clientWithJWT, getUserFromRequest } from '../_lib/supabase.js'
import { CORS, error } from '../_lib/helpers.js'

export default async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    return res.setHeader('Access-Control-Allow-Origin', '*')
      .setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS')
      .setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      .status(204).end()
  }
  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v))

  const auth = await getUserFromRequest(req)
  if (!auth) return error(res, 'Token requerido', 401)

  const { token } = auth

  if (req.method === 'GET') {
    const sb = clientWithJWT(token)

    // Intentar función RPC
    const { data: rpcData } = await sb.rpc('productividad_asesores')
    if (rpcData?.length) {
      return res.status(200).json(
        rpcData.map((r) => ({
          asesor_nombre: r.asesor_nombre,
          codigo: r.codigo,
          enviadas: Number(r.enviadas || 0),
          aprobadas: Number(r.aprobadas || 0),
          monto_total: Number(r.monto_total || 0),
        }))
      )
    }

    // Fallback manual
    const [{ data: asesores }, { data: solicitudes }] = await Promise.all([
      sb.from('perfiles_asesor').select('id, nombre, codigo'),
      sb.from('solicitudes').select('asesor_id, estado, monto_aprobado, created_at')
        .gte('created_at', new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString()),
    ])

    const map = new Map()
    for (const a of asesores || []) {
      map.set(a.id, { asesor_nombre: a.nombre, codigo: a.codigo, enviadas: 0, aprobadas: 0, monto_total: 0 })
    }
    for (const s of solicitudes || []) {
      const row = map.get(s.asesor_id)
      if (!row) continue
      const est = (s.estado || '').toLowerCase()
      if (est.includes('enviad') || est.includes('pendient') || est.includes('borrador')) row.enviadas++
      if (est.includes('aprob') || est.includes('desembols')) row.aprobadas++
      if (est.includes('desembols')) row.monto_total += Number(s.monto_aprobado || 0)
    }

    return res.status(200).json([...map.values()])
  }

  return error(res, 'Método no permitido', 405)
}
