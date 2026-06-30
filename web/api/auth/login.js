import { anonClient, codigoToEmail } from '../_lib/supabase.js'
import { CORS, error } from '../_lib/helpers.js'

export default async function handler(req, res) {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return res.setHeader('Access-Control-Allow-Origin', '*')
      .setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS')
      .setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      .status(204).end()
  }

  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v))

  if (req.method !== 'POST') return error(res, 'Método no permitido', 405)

  const { codigo_empleado, password } = req.body || {}
  if (!codigo_empleado || !password) return error(res, 'codigo_empleado y password requeridos', 400)

  const email = codigoToEmail(codigo_empleado)
  const sb = anonClient()

  let session, user
  try {
    const { data, error: authErr } = await sb.auth.signInWithPassword({ email, password })
    if (authErr || !data?.session) return error(res, 'Credenciales inválidas', 401)
    session = data.session
    user = data.user
  } catch (e) {
    return error(res, `Credenciales inválidas: ${e.message}`, 401)
  }

  // Buscar perfil del asesor
  const { data: perfiles } = await sb
    .from('perfiles_asesor')
    .select('*')
    .eq('id', user.id)
    .limit(1)

  const row = perfiles?.[0] || {}
  const codigo = row.codigo || codigo_empleado.trim().toUpperCase()
  const nombre = row.nombre || `Asesor ${codigo}`
  const parts = nombre.split(' ')

  return res.status(200).json({
    access_token: session.access_token,
    token_type: 'bearer',
    asesor: {
      id: user.id,
      codigo_empleado: codigo,
      nombres: parts[0],
      apellidos: parts.slice(1).join(' '),
      perfil: user.user_metadata?.role || 'Operador',
      agencia_id: row.sucursal || null,
    },
  })
}
