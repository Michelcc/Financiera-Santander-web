import api from './api.js'
import { productividadSupabase } from './supabaseDataService.js'

/** Reporte de productividad mensual por asesor — FastAPI o Supabase RPC real. */
export async function productividad() {
  try {
    const { data } = await api.get('/reportes/productividad')
    return data
  } catch {
    return productividadSupabase()
  }
}
