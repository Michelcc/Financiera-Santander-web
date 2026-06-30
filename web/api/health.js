import { anonClient } from '../_lib/supabase.js'
import { CORS } from '../_lib/helpers.js'

export default async function handler(req, res) {
  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v))
  if (req.method === 'OPTIONS') return res.status(204).end()

  let dbOk = false
  try {
    const sb = anonClient()
    const { error } = await sb.from('perfiles_asesor').select('id').limit(1)
    dbOk = !error
  } catch (_) {}

  return res.status(200).json({
    sistema: 'Core Mobile Santander Consumer Perú',
    version: '1.0.0',
    status: 'ok',
    supabase: dbOk ? 'conectado' : 'error',
    timestamp: new Date().toISOString(),
  })
}
