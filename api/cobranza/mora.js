import { clientWithJWT, getUserFromRequest } from '../_lib/supabase.js'
import { CORS, error, mapCliente } from '../_lib/helpers.js'

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

  // GET /api/cobranza/mora
  if (req.method === 'GET') {
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

  return error(res, 'Método no permitido', 405)
}
