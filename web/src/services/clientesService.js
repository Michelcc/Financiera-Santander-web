import api from './api.js'
import { getFichaClienteSupabase } from './supabaseDataService.js'

export async function obtenerFicha(clienteId) {
  try {
    const { data } = await api.get(`/clientes/${clienteId}/ficha`)
    return data
  } catch {
    return getFichaClienteSupabase(clienteId)
  }
}
