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

  const { action } = req.query

  // GET /api/cobranza/mora
  if (action === 'mora') {
    if (req.method !== 'GET') return error(res, 'Método no permitido', 405)
    const { data, error: dbErr } = await sb
      .from('clientes')
      .select('*')
      .eq('asesor_id', user.id)
      .gt('mora_dias', 0)
      .order('mora_dias', { ascending: false })

    if (dbErr) return error(res, dbErr.message, 500)

    return res.status(200).json(
      (data || []).map((c) => ({
        ...mapCliente(c),
        deuda_total: c.deuda_total ?? 0,
        dias_mora: c.mora_dias ?? 0,
      }))
    )
  }

  // POST /api/cobranza/accion
  if (action === 'accion') {
    if (req.method !== 'POST') return error(res, 'Método no permitido', 405)
    const { cliente_id, tipo, observacion, compromiso_fecha, compromiso_monto, latitud, longitud } = req.body || {}
    if (!cliente_id || !tipo) return error(res, 'cliente_id y tipo requeridos', 400)

    const actionId = `cob_${cliente_id}_${Date.now()}`
    const { error: upsertErr } = await sb.from('acciones_cobranza').upsert({
      id: actionId,
      asesor_id: user.id,
      cliente_id,
      tipo,
      observacion: observacion || '',
      compromiso_fecha: compromiso_fecha || null,
      compromiso_monto: compromiso_monto || 0,
      latitud: latitud ?? null,
      longitud: longitud ?? null,
    })

    if (upsertErr) return error(res, upsertErr.message, 500)
    return res.status(200).json({ ok: true, id: actionId })
  }

  return error(res, 'Método no permitido', 405)
}
