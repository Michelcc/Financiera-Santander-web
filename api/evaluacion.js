import { clientWithJWT, getUserFromRequest } from './_lib/supabase.js'
import { CORS, error, preEvaluar, consultarBuro } from './_lib/helpers.js'

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
  const { action } = req.query

  if (req.method === 'POST') {
    // POST /api/pre-evaluar
    if (action === 'pre-evaluar') {
      const result = preEvaluar(req.body || {})
      return res.status(200).json(result)
    }

    // POST /api/buro/consulta
    if (action === 'buro') {
      const { dni, consentimiento = true } = req.body || {}
      if (!dni) return error(res, 'dni requerido', 400)

      const result = consultarBuro(dni.trim())

      // Guardar en historial (no bloqueante)
      try {
        const sb = clientWithJWT(token)
        await sb.from('consultas_buro').insert({
          asesor_id: user.id,
          documento: dni,
          calificacion_sbs: result.calificacion_sbs,
          entidades_con_deuda: result.entidades_con_deuda,
          deuda_total_pen: result.deuda_total,
          mayor_deuda: result.mayor_deuda,
          dias_mayor_mora: result.dias_mayor_mora,
          consentimiento_firmado: consentimiento,
        })
      } catch (_) { /* ignorar errores de registro */ }

      return res.status(200).json(result)
    }
  }

  return error(res, 'Método no permitido', 405)
}
