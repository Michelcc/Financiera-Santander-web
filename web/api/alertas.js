import { clientWithJWT, getUserFromRequest } from '../_lib/supabase.js'
import { CORS, error } from '../_lib/helpers.js'

export default async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    return res.setHeader('Access-Control-Allow-Origin', '*')
      .setHeader('Access-Control-Allow-Methods', 'GET,PATCH,OPTIONS')
      .setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      .status(204).end()
  }
  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v))

  const auth = await getUserFromRequest(req)
  if (!auth) return error(res, 'Token requerido', 401)

  const { user, token } = auth
  const sb = clientWithJWT(token)

  const isSupervisor = ['supervisor', 'administrador', 'super operador']
    .includes(String(user.user_metadata?.role || '').toLowerCase())

  // GET /api/alertas
  if (req.method === 'GET') {
    let q = sb.from('notificaciones_supervisor')
      .select('*').order('created_at', { ascending: false }).limit(50)

    if (isSupervisor) {
      q = q.in('audiencia', ['supervisor', 'todos'])
    } else {
      q = q.eq('asesor_id', user.id).in('audiencia', ['asesor', 'todos'])
    }

    const { data, error: dbErr } = await q
    if (dbErr) return error(res, dbErr.message, 500)
    return res.status(200).json(data || [])
  }

  // PATCH /api/alertas?id=xxx (marcar leída)
  if (req.method === 'PATCH') {
    const { id } = req.query
    if (!id) return error(res, 'id requerido', 400)
    const { error: updErr } = await sb
      .from('notificaciones_supervisor').update({ leida: true }).eq('id', id)
    if (updErr) return error(res, updErr.message, 500)
    return res.status(200).json({ ok: true })
  }

  return error(res, 'Método no permitido', 405)
}
