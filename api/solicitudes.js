import { clientWithJWT, getUserFromRequest } from './_lib/supabase.js'
import { CORS, error, mapSolicitud } from './_lib/helpers.js'

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

  const { solicitud_id, action } = req.query

  // POST /api/solicitudes/[solicitud_id]/resolver
  if (solicitud_id && action === 'resolver') {
    if (req.method !== 'POST') return error(res, 'Método no permitido', 405)
    const { decision, monto, plazo, motivo } = req.body || {}
    if (!decision) return error(res, 'decision requerida', 400)

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

  // GET/POST /api/solicitudes/[solicitud_id]/notas
  if (solicitud_id && action === 'notas') {
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

  // GET /api/solicitudes
  if (req.method === 'GET') {
    const { data, error: dbErr } = await sb
      .from('solicitudes')
      .select('*')
      .eq('asesor_id', user.id)
      .order('created_at', { ascending: false })
    if (dbErr) return error(res, dbErr.message, 500)
    return res.status(200).json((data || []).map(mapSolicitud))
  }

  // POST /api/solicitudes
  if (req.method === 'POST') {
    const body = req.body || {}
    const nombre = `${body.nombres || ''} ${body.apellidos || ''}`.trim()

    const { data, error: rpcErr } = await sb.rpc('crear_solicitud_desde_asesor', {
      p_documento: (body.numero_documento || '').trim(),
      p_nombres: nombre,
      p_monto: body.monto_solicitado,
      p_plazo: body.plazo_meses || 12,
      p_telefono: body.telefono || null,
      p_tipo_negocio: body.tipo_negocio || null,
      p_nombre_negocio: body.nombre_negocio || null,
      p_destino: body.destino_credito || null,
      p_tea: body.tea_referencial ?? 43.92,
    })

    if (rpcErr) return error(res, rpcErr.message, 500)
    const d = data || {}
    return res.status(200).json({
      id: d.id,
      numero_expediente: d.expediente_numero || d.numero_expediente || d.id,
      expediente_numero: d.expediente_numero || d.id,
      estado: (d.estado || 'enviado').toLowerCase(),
      cuota_mensual: d.cuota_mensual || null,
    })
  }

  return error(res, 'Método no permitido', 405)
}
