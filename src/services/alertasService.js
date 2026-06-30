import api from './api.js'
import {
  listarNotificacionesSupabase,
  marcarNotificacionLeidaSupabase,
  suscribirTabla,
} from './supabaseDataService.js'

export async function listarAlertas(perfil) {
  try {
    const { data } = await api.get('/alertas')
    return data
  } catch {
    return listarNotificacionesSupabase(perfil)
  }
}

export async function marcarLeida(id) {
  try {
    await api.patch(`/alertas/${id}/leida`)
  } catch {
    await marcarNotificacionLeidaSupabase(id)
  }
}

export { suscribirTabla }
