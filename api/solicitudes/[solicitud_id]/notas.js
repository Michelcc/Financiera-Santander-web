import { clientWithJWT, getUserFromRequest } from '../../../_lib/supabase.js'
import { CORS, error } from '../../../_lib/helpers.js'

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
  const { solicitud_id } = req.query
  if (!solicitud_id) return error(res, 'solicitud_id requerido', 400)

  const sb = clientWithJWT(token)

  // GET /api/solicitudes/[solicitud_id]/notas
  if (req.method === 'GET') {
    const { data, error: dbErr } = await sb
      .from('solicitudes_notas_internas')
      .select('*')
      .eq('solicitud_id', solicitud_id)
      .order('created_at', { ascending: false })
    if (dbErr) return error(res, dbErr.message, 500)
    return res.status(200).json(
      (data || []).map((n) => ({ contenido: n.nota, created_at: n.created_at }))
    )
  }

  // POST /api/solicitudes/[solicitud_id]/notas
  if (req.method === 'POST') {
    const { contenido } = req.body || {}
    if (!contenido) return error(res, 'contenido requerido', 400)

    const { error: insErr } = await sb.from('solicitudes_notas_internas').insert({
      solicitud_id,
      asesor_id: user.id,
      nota: contenido,
    })
    if (insErr) return error(res, insErr.message, 500)
    return res.status(200).json({ ok: true })
  }

  return error(res, 'Método no permitido', 405)
}
