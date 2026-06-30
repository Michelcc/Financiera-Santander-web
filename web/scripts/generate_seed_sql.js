/**
 * Regenera supabase_seed_30_casos.sql desde web/src/data/casosCredito30.js
 * Uso: node web/scripts/generate_seed_sql.js
 */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { CASOS_CREDITO_30 } from '../src/data/casosCredito30.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.join(__dirname, '../..')
const outPath = path.join(rootDir, 'supabase_seed_30_casos.sql')
const bootstrapPath = path.join(rootDir, 'supabase_bootstrap.sql')

const bootstrap = fs.readFileSync(bootstrapPath, 'utf8')

let sql = `${bootstrap}

-- =============================================================================
-- SEED: 30 CASOS CRÉDITO EMPRESARIAL — Flujo móvil (PDF enunciados)
-- =============================================================================

DO $$
DECLARE v_asesor UUID;
BEGIN
  v_asesor := public.ensure_demo_asesor_id();

  IF v_asesor IS NULL THEN
    RAISE EXCEPTION 'No se pudo obtener asesor OP001. Ejecute supabase_bootstrap.sql primero.';
  END IF;

`

for (const c of CASOS_CREDITO_30) {
  const prio = c.asignacion.prioridad === 'alta' ? 1 : c.asignacion.prioridad === 'media' ? 2 : 3
  const estado =
    c.comite.decision === 'RECHAZADO'
      ? 'rechazado'
      : c.comite.decision === 'CONDICIONADO'
        ? 'condicionado'
        : 'enviado'
  const id = `cli_${c.documento}`
  const esc = (s) => String(s).replace(/'/g, "''")
  const tea = c.solicitud.conSeguro ? 40.92 : 43.92
  const cuota = c.desembolso?.cuotaMensual ?? 0

  sql += `
  -- Caso ${c.id}: ${c.nombre}
  INSERT INTO public.clientes (id, asesor_id, documento, nombre, telefono, negocio_nombre, direccion, latitud, longitud, tipo_gestion, prioridad, monto_preaprobado, plazo_preaprobado, tasa_preaprobada)
  VALUES ('${id}', v_asesor, '${c.documento}', '${esc(c.nombre)}', '${c.telefono}', '${esc(c.negocio)}', '${esc(c.distrito)}', ${c.lat}, ${c.lng}, 'NUEVA SOLICITUD', ${prio}, ${c.solicitud.monto}, ${c.solicitud.plazo}, ${tea})
  ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, tipo_gestion = 'NUEVA SOLICITUD', prioridad = EXCLUDED.prioridad, latitud = EXCLUDED.latitud, longitud = EXCLUDED.longitud;

  INSERT INTO public.solicitudes (id, asesor_id, cliente_id, documento_cliente, datos_personales, datos_negocio, condiciones, estado, monto_aprobado, plazo_aprobado, cuota_mensual, expediente_numero, motivo_rechazo)
  VALUES (
    'sol_${c.documento}', v_asesor, '${id}', '${c.documento}',
    jsonb_build_object('nombre','${esc(c.nombre)}','documento','${c.documento}','telefono','${c.telefono}','ingreso',${c.ingreso},'gasto',${c.gasto}),
    jsonb_build_object('nombre','${esc(c.negocio)}','distrito','${esc(c.distrito)}','antiguedad_meses',${c.antiguedadMeses}),
    jsonb_build_object('monto',${c.solicitud.monto},'plazo',${c.solicitud.plazo},'destino','${esc(c.solicitud.destino)}','garantia','${esc(c.solicitud.garantia)}','tea',${tea},'con_seguro',${c.solicitud.conSeguro}),
    '${estado}', ${c.comite.montoAprobado || 0}, ${c.solicitud.plazo}, ${cuota},
    'EXP-${c.documento}', ${c.comite.motivoRechazo ? `'${esc(c.comite.motivoRechazo)}'` : 'NULL'}
  )
  ON CONFLICT (id) DO UPDATE SET estado = EXCLUDED.estado, monto_aprobado = EXCLUDED.monto_aprobado, cuota_mensual = EXCLUDED.cuota_mensual;
`
}

sql += `
  RAISE NOTICE 'Seed 30 casos aplicado para asesor %', v_asesor;
END $$;

SELECT codigo, nombre FROM public.perfiles_asesor WHERE UPPER(codigo) = 'OP001';
SELECT COUNT(*) AS clientes_cargados FROM public.clientes WHERE id LIKE 'cli_%';
`

fs.writeFileSync(outPath, sql)
console.log(`Escrito ${CASOS_CREDITO_30.length} casos + bootstrap en ${outPath}`)
