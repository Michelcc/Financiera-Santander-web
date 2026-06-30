import api from './api.js'
import { listarClientesMoraSupabase } from './supabaseDataService.js'
import { supabase } from '../lib/supabase.js'

export async function listarMora() {
  try {
    const { data } = await api.get('/cobranza/mora')
    return data
  } catch {
    return listarClientesMoraSupabase()
  }
}

export async function registrarAccion(payload) {
  try {
    const { data } = await api.post('/cobranza/accion', payload)
    return data
  } catch {
    const { data: userData } = await supabase.auth.getUser()
    const asesorId = userData.user?.id
    if (!asesorId) throw new Error('Sesión expirada')
    const id = `cob_${payload.cliente_id}_${Date.now()}`
    const { error } = await supabase.from('acciones_cobranza').upsert({
      id,
      asesor_id: asesorId,
      cliente_id: payload.cliente_id,
      tipo: payload.tipo,
      observacion: payload.observacion ?? '',
      compromiso_fecha: payload.compromiso_fecha ?? null,
      compromiso_monto: payload.compromiso_monto ?? 0,
      latitud: payload.latitud ?? null,
      longitud: payload.longitud ?? null,
    })
    if (error) throw error
    return { ok: true, id }
  }
}
