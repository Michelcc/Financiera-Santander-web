import api from './api.js'
import {
  listarSolicitudesSupabase,
  crearSolicitudSupabase,
  resolverSolicitudSupabase,
  listarNotasSupabase,
  agregarNotaSupabase,
} from './supabaseDataService.js'

export async function listarSolicitudes() {
  try {
    const { data } = await api.get('/solicitudes')
    return data
  } catch {
    return listarSolicitudesSupabase()
  }
}

export async function crearSolicitud(payload) {
  try {
    const { data } = await api.post('/solicitudes', payload)
    return data
  } catch {
    return crearSolicitudSupabase(payload)
  }
}

export async function resolverSolicitud(id, decision, opts = {}) {
  try {
    const { data } = await api.post(`/solicitudes/${id}/resolver`, {
      decision,
      ...opts,
    })
    return data
  } catch {
    return resolverSolicitudSupabase(id, decision, opts)
  }
}

export async function listarNotas(solicitudId) {
  try {
    const { data } = await api.get(`/solicitudes/${solicitudId}/notas`)
    return data
  } catch {
    return listarNotasSupabase(solicitudId)
  }
}

export async function agregarNota(solicitudId, contenido) {
  try {
    const { data } = await api.post(`/solicitudes/${solicitudId}/notas`, {
      contenido,
    })
    return data
  } catch {
    return agregarNotaSupabase(solicitudId, contenido)
  }
}
