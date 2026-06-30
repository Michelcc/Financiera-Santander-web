import api from './api.js'
import {
  listarCarteraSupabase,
  marcarVisitaSupabase,
} from './supabaseDataService.js'

/** Cartera del día — FastAPI o Supabase (BD compartida con apps móviles). */
export async function listarCartera(fecha) {
  try {
    const params = fecha ? { fecha } : {}
    const { data } = await api.get('/cartera', { params })
    return data
  } catch {
    return listarCarteraSupabase()
  }
}

export async function marcarVisita(carteraId, payload) {
  try {
    const { data } = await api.post(`/cartera/${carteraId}/visita`, payload)
    return data
  } catch {
    return marcarVisitaSupabase(carteraId, payload)
  }
}
