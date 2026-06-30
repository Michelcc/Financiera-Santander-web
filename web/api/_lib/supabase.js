import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL
const SUPABASE_SERVICE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY

/**
 * Client con el token JWT del usuario (RLS activo).
 * Se usa para todas las operaciones autenticadas.
 */
export function clientWithJWT(jwt) {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false },
  })
}

/**
 * Client anon — sólo para sign-in.
 */
export function anonClient() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { persistSession: false },
  })
}

/**
 * Extrae y verifica el Bearer token del header Authorization.
 * Devuelve { user, token } o null si no hay token / sesión inválida.
 */
export async function getUserFromRequest(req) {
  const auth = req.headers['authorization'] || ''
  const token = auth.replace(/^Bearer\s+/i, '').trim()
  if (!token) return null
  const sb = anonClient()
  try {
    const { data, error } = await sb.auth.getUser(token)
    if (error || !data?.user) return null
    return { user: data.user, token }
  } catch {
    return null
  }
}

/**
 * Convierte codigo_empleado → email Supabase.
 */
export function codigoToEmail(codigo) {
  return `${codigo.trim().toLowerCase().replace(/\s+/g, '')}@asesor.santander.pe`
}
