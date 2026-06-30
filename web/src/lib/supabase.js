import { createClient } from '@supabase/supabase-js'

const supabaseUrl =
  import.meta.env.VITE_SUPABASE_URL ||
  'https://jyuclilkqegictxmunfb.supabase.co'

const supabaseAnonKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  'sb_publishable_1MEOuTvmRbHlDXDFelOtrQ_JPtyRAIN'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

export function codigoToEmail(codigo) {
  const clean = String(codigo).trim().toLowerCase().replace(/\s+/g, '')
  return `${clean}@asesor.santander.pe`
}
