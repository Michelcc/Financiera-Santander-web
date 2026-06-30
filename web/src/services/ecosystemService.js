import api from './api.js'
import { pingSupabase, getEcosistemaStats } from './supabaseDataService.js'

/** Verifica conectividad con FastAPI (puerto 8003) y Supabase. */
export async function checkEcosystemHealth() {
  const supabaseOk = await pingSupabase().catch(() => false)

  let apiOk = false
  let apiDetail = 'No disponible'
  try {
    const { status } = await api.get('/health', { timeout: 5000 })
    apiOk = status === 200
    apiDetail = 'Core Mobile activo'
  } catch {
    try {
      await api.get('/', { timeout: 3000 })
      apiOk = true
      apiDetail = 'API respondiendo'
    } catch (e) {
      apiDetail = e?.message?.includes('Network') ? 'Sin conexión' : 'Offline'
    }
  }

  let stats = null
  if (supabaseOk) {
    try {
      stats = await getEcosistemaStats()
    } catch (_) {}
  }

  return {
    supabase: { ok: supabaseOk, label: 'PostgreSQL / Supabase (BD única)' },
    fastapi: { ok: apiOk, label: 'API Mobile FVentas (FastAPI :8003)' },
    stats,
    modulos: [
      { nombre: 'App Fuerza de Ventas', tipo: 'Flutter', puerto: 'APK', conectado: supabaseOk },
      { nombre: 'App Clientes', tipo: 'Flutter', puerto: 'APK', conectado: supabaseOk },
      { nombre: 'Front Banking', tipo: 'React', puerto: '5173', conectado: true },
      { nombre: 'Core Mobile API', tipo: 'FastAPI', puerto: '8003', conectado: apiOk },
    ],
    apiDetail,
  }
}
