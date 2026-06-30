import api, { TOKEN_KEY, USER_KEY } from './api.js'
import {
  loginWithSupabase,
  logoutSupabase,
  restoreSupabaseSession,
} from './supabaseAuthService.js'

function normalizeApiUser(a, codigoEmpleado) {
  return {
    id: a.id,
    codigo_empleado: a.codigo_empleado ?? codigoEmpleado,
    nombres: a.nombres ?? '',
    apellidos: a.apellidos ?? '',
    nombre:
      `${a.nombres ?? ''} ${a.apellidos ?? ''}`.trim() || codigoEmpleado,
    perfil: a.perfil ?? 'operador',
    agencia_id: a.agencia_id ?? null,
    fuente: 'fastapi',
  }
}

/**
 * Login híbrido: FastAPI (8003) → fallback Supabase (misma BD que apps móviles).
 */
export async function login(codigoEmpleado, password) {
  const codigo = codigoEmpleado.trim()
  try {
    const { data } = await api.post('/auth/login', {
      codigo_empleado: codigo,
      password,
    })
    const token = data.access_token
    const user = normalizeApiUser(data.asesor || {}, codigo)
    return { token, user }
  } catch {
    return loginWithSupabase(codigo, password)
  }
}

export function saveSession(token, user) {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(USER_KEY, JSON.stringify(user))
}

export async function clearSession() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
  await logoutSupabase().catch(() => {})
}

export function getStoredToken() {
  return localStorage.getItem(TOKEN_KEY)
}

export function getStoredUser() {
  try {
    const raw = localStorage.getItem(USER_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export async function tryRestoreSession() {
  const stored = getStoredToken()
  if (stored) {
    const user = getStoredUser()
    if (user) return { token: stored, user }
  }
  return restoreSupabaseSession()
}
