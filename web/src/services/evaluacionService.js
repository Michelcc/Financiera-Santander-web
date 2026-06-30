import api from './api.js'
import { preEvaluarSupabase, consultarBuroSupabase } from './supabaseEvaluacionService.js'

export async function preEvaluar(payload) {
  try {
    const { data } = await api.post('/pre-evaluar', payload)
    return data
  } catch {
    return preEvaluarSupabase(payload)
  }
}

export async function consultarBuro(payload) {
  try {
    const { data } = await api.post('/buro/consulta', payload)
    return data
  } catch {
    return consultarBuroSupabase(payload)
  }
}
