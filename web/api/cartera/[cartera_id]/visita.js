import { clientWithJWT, getUserFromRequest } from '../../_lib/supabase.js'
import { CORS, error } from '../../_lib/helpers.js'

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

  const { user, token } = auth
  const { cartera_id } = req.query

  if (!cartera_id) return error(res, 'cartera_id requerido', 400)

  if (req.method === 'POST') {
    const { resultado, observacion, latitud, longitud } = req.body || {}
    if (!resultado) return error(res, 'resultado requerido', 400)

    const sb = clientWithJWT(token)
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

  return error(res, 'Método no permitido', 405)
}
