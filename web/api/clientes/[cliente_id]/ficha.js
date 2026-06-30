import { clientWithJWT, getUserFromRequest } from '../../_lib/supabase.js'
import { CORS, error, mapCliente, mapSolicitud } from '../../_lib/helpers.js'

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
  const { cliente_id } = req.query
  if (!cliente_id) return error(res, 'cliente_id requerido', 400)

  if (req.method === 'GET') {
    const sb = clientWithJWT(token)

    const { data: clientes, error: cErr } = await sb
      .from('clientes').select('*').eq('id', cliente_id).limit(1)
    if (cErr) return error(res, cErr.message, 500)
    if (!clientes?.length) return error(res, 'Cliente no encontrado', 404)

    const c = clientes[0]

    const [{ data: creditos }, { data: solicitudes }] = await Promise.all([
      sb.from('creditos').select('*').eq('cliente_id', cliente_id),
      sb.from('solicitudes').select('*').eq('cliente_id', cliente_id)
        .order('created_at', { ascending: false }).limit(5),
    ])

    return res.status(200).json({
      cliente: mapCliente(c),
      creditos: creditos || [],
      solicitudes: (solicitudes || []).map(mapSolicitud),
      oferta: {
        monto_preaprobado: c.monto_preaprobado ?? null,
        plazo: c.plazo_preaprobado ?? null,
        tasa: c.tasa_preaprobada ?? null,
        segmento: c.segmento ?? null,
      },
    })
  }

  return error(res, 'Método no permitido', 405)
}
