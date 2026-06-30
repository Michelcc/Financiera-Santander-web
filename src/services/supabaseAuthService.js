import { supabase, codigoToEmail } from '../lib/supabase.js'

export async function loginWithSupabase(codigoEmpleado, password) {
  const email = codigoToEmail(codigoEmpleado)
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })
  if (error) throw error

  const uid = data.user.id
  const { data: perfil } = await supabase
    .from('perfiles_asesor')
    .select('*')
    .eq('id', uid)
    .maybeSingle()

  const codigo =
    perfil?.codigo ?? codigoEmpleado.trim().toUpperCase()
  const nombre = perfil?.nombre ?? `Asesor ${codigo}`

  const user = {
    id: uid,
    codigo_empleado: codigo,
    nombres: nombre.split(' ')[0] ?? nombre,
    apellidos: nombre.split(' ').slice(1).join(' ') ?? '',
    nombre,
    perfil: data.user.user_metadata?.role ?? 'Operador',
    agencia_id: perfil?.sucursal ?? null,
    fuente: 'supabase',
  }

  return { token: data.session.access_token, user }
}

export async function logoutSupabase() {
  await supabase.auth.signOut()
}

export async function restoreSupabaseSession() {
  const { data } = await supabase.auth.getSession()
  if (!data.session) return null

  const uid = data.session.user.id
  const { data: perfil } = await supabase
    .from('perfiles_asesor')
    .select('*')
    .eq('id', uid)
    .maybeSingle()

  const email = data.session.user.email ?? ''
  const codigo =
    perfil?.codigo ?? email.split('@')[0]?.toUpperCase() ?? 'OP001'
  const nombre = perfil?.nombre ?? `Asesor ${codigo}`

  return {
    token: data.session.access_token,
    user: {
      id: uid,
      codigo_empleado: codigo,
      nombres: nombre.split(' ')[0] ?? nombre,
      apellidos: nombre.split(' ').slice(1).join(' ') ?? '',
      nombre,
      perfil: data.session.user.user_metadata?.role ?? 'Operador',
      agencia_id: perfil?.sucursal ?? null,
      fuente: 'supabase',
    },
  }
}
