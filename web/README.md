# Santander Consumer Peru - Front Banking

Portal web en **React + Vite** para el ecosistema financiero integrado.

Este frontend se conecta a la misma base de datos PostgreSQL de Supabase que usan:

- **Final Financiera** - App Clientes
- **Final Financiera Admin** - App Fuerza de Ventas

## Despliegue en Vercel

El proyecto esta listo para desplegarse como SPA en Vercel.

Configuracion recomendada en Vercel:

- **Framework Preset:** Vite
- **Build Command:** `npm run build`
- **Output Directory:** `dist`
- **Install Command:** `npm install`

Variables de entorno requeridas:

- `VITE_BASE_URL`
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Si despliegas este repositorio, Vercel debe servir cualquier ruta del frontend con `index.html`. Para eso este proyecto incluye `vercel.json` con rewrite para React Router.

## Desarrollo local

```bash
npm install
copy .env.example .env
npm run dev
```

Abrir: `http://localhost:5173`

## Credenciales demo

| Campo | Valor |
|-------|-------|
| Codigo asesor | `OP001` |
| Contrasena | `santander2026` |

El login intenta primero el backend FastAPI (`POST /auth/login`) y, si no esta disponible, usa Supabase Auth.

## Estructura principal

```text
src/
  lib/supabase.js           Cliente Supabase
  services/                 Logica de acceso a datos
  pages/                    Pantallas del portal
  context/AuthContext.jsx   Sesion del usuario
```

## Build de produccion

```bash
npm run build
npm run preview
```

## Requisitos de Supabase

1. Ejecutar `supabase_completo.sql` en el SQL Editor
2. Crear o mantener el usuario asesor `op001@asesor.santander.pe`
3. Desactivar la confirmacion de correo si quieres flujo inmediato en pruebas

## Observacion

Este proyecto usa rutas con `BrowserRouter`, por eso el rewrite de Vercel es necesario para que funcionen rutas como `/inicio`, `/cartera` o `/casos/123` al refrescar la pagina.
