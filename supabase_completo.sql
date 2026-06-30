-- =============================================================================
-- SANTANDER CONSUMER PERÚ — BASE DE DATOS ÚNICA
-- Para App Cliente + App Fuerza de Ventas (ambas usan ESTE mismo proyecto)
--
-- CÓMO USAR (proyecto nuevo o con errores):
--   1. Supabase Dashboard → SQL Editor
--   2. Pegar TODO este archivo
--   3. Click RUN (una sola vez)
--   4. Authentication → Providers → Email habilitado
--   5. Authentication → Settings → desactivar "Confirm email" (pruebas)
--   6. Crear usuarios demo (sección al final) o usar los que crea el script
-- =============================================================================

-- ── LIMPIEZA DE POLÍTICAS (evita errores al re-ejecutar) ─────────────────────
DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'perfiles_cliente','perfiles_asesor','clientes','solicitudes',
        'visitas','acciones_cobranza','prospectos','sync_queue',
        'cartera_diaria','creditos','pagos_credito',
        'declaraciones_informales','notificaciones_cliente','consultas_buro',
        'solicitudes_notas_internas','solicitudes_documentos'
      )
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

DROP POLICY IF EXISTS "storage_upload" ON storage.objects;
DROP POLICY IF EXISTS "storage_select" ON storage.objects;
DROP POLICY IF EXISTS "storage_delete" ON storage.objects;

-- ── FUNCIONES HELPER ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc', NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.actualizar_score_final()
RETURNS TRIGGER AS $$
BEGIN
  NEW.score_final := COALESCE(NEW.score_transaccional, 0) + COALESCE(NEW.score_campo, 0);
  NEW.hipotesis_credito := NEW.score_final * 100;
  NEW.segmento := CASE
    WHEN NEW.score_final >= 700 THEN 'PREMIER'
    WHEN NEW.score_final > 400 THEN 'ESTANDAR'
    ELSE 'BASICO'
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.calcular_score_transaccional(p_cliente_id TEXT)
RETURNS INTEGER AS $$
DECLARE
  v_score INTEGER := 400;
  v_pago RECORD;
BEGIN
  FOR v_pago IN
    SELECT pc.estado, pc.dias_mora
    FROM public.pagos_credito pc
    JOIN public.creditos c ON c.id = pc.credito_id
    WHERE c.cliente_id = p_cliente_id AND pc.fecha_pago IS NOT NULL
  LOOP
    IF v_pago.estado = 'PAGADO' AND v_pago.dias_mora = 0 THEN
      v_score := v_score + 50;
    ELSIF v_pago.dias_mora BETWEEN 30 AND 60 THEN
      v_score := v_score - 100;
    ELSIF v_pago.dias_mora > 60 THEN
      v_score := v_score - 200;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM public.creditos WHERE cliente_id = p_cliente_id AND estado = 'PAGADO') THEN
    v_score := v_score + 100;
  END IF;
  RETURN GREATEST(0, LEAST(800, v_score));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.trigger_score_transaccional()
RETURNS TRIGGER AS $$
DECLARE v_cliente_id TEXT;
BEGIN
  SELECT cliente_id INTO v_cliente_id FROM public.creditos WHERE id = NEW.credito_id;
  IF v_cliente_id IS NOT NULL THEN
    UPDATE public.clientes
    SET score_transaccional = public.calcular_score_transaccional(v_cliente_id)
    WHERE id = v_cliente_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── TABLAS ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.perfiles_cliente (
    id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre        TEXT NOT NULL,
    documento     TEXT NOT NULL,
    telefono      TEXT,
    email         TEXT,
    numero_cuenta TEXT UNIQUE NOT NULL,
    asesor_id     UUID,
    fecha_nacimiento DATE,
    distrito      TEXT,
    tipo_negocio  TEXT,
    direccion_negocio TEXT,
    lat_negocio   DOUBLE PRECISION,
    lng_negocio   DOUBLE PRECISION,
    calificacion_sbs TEXT DEFAULT 'Normal',
    activo        BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at    TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.perfiles_asesor (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre      TEXT NOT NULL,
    codigo      TEXT UNIQUE,
    zona        TEXT,
    sucursal    TEXT,
    telefono    TEXT,
    foto_url    TEXT,
    activo      BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at  TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.clientes (
    id                   TEXT PRIMARY KEY,
    asesor_id            UUID NOT NULL REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE,
    documento            TEXT NOT NULL,
    nombre               TEXT NOT NULL,
    telefono             TEXT,
    negocio_nombre       TEXT,
    negocio_tipo         TEXT,
    direccion            TEXT,
    latitud              DOUBLE PRECISION,
    longitud             DOUBLE PRECISION,
    tipo_gestion         TEXT DEFAULT 'Renovacion',
    prioridad            INTEGER DEFAULT 3,
    score_transaccional  INTEGER DEFAULT 500,
    score_campo          INTEGER DEFAULT 0,
    score_final          INTEGER DEFAULT 500,
    hipotesis_credito    NUMERIC(12,2) DEFAULT 50000.00,
    segmento             TEXT DEFAULT 'ESTANDAR',
    cliente_user_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    asesor_asignado_id   UUID REFERENCES public.perfiles_asesor(id) ON DELETE SET NULL,
    deuda_total          NUMERIC(12,2) DEFAULT 0.00,
    mora_dias            INTEGER DEFAULT 0,
    ultimo_pago_fecha    TEXT,
    proxima_cuota_monto  NUMERIC(12,2) DEFAULT 0,
    proxima_cuota_fecha  DATE,
    estado_credito       TEXT DEFAULT 'AL_DIA',
    monto_preaprobado    NUMERIC(12,2) DEFAULT 0.00,
    plazo_preaprobado    INTEGER DEFAULT 6,
    tasa_preaprobada     NUMERIC(5,2) DEFAULT 18.00,
    historial_pagos      JSONB DEFAULT '[]'::jsonb,
    created_at           TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at           TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE (asesor_id, documento)
);

CREATE TABLE IF NOT EXISTS public.solicitudes (
    id               TEXT PRIMARY KEY,
    asesor_id        UUID NOT NULL REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE,
    cliente_id       TEXT REFERENCES public.clientes(id) ON DELETE SET NULL,
    cliente_user_id  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    documento_cliente TEXT,
    datos_personales JSONB,
    datos_negocio    JSONB,
    condiciones      JSONB,
    firma_path       TEXT,
    nitidez_ok       BOOLEAN DEFAULT TRUE,
    fotos_paths      JSONB DEFAULT '[]'::jsonb,
    score_campo      INTEGER DEFAULT 0,
    score_final      INTEGER DEFAULT 0,
    segmento         TEXT DEFAULT 'BASICO',
    monto_aprobado   NUMERIC(12,2) DEFAULT 0.00,
    plazo_aprobado   INTEGER DEFAULT 6,
    cuota_mensual    NUMERIC(12,2) DEFAULT 0.00,
    estado           TEXT DEFAULT 'Borrador',
    motivo_rechazo   TEXT,
    expediente_numero TEXT,
    timeline         JSONB DEFAULT '[]'::jsonb,
    notas_asesor     TEXT,
    created_at       TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at       TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.visitas (
    id           TEXT PRIMARY KEY,
    asesor_id    UUID NOT NULL REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE,
    cliente_id   TEXT REFERENCES public.clientes(id) ON DELETE CASCADE,
    resultado    TEXT NOT NULL,
    observacion  TEXT,
    latitud      DOUBLE PRECISION,
    longitud     DOUBLE PRECISION,
    created_at   TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.acciones_cobranza (
    id                TEXT PRIMARY KEY,
    asesor_id         UUID NOT NULL REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE,
    cliente_id        TEXT REFERENCES public.clientes(id) ON DELETE CASCADE,
    tipo              TEXT NOT NULL,
    observacion       TEXT,
    compromiso_fecha  TIMESTAMPTZ,
    compromiso_monto  NUMERIC(12,2) DEFAULT 0.00,
    latitud           DOUBLE PRECISION,
    longitud          DOUBLE PRECISION,
    created_at        TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.prospectos (
    id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    asesor_id        UUID NOT NULL REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE,
    documento        TEXT NOT NULL,
    nombre           TEXT NOT NULL,
    telefono         TEXT,
    negocio_nombre   TEXT,
    ingresos         NUMERIC(12,2) DEFAULT 0.00,
    pre_evaluacion   TEXT,
    motivo_desercion TEXT,
    latitud          DOUBLE PRECISION,
    longitud         DOUBLE PRECISION,
    created_at       TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE (asesor_id, documento)
);

CREATE TABLE IF NOT EXISTS public.sync_queue (
    id          BIGSERIAL PRIMARY KEY,
    asesor_id   UUID NOT NULL REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE,
    tabla       TEXT NOT NULL,
    operacion   TEXT NOT NULL,
    payload     JSONB NOT NULL,
    intentos    INTEGER DEFAULT 0,
    procesado   BOOLEAN DEFAULT FALSE,
    error_msg   TEXT,
    created_at  TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.cartera_diaria (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    asesor_id UUID NOT NULL REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE,
    cliente_id TEXT NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
    fecha_asignacion DATE NOT NULL DEFAULT CURRENT_DATE,
    tipo_gestion TEXT NOT NULL DEFAULT 'NUEVA SOLICITUD',
    prioridad INTEGER DEFAULT 50,
    score_prioridad INTEGER DEFAULT 50,
    visitado BOOLEAN DEFAULT FALSE,
    estado_visita TEXT,
    resultado_visita TEXT,
    observacion_visita TEXT,
    timestamp_visita TIMESTAMPTZ,
    lat_visita DOUBLE PRECISION,
    lng_visita DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE (asesor_id, cliente_id, fecha_asignacion)
);

CREATE TABLE IF NOT EXISTS public.creditos (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    cliente_id TEXT NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
    cliente_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    monto NUMERIC(12,2) NOT NULL,
    plazo_meses INTEGER NOT NULL DEFAULT 12,
    tea NUMERIC(5,2) DEFAULT 60.00,
    cuota_mensual NUMERIC(12,2) DEFAULT 0,
    saldo_pendiente NUMERIC(12,2) DEFAULT 0,
    estado TEXT DEFAULT 'VIGENTE',
    fecha_desembolso DATE,
    fecha_vencimiento DATE,
    dias_mora INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.pagos_credito (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    credito_id TEXT NOT NULL REFERENCES public.creditos(id) ON DELETE CASCADE,
    numero_cuota INTEGER NOT NULL,
    monto NUMERIC(12,2) NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    fecha_pago DATE,
    dias_mora INTEGER DEFAULT 0,
    estado TEXT DEFAULT 'PENDIENTE',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.declaraciones_informales (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    cliente_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    documento TEXT NOT NULL,
    tiene_deuda BOOLEAN NOT NULL DEFAULT FALSE,
    monto_aproximado NUMERIC(12,2) DEFAULT 0,
    entidad TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.notificaciones_cliente (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    cliente_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    titulo TEXT NOT NULL,
    mensaje TEXT NOT NULL,
    leida BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.consultas_buro (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    asesor_id UUID NOT NULL REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE,
    documento TEXT NOT NULL,
    calificacion_sbs TEXT,
    entidades_con_deuda INTEGER DEFAULT 0,
    deuda_total_pen NUMERIC(12,2) DEFAULT 0,
    mayor_deuda NUMERIC(12,2) DEFAULT 0,
    dias_mayor_mora INTEGER DEFAULT 0,
    consentimiento_firmado BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.solicitudes_notas_internas (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    solicitud_id TEXT NOT NULL REFERENCES public.solicitudes(id) ON DELETE CASCADE,
    asesor_id UUID NOT NULL REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE,
    nota TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.solicitudes_documentos (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    solicitud_id TEXT NOT NULL REFERENCES public.solicitudes(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    nitidez_ok BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- ── MIGRACIÓN: agregar columnas si la tabla ya existía (schema viejo) ─────────
ALTER TABLE public.perfiles_cliente
  ADD COLUMN IF NOT EXISTS asesor_id UUID,
  ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE,
  ADD COLUMN IF NOT EXISTS distrito TEXT,
  ADD COLUMN IF NOT EXISTS tipo_negocio TEXT,
  ADD COLUMN IF NOT EXISTS direccion_negocio TEXT,
  ADD COLUMN IF NOT EXISTS lat_negocio DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS lng_negocio DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS calificacion_sbs TEXT DEFAULT 'Normal';

ALTER TABLE public.clientes
  ADD COLUMN IF NOT EXISTS score_campo INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS score_final INTEGER DEFAULT 500,
  ADD COLUMN IF NOT EXISTS hipotesis_credito NUMERIC(12,2) DEFAULT 50000.00,
  ADD COLUMN IF NOT EXISTS segmento TEXT DEFAULT 'ESTANDAR',
  ADD COLUMN IF NOT EXISTS cliente_user_id UUID,
  ADD COLUMN IF NOT EXISTS asesor_asignado_id UUID,
  ADD COLUMN IF NOT EXISTS proxima_cuota_monto NUMERIC(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS proxima_cuota_fecha DATE,
  ADD COLUMN IF NOT EXISTS estado_credito TEXT DEFAULT 'AL_DIA';

ALTER TABLE public.solicitudes
  ADD COLUMN IF NOT EXISTS cliente_user_id UUID,
  ADD COLUMN IF NOT EXISTS documento_cliente TEXT,
  ADD COLUMN IF NOT EXISTS motivo_rechazo TEXT,
  ADD COLUMN IF NOT EXISTS expediente_numero TEXT,
  ADD COLUMN IF NOT EXISTS timeline JSONB DEFAULT '[]'::jsonb;

-- Recalcular scores en todas las filas existentes
UPDATE public.clientes
SET
  score_final = COALESCE(score_transaccional, 0) + COALESCE(score_campo, 0),
  hipotesis_credito = (COALESCE(score_transaccional, 0) + COALESCE(score_campo, 0)) * 100,
  segmento = CASE
    WHEN (COALESCE(score_transaccional, 0) + COALESCE(score_campo, 0)) >= 700 THEN 'PREMIER'
    WHEN (COALESCE(score_transaccional, 0) + COALESCE(score_campo, 0)) > 400 THEN 'ESTANDAR'
    ELSE 'BASICO'
  END;

ALTER TABLE public.perfiles_cliente
  DROP CONSTRAINT IF EXISTS perfiles_cliente_asesor_id_fkey;
ALTER TABLE public.perfiles_cliente
  ADD CONSTRAINT perfiles_cliente_asesor_id_fkey
  FOREIGN KEY (asesor_id) REFERENCES public.perfiles_asesor(id) ON DELETE SET NULL;

-- ── TRIGGERS ───────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_perfiles_cliente_updated_at ON public.perfiles_cliente;
CREATE TRIGGER trg_perfiles_cliente_updated_at
  BEFORE UPDATE ON public.perfiles_cliente
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_perfiles_asesor_updated_at ON public.perfiles_asesor;
CREATE TRIGGER trg_perfiles_asesor_updated_at
  BEFORE UPDATE ON public.perfiles_asesor
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_clientes_updated_at ON public.clientes;
CREATE TRIGGER trg_clientes_updated_at
  BEFORE UPDATE ON public.clientes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_solicitudes_updated_at ON public.solicitudes;
CREATE TRIGGER trg_solicitudes_updated_at
  BEFORE UPDATE ON public.solicitudes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_clientes_score_final ON public.clientes;
CREATE TRIGGER trg_clientes_score_final
  BEFORE INSERT OR UPDATE OF score_transaccional, score_campo ON public.clientes
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_score_final();

DROP TRIGGER IF EXISTS trg_pagos_score ON public.pagos_credito;
CREATE TRIGGER trg_pagos_score
  AFTER INSERT OR UPDATE ON public.pagos_credito
  FOR EACH ROW EXECUTE FUNCTION public.trigger_score_transaccional();

-- Trigger: crear perfil al registrarse
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
  v_nombre TEXT;
  v_numero_cuenta TEXT;
  v_codigo TEXT;
BEGIN
  v_role   := LOWER(COALESCE(NEW.raw_user_meta_data->>'role', 'asesor'));
  v_nombre := COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email, '@', 1));
  v_codigo := COALESCE(
    NEW.raw_user_meta_data->>'codigo',
    split_part(NEW.email, '@', 1)
  );

  IF v_role = 'cliente' THEN
    v_numero_cuenta := 'SCF-' || LPAD(FLOOR(RANDOM() * 100000000)::TEXT, 8, '0');
    INSERT INTO public.perfiles_cliente (id, nombre, documento, telefono, email, numero_cuenta)
    VALUES (
      NEW.id,
      v_nombre,
      COALESCE(NEW.raw_user_meta_data->>'documento', split_part(NEW.email, '@', 1)),
      COALESCE(NEW.raw_user_meta_data->>'telefono', ''),
      NEW.email,
      v_numero_cuenta
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    INSERT INTO public.perfiles_asesor (id, nombre, codigo, sucursal)
    VALUES (
      NEW.id,
      v_nombre,
      v_codigo,
      COALESCE(NEW.raw_user_meta_data->>'sucursal', 'Agencia Principal')
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── REPARAR FK clientes → perfiles_asesor (schema viejo usaba tabla asesores) ─
INSERT INTO public.perfiles_asesor (id, nombre, codigo, sucursal)
SELECT u.id,
  COALESCE(u.raw_user_meta_data->>'nombre', 'Asesor'),
  UPPER(COALESCE(u.raw_user_meta_data->>'codigo', split_part(u.email, '@', 1))),
  COALESCE(u.raw_user_meta_data->>'sucursal', 'Agencia Principal')
FROM auth.users u
WHERE u.email LIKE '%@asesor.santander.pe'
  AND NOT EXISTS (SELECT 1 FROM public.perfiles_asesor p WHERE p.id = u.id)
ON CONFLICT (id) DO UPDATE SET
  nombre = EXCLUDED.nombre,
  codigo = EXCLUDED.codigo,
  sucursal = EXCLUDED.sucursal;

UPDATE public.clientes c
SET asesor_id = sub.id
FROM (
  SELECT COALESCE(
    (SELECT pa.id FROM public.perfiles_asesor pa WHERE UPPER(pa.codigo) = 'OP001' LIMIT 1),
    (SELECT u.id FROM auth.users u WHERE u.email = 'op001@asesor.santander.pe' LIMIT 1),
    (SELECT pa.id FROM public.perfiles_asesor pa ORDER BY pa.created_at LIMIT 1)
  ) AS id
) sub
WHERE c.asesor_id IS NULL
   OR NOT EXISTS (SELECT 1 FROM public.perfiles_asesor pa WHERE pa.id = c.asesor_id);

ALTER TABLE public.clientes DROP CONSTRAINT IF EXISTS clientes_asesor_id_fkey;
ALTER TABLE public.clientes
  ADD CONSTRAINT clientes_asesor_id_fkey
  FOREIGN KEY (asesor_id) REFERENCES public.perfiles_asesor(id) ON DELETE CASCADE;

UPDATE public.perfiles_cliente pc
SET asesor_id = NULL
WHERE asesor_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.perfiles_asesor pa WHERE pa.id = pc.asesor_id);

-- ── ÍNDICES ÚNICOS para sync cartera (tablas creadas antes sin UNIQUE) ───────
DELETE FROM public.clientes a
USING public.clientes b
WHERE a.asesor_id = b.asesor_id
  AND a.documento = b.documento
  AND a.ctid > b.ctid;

CREATE UNIQUE INDEX IF NOT EXISTS uq_clientes_asesor_documento
  ON public.clientes (asesor_id, documento);

DELETE FROM public.prospectos a
USING public.prospectos b
WHERE a.asesor_id = b.asesor_id
  AND a.documento = b.documento
  AND a.ctid > b.ctid;

CREATE UNIQUE INDEX IF NOT EXISTS uq_prospectos_asesor_documento
  ON public.prospectos (asesor_id, documento);

CREATE UNIQUE INDEX IF NOT EXISTS uq_cartera_diaria_asesor_cliente_fecha
  ON public.cartera_diaria (asesor_id, cliente_id, fecha_asignacion);

-- ── SINCRONIZAR PERFILES Y PROSPECTOS → CARTERA (clientes + cartera_diaria) ──
CREATE OR REPLACE FUNCTION public.get_default_asesor_id()
RETURNS UUID AS $$
  SELECT COALESCE(
    (SELECT pa.id FROM public.perfiles_asesor pa WHERE UPPER(pa.codigo) = 'OP001' LIMIT 1),
    (SELECT u.id FROM auth.users u WHERE u.email = 'op001@asesor.santander.pe' LIMIT 1),
    (SELECT pa.id FROM public.perfiles_asesor pa ORDER BY pa.created_at LIMIT 1)
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION public.sync_perfil_cliente_cartera(p_documento TEXT)
RETURNS VOID AS $$
DECLARE
  v_perfil public.perfiles_cliente%ROWTYPE;
  v_asesor_id UUID;
  v_cliente_id TEXT;
BEGIN
  SELECT * INTO v_perfil
  FROM public.perfiles_cliente
  WHERE documento = p_documento
  LIMIT 1;

  IF NOT FOUND THEN RETURN; END IF;

  v_asesor_id := COALESCE(v_perfil.asesor_id, public.get_default_asesor_id());

  IF v_asesor_id IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.perfiles_asesor WHERE id = v_asesor_id) THEN
    INSERT INTO public.perfiles_asesor (id, nombre, codigo, sucursal)
    SELECT u.id,
      COALESCE(u.raw_user_meta_data->>'nombre', 'Asesor OP001'),
      UPPER(COALESCE(u.raw_user_meta_data->>'codigo', 'OP001')),
      COALESCE(u.raw_user_meta_data->>'sucursal', 'Agencia Principal')
    FROM auth.users u
    WHERE u.email = 'op001@asesor.santander.pe'
    ON CONFLICT (id) DO NOTHING;

    v_asesor_id := public.get_default_asesor_id();
  END IF;

  IF v_asesor_id IS NULL THEN RETURN; END IF;

  v_cliente_id := 'cli_' || v_perfil.documento;

  UPDATE public.clientes SET
    asesor_id = v_asesor_id,
    documento = v_perfil.documento,
    nombre = v_perfil.nombre,
    telefono = v_perfil.telefono,
    negocio_nombre = COALESCE(v_perfil.tipo_negocio, negocio_nombre, 'Registro app cliente'),
    negocio_tipo = COALESCE(negocio_tipo, 'Comercio'),
    tipo_gestion = 'Nueva Solicitud',
    cliente_user_id = COALESCE(v_perfil.id, cliente_user_id)
  WHERE id = v_cliente_id;

  IF NOT FOUND THEN
    INSERT INTO public.clientes (
      id, asesor_id, documento, nombre, telefono,
      negocio_nombre, negocio_tipo, tipo_gestion, prioridad,
      score_transaccional, score_campo, score_final, cliente_user_id
    ) VALUES (
      v_cliente_id, v_asesor_id, v_perfil.documento, v_perfil.nombre, v_perfil.telefono,
      COALESCE(v_perfil.tipo_negocio, 'Registro app cliente'), 'Comercio', 'Nueva Solicitud', 3,
      500, 0, 500, v_perfil.id
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.cartera_diaria
    WHERE asesor_id = v_asesor_id
      AND cliente_id = v_cliente_id
      AND fecha_asignacion = CURRENT_DATE
  ) THEN
    INSERT INTO public.cartera_diaria (asesor_id, cliente_id, fecha_asignacion, tipo_gestion, prioridad, score_prioridad)
    VALUES (v_asesor_id, v_cliente_id, CURRENT_DATE, 'Nueva Solicitud', 3, 50);
  END IF;

  IF v_perfil.asesor_id IS NULL OR v_perfil.asesor_id IS DISTINCT FROM v_asesor_id THEN
    UPDATE public.perfiles_cliente SET asesor_id = v_asesor_id WHERE id = v_perfil.id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.trg_sync_perfil_cartera()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM public.sync_perfil_cliente_cartera(NEW.documento);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.trg_sync_prospecto_cartera()
RETURNS TRIGGER AS $$
DECLARE
  v_cliente_id TEXT;
BEGIN
  v_cliente_id := 'cli_' || NEW.documento;

  UPDATE public.clientes SET
    asesor_id = NEW.asesor_id,
    documento = NEW.documento,
    nombre = NEW.nombre,
    telefono = NEW.telefono,
    negocio_nombre = COALESCE(NEW.negocio_nombre, negocio_nombre, 'Por definir'),
    latitud = NEW.latitud,
    longitud = NEW.longitud,
    tipo_gestion = 'Nueva Solicitud'
  WHERE id = v_cliente_id;

  IF NOT FOUND THEN
    INSERT INTO public.clientes (
      id, asesor_id, documento, nombre, telefono,
      negocio_nombre, negocio_tipo, direccion, latitud, longitud,
      tipo_gestion, prioridad, score_transaccional, score_campo, score_final
    ) VALUES (
      v_cliente_id, NEW.asesor_id, NEW.documento, NEW.nombre, NEW.telefono,
      COALESCE(NEW.negocio_nombre, 'Por definir'), 'Comercio', '', NEW.latitud, NEW.longitud,
      'Nueva Solicitud', 3, 500, 0, 500
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.cartera_diaria
    WHERE asesor_id = NEW.asesor_id
      AND cliente_id = v_cliente_id
      AND fecha_asignacion = CURRENT_DATE
  ) THEN
    INSERT INTO public.cartera_diaria (asesor_id, cliente_id, fecha_asignacion, tipo_gestion, prioridad, score_prioridad)
    VALUES (NEW.asesor_id, v_cliente_id, CURRENT_DATE, 'Nueva Solicitud', 3, 50);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_perfil_a_cartera ON public.perfiles_cliente;
CREATE TRIGGER trg_perfil_a_cartera
  AFTER INSERT OR UPDATE ON public.perfiles_cliente
  FOR EACH ROW EXECUTE FUNCTION public.trg_sync_perfil_cartera();

DROP TRIGGER IF EXISTS trg_prospecto_a_cartera ON public.prospectos;
CREATE TRIGGER trg_prospecto_a_cartera
  AFTER INSERT OR UPDATE ON public.prospectos
  FOR EACH ROW EXECUTE FUNCTION public.trg_sync_prospecto_cartera();

GRANT EXECUTE ON FUNCTION public.sync_perfil_cliente_cartera(TEXT) TO authenticated;

-- Reparar registros existentes (perfiles + prospectos → cartera)
DO $$
DECLARE v_doc TEXT;
BEGIN
  FOR v_doc IN SELECT documento FROM public.perfiles_cliente LOOP
    PERFORM public.sync_perfil_cliente_cartera(v_doc);
  END LOOP;
END $$;

-- ── STORAGE ──────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('expedientes','expedientes',false,10485760,
  ARRAY['image/jpeg','image/png','image/webp','application/pdf'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "storage_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'expedientes' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "storage_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'expedientes' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "storage_delete" ON storage.objects FOR DELETE
  USING (bucket_id = 'expedientes' AND (storage.foldername(name))[1] = auth.uid()::text);

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.perfiles_cliente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_asesor ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acciones_cobranza ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prospectos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cartera_diaria ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creditos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos_credito ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.declaraciones_informales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones_cliente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultas_buro ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_notas_internas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_documentos ENABLE ROW LEVEL SECURITY;

-- Perfiles
CREATE POLICY "pc_select_own" ON public.perfiles_cliente FOR SELECT USING (auth.uid() = id);
CREATE POLICY "pc_update_own" ON public.perfiles_cliente FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "pc_insert_own" ON public.perfiles_cliente FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "pa_select_own" ON public.perfiles_asesor FOR SELECT
  USING (auth.uid() = id OR id IN (SELECT asesor_id FROM public.perfiles_cliente WHERE id = auth.uid()));
CREATE POLICY "pa_update_own" ON public.perfiles_asesor FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "pa_insert_own" ON public.perfiles_asesor FOR INSERT WITH CHECK (auth.uid() = id);

-- Clientes: asesor todo, cliente solo lectura
CREATE POLICY "cli_asesor_all" ON public.clientes FOR ALL
  USING (asesor_id = auth.uid()) WITH CHECK (asesor_id = auth.uid());
CREATE POLICY "cli_cliente_read" ON public.clientes FOR SELECT
  USING (
    cliente_user_id = auth.uid()
    OR documento IN (SELECT documento FROM public.perfiles_cliente WHERE id = auth.uid())
  );

-- Solicitudes
CREATE POLICY "sol_asesor_all" ON public.solicitudes FOR ALL
  USING (asesor_id = auth.uid()) WITH CHECK (asesor_id = auth.uid());
CREATE POLICY "sol_cliente_read" ON public.solicitudes FOR SELECT
  USING (
    cliente_user_id = auth.uid()
    OR documento_cliente IN (SELECT documento FROM public.perfiles_cliente WHERE id = auth.uid())
  );

-- Asesor: visitas, cobranza, prospectos, sync, cartera, buró
CREATE POLICY "vis_asesor" ON public.visitas FOR ALL
  USING (asesor_id = auth.uid()) WITH CHECK (asesor_id = auth.uid());
CREATE POLICY "cob_asesor" ON public.acciones_cobranza FOR ALL
  USING (asesor_id = auth.uid()) WITH CHECK (asesor_id = auth.uid());
CREATE POLICY "pro_asesor" ON public.prospectos FOR ALL
  USING (asesor_id = auth.uid()) WITH CHECK (asesor_id = auth.uid());
CREATE POLICY "sync_asesor" ON public.sync_queue FOR ALL
  USING (asesor_id = auth.uid()) WITH CHECK (asesor_id = auth.uid());
CREATE POLICY "cart_asesor" ON public.cartera_diaria FOR ALL
  USING (asesor_id = auth.uid()) WITH CHECK (asesor_id = auth.uid());
CREATE POLICY "buro_asesor" ON public.consultas_buro FOR ALL
  USING (asesor_id = auth.uid()) WITH CHECK (asesor_id = auth.uid());
CREATE POLICY "notas_asesor" ON public.solicitudes_notas_internas FOR ALL
  USING (asesor_id = auth.uid()) WITH CHECK (asesor_id = auth.uid());
CREATE POLICY "docs_asesor" ON public.solicitudes_documentos FOR ALL
  USING (solicitud_id IN (SELECT id FROM public.solicitudes WHERE asesor_id = auth.uid()));

-- Cliente: créditos, pagos, declaraciones, notificaciones
CREATE POLICY "cred_cliente" ON public.creditos FOR SELECT
  USING (
    cliente_user_id = auth.uid()
    OR cliente_id IN (
      SELECT c.id FROM public.clientes c
      JOIN public.perfiles_cliente p ON p.documento = c.documento
      WHERE p.id = auth.uid()
    )
  );
CREATE POLICY "cred_asesor" ON public.creditos FOR SELECT
  USING (cliente_id IN (SELECT id FROM public.clientes WHERE asesor_id = auth.uid()));

CREATE POLICY "pag_cliente" ON public.pagos_credito FOR SELECT
  USING (credito_id IN (
    SELECT id FROM public.creditos WHERE cliente_user_id = auth.uid()
    UNION
    SELECT cr.id FROM public.creditos cr
    JOIN public.clientes c ON c.id = cr.cliente_id
    JOIN public.perfiles_cliente p ON p.documento = c.documento
    WHERE p.id = auth.uid()
  ));

CREATE POLICY "decl_cliente" ON public.declaraciones_informales FOR ALL
  USING (cliente_user_id = auth.uid()) WITH CHECK (cliente_user_id = auth.uid());
CREATE POLICY "decl_asesor_read" ON public.declaraciones_informales FOR SELECT USING (true);

CREATE POLICY "notif_cliente" ON public.notificaciones_cliente FOR ALL
  USING (cliente_user_id = auth.uid()) WITH CHECK (cliente_user_id = auth.uid());

-- ── ÍNDICES ────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_clientes_asesor ON public.clientes(asesor_id);
CREATE INDEX IF NOT EXISTS idx_clientes_doc ON public.clientes(documento);
CREATE INDEX IF NOT EXISTS idx_perfil_cliente_doc ON public.perfiles_cliente(documento);
CREATE INDEX IF NOT EXISTS idx_solicitudes_asesor ON public.solicitudes(asesor_id);

-- ── REALTIME (ignora si ya existe) ─────────────────────────────────────────────
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.clientes;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.declaraciones_informales;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.solicitudes;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones_cliente;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =============================================================================
-- REPARAR PERFILES DE USUARIOS YA CREADOS EN AUTH (sin perfil en tablas)
-- Esto corrige el error más común al iniciar sesión
-- =============================================================================
INSERT INTO public.perfiles_asesor (id, nombre, codigo, sucursal)
SELECT u.id,
  COALESCE(u.raw_user_meta_data->>'nombre', 'Asesor Demo'),
  COALESCE(u.raw_user_meta_data->>'codigo', split_part(u.email, '@', 1)),
  COALESCE(u.raw_user_meta_data->>'sucursal', 'Agencia Miraflores')
FROM auth.users u
WHERE u.email LIKE '%@asesor.santander.pe'
  AND NOT EXISTS (SELECT 1 FROM public.perfiles_asesor p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.perfiles_cliente (id, nombre, documento, telefono, email, numero_cuenta)
SELECT u.id,
  COALESCE(u.raw_user_meta_data->>'nombre', 'Cliente'),
  COALESCE(u.raw_user_meta_data->>'documento', split_part(u.email, '@', 1)),
  COALESCE(u.raw_user_meta_data->>'telefono', ''),
  u.email,
  'SCF-' || LPAD(FLOOR(RANDOM() * 100000000)::TEXT, 8, '0')
FROM auth.users u
WHERE u.email LIKE '%@cliente.santander.pe'
  AND NOT EXISTS (SELECT 1 FROM public.perfiles_cliente p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- DATOS DEMO (solo si existe al menos un asesor)
-- =============================================================================
DO $$
DECLARE v_asesor_id UUID;
        v_cliente_uid UUID;
BEGIN
  SELECT id INTO v_asesor_id FROM public.perfiles_asesor ORDER BY created_at LIMIT 1;
  SELECT id INTO v_cliente_uid FROM auth.users WHERE email = '45781290@cliente.santander.pe' LIMIT 1;

  IF v_asesor_id IS NULL THEN
    RAISE NOTICE 'No hay asesor. Crea usuario: op001@asesor.santander.pe / santander2026';
    RETURN;
  END IF;

  INSERT INTO public.clientes (
    id, asesor_id, documento, nombre, telefono, negocio_nombre, negocio_tipo,
    direccion, latitud, longitud, tipo_gestion, prioridad,
    score_transaccional, score_campo, deuda_total, mora_dias,
    monto_preaprobado, proxima_cuota_monto, proxima_cuota_fecha, estado_credito,
    cliente_user_id, historial_pagos
  ) VALUES
  ('cli_demo_001', v_asesor_id, '45781290', 'Juan Perez Garcia', '987654321',
   'Bodega Don Juan', 'Comercio', 'Av. Larco 452, Miraflores', -12.1221, -77.0298,
   'Renovacion', 2, 700, 50, 15000, 0, 75000, 450, '2026-06-15', 'AL_DIA',
   v_cliente_uid, '[350,350,350,350,350,350,350,350,350,350,0,0]'::jsonb),
  ('cli_demo_002', v_asesor_id, '10473922', 'Maria Lopez Ruiz', '945612307',
   'Textiles Maria', 'Produccion', 'Jr. Gamarra 820', -12.0628, -77.0151,
   'Mora', 1, 550, 30, 8500, 15, 58000, 380, '2026-06-10', 'MORA_LEVE',
   NULL, '[400,400,400,400,400,400,400,400,400,400,400,400]'::jsonb),
  ('cli_demo_003', v_asesor_id, '73920199', 'Carlos Quispe', '912345678',
   'Frutas Carlos', 'Comercio', 'Mercado Surco', -12.1472, -77.0211,
   'Mora', 1, 350, 0, 22000, 45, 35000, 620, '2026-05-28', 'MORA',
   NULL, '[500,500,500,500,0,0,0,0,0,0,0,0]'::jsonb)
  ON CONFLICT (id) DO UPDATE SET
    score_transaccional = EXCLUDED.score_transaccional,
    score_campo = EXCLUDED.score_campo,
    cliente_user_id = COALESCE(EXCLUDED.cliente_user_id, public.clientes.cliente_user_id);

  -- Vincular asesor al cliente demo
  IF v_cliente_uid IS NOT NULL THEN
    UPDATE public.perfiles_cliente
    SET asesor_id = v_asesor_id
    WHERE id = v_cliente_uid;
  END IF;

  INSERT INTO public.creditos (id, cliente_id, cliente_user_id, monto, plazo_meses, tea, cuota_mensual, saldo_pendiente, estado, fecha_desembolso)
  VALUES ('cred_demo_001', 'cli_demo_001', v_cliente_uid, 15000, 24, 60, 450, 12000, 'VIGENTE', '2025-06-01')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.pagos_credito (id, credito_id, numero_cuota, monto, fecha_vencimiento, fecha_pago, dias_mora, estado)
  SELECT 'pago_' || n, 'cred_demo_001', n, 450,
    ('2025-06-01'::date + (n || ' months')::interval)::date,
    CASE WHEN n <= 10 THEN ('2025-06-01'::date + (n || ' months')::interval)::date END,
    CASE WHEN n = 9 THEN 5 ELSE 0 END,
    CASE WHEN n <= 10 THEN 'PAGADO' ELSE 'PENDIENTE' END
  FROM generate_series(1, 12) AS n
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.cartera_diaria (asesor_id, cliente_id, fecha_asignacion, tipo_gestion, prioridad, score_prioridad)
  SELECT v_asesor_id, c.id, CURRENT_DATE, c.tipo_gestion, 50, 50
  FROM public.clientes c WHERE c.asesor_id = v_asesor_id
  ON CONFLICT (asesor_id, cliente_id, fecha_asignacion) DO NOTHING;

END $$;

-- =============================================================================
-- USUARIOS DEMO — Crear manualmente en Authentication → Users → Add user
-- (El script de arriba repara perfiles si ya los creaste)
--
-- ASESOR (Fuerza de Ventas):
--   Email:    op001@asesor.santander.pe
--   Password: santander2026
--   Metadata: {"role":"Operador","nombre":"Carlos Mendoza","codigo":"OP001","sucursal":"Agencia Miraflores"}
--
-- CLIENTE (App Cliente):
--   Email:    45781290@cliente.santander.pe
--   Password: santander2026
--   Metadata: {"role":"cliente","nombre":"Juan Perez Garcia","documento":"45781290","telefono":"987654321"}
--
-- Luego vuelve a ejecutar SOLO la sección "REPARAR PERFILES" si hace falta,
-- o ejecuta de nuevo este script completo (es seguro re-ejecutarlo).
--
-- Sincronización automática activa:
--   • Registro app Cliente (perfiles_cliente) → clientes + cartera_diaria
--   • Prospecto app Admin (prospectos) → clientes + cartera_diaria
-- Si falla sync_perfil_cliente_cartera, ejecute primero: supabase_sync_cartera.sql

-- DESARROLLO: evita error 429 "email rate limit exceeded"
--   1. Authentication → Providers → Email → desactivar "Confirm email"
--   2. Al crear usuarios demo, marcar "Auto Confirm User"
--   3. Si ya bloqueó: esperar 30-60 min sin reintentar login/registro
-- =============================================================================
