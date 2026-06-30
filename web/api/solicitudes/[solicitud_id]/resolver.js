import { clientWithJWT, getUserFromRequest } from '../../../_lib/supabase.js'
import { CORS, error } from '../../../_lib/helpers.js'

export default async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    return res.setHeader('Access-Control-Allow-Origin', '*')
      .setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS')
      .setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      .status(204).end()
  }
  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v))

  const auth = await getUserFromRequest(req)
  if (!auth) return error(res, 'Token requerido', 401)

  const { token } = auth
  const { solicitud_id } = req.query
  if (!solicitud_id) return error(res, 'solicitud_id requerido', 400)

  if (req.method === 'POST') {
    const { decision, monto, plazo, motivo } = req.body || {}
    if (!decision) return error(res, 'decision requerida', 400)

    const sb = clientWithJWT(token)
    const { error: rpcErr } = await sb.rpc('resolver_solicitud', {
      p_solicitud_id: solicitud_id,
      p_decision: decision.toUpperCase(),
      p_monto_aprobado: monto ?? null,
      p_plazo: plazo ?? null,
      p_motivo: motivo ?? null,
    })
    if (rpcErr) return error(res, rpcErr.message, 500)
    return res.status(200).json({ ok: true })
  }

  return error(res, 'Método no permitido', 405)
}
