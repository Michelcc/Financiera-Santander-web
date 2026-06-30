import { useState, useEffect, useCallback } from 'react'
import { Bell, RefreshCw, CheckCircle2 } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import { useAuth } from '../context/AuthContext.jsx'
import { listarAlertas, marcarLeida, suscribirTabla } from '../services/alertasService.js'
import { extractError, formatDateTime } from '../utils/format.js'

export default function AlertasPage() {
  const { user } = useAuth()
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const cargar = useCallback(() => {
    setLoading(true)
    listarAlertas(user?.perfil ?? 'operador')
      .then((data) => setItems(data || []))
      .catch((err) => setError(extractError(err)))
      .finally(() => setLoading(false))
  }, [user?.perfil])

  useEffect(() => {
    cargar()
    const unsub = suscribirTabla('notificaciones_supervisor', cargar)
    return unsub
  }, [cargar])

  const noLeidas = items.filter((n) => !n.leida).length

  return (
    <>
      <PageHead
        title="Alertas en tiempo real"
        subtitle={
          noLeidas > 0
            ? `${noLeidas} alerta(s) sin leer — incluye solicitudes del App Cliente`
            : 'Sincronizado con App Cliente y App Fuerza de Ventas vía Supabase'
        }
        icon={Bell}
        actions={
          <button className="hb-btn hb-btn-gray hb-btn-sm" onClick={cargar}>
            <RefreshCw size={15} /> Actualizar
          </button>
        }
      />

      {error && <Alert tipo="error">{error}</Alert>}

      {loading ? (
        <Loader text="Cargando alertas…" />
      ) : items.length === 0 ? (
        <div className="hb-card hb-table-empty">
          Sin alertas. Cuando un cliente solicite crédito desde la app móvil,
          verá aquí la notificación para asesor y supervisor.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {items.map((n) => (
            <div
              key={n.id}
              className="hb-card"
              style={{
                borderLeft: n.leida ? '4px solid var(--hb-border)' : '4px solid #e2132b',
                opacity: n.leida ? 0.85 : 1,
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
                <div>
                  <strong>{n.titulo}</strong>
                  <div style={{ fontSize: 14, marginTop: 6 }}>{n.mensaje}</div>
                  <small style={{ color: 'var(--hb-muted)' }}>
                    {formatDateTime(n.created_at)} · {n.audiencia} · {n.tipo}
                  </small>
                </div>
                {!n.leida && (
                  <button
                    className="hb-btn hb-btn-sm hb-btn-gray"
                    onClick={async () => {
                      await marcarLeida(n.id)
                      cargar()
                    }}
                  >
                    <CheckCircle2 size={14} /> Leída
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}
