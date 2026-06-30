import { getUserFromRequest } from '../_lib/supabase.js'
import { CORS, error, preEvaluar } from '../_lib/helpers.js'

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

  if (req.method === 'POST') {
    const result = preEvaluar(req.body || {})
    return res.status(200).json(result)
  }

  return error(res, 'Método no permitido', 405)
}
