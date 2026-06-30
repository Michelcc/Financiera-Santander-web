import { useState, useEffect } from 'react'
import {
  Database, Server, Smartphone, Globe, RefreshCw,
  CheckCircle2, XCircle, ArrowRightLeft,
} from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import { checkEcosystemHealth } from '../services/ecosystemService.js'
import { useAuth } from '../context/AuthContext.jsx'

const FLUJO = [
  'Asesor registra solicitud (App FVentas / Web)',
  '→ Cola sync_queue / Supabase',
  '→ Core Mobile evalúa y aprueba',
  '→ Crédito reflejado en tablas espejo',
  '→ Cliente lo ve en App Clientes (cronograma, saldo)',
]

export default function EcosistemaPage() {
  const { user } = useAuth()
  const [health, setHealth] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const cargar = () => {
    setLoading(true)
    setError(null)
    checkEcosystemHealth()
      .then(setHealth)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }

  useEffect(() => { cargar() }, [])

  return (
    <>
      <PageHead
        title="Ecosistema integrado"
        subtitle="Front Banking · App FVentas · App Clientes · Core Mobile · BD única (PostgreSQL/Supabase)"
        action={
          <button className="hb-btn hb-btn-ghost" onClick={cargar}>
            <RefreshCw size={16} /> Verificar conexiones
          </button>
        }
      />

      {error && <Alert tipo="error">{error}</Alert>}

      {loading ? (
        <Loader text="Verificando ecosistema…" />
      ) : health && (
        <>
          <div className="cm-kpis">
            <div className="cm-kpi">
              <span className="cm-kpi-ico" style={{ background: '#fde8eb', color: '#EC0000' }}>
                <Database size={24} />
              </span>
              <div>
                <div className="cm-kpi-label">Supabase / PostgreSQL</div>
                <span className="cm-kpi-val" style={{ fontSize: 18 }}>
                  {health.supabase.ok ? 'Conectado' : 'Offline'}
                </span>
                <small>BD única compartida</small>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#444' }}>
              <span className="cm-kpi-ico" style={{ background: '#f3f4f6', color: '#374151' }}>
                <Server size={24} />
              </span>
              <div>
                <div className="cm-kpi-label">FastAPI Core Mobile</div>
                <span className="cm-kpi-val" style={{ fontSize: 18 }}>
                  {health.fastapi.ok ? 'Activo' : 'Opcional'}
                </span>
                <small>{health.apiDetail}</small>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#16a34a' }}>
              <span className="cm-kpi-ico" style={{ background: '#dcfce7', color: '#16a34a' }}>
                <ArrowRightLeft size={24} />
              </span>
              <div>
                <div className="cm-kpi-label">Sync pendiente</div>
                <span className="cm-kpi-val">{health.stats?.pendientesSync ?? 0}</span>
                <small>cola sync_queue</small>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#2563eb' }}>
              <span className="cm-kpi-ico" style={{ background: '#dbeafe', color: '#2563eb' }}>
                <Globe size={24} />
              </span>
              <div>
                <div className="cm-kpi-label">Sesión web</div>
                <span className="cm-kpi-val" style={{ fontSize: 16 }}>{user?.codigo_empleado}</span>
                <small>fuente: {user?.fuente ?? 'local'}</small>
              </div>
            </div>
          </div>

          <Card title="Módulos del ecosistema" icon={Smartphone}>
            <div className="hb-table-wrap">
              <table className="hb-table">
                <thead>
                  <tr>
                    <th>Módulo</th>
                    <th>Tecnología</th>
                    <th>Puerto</th>
                    <th>Estado</th>
                  </tr>
                </thead>
                <tbody>
                  {health.modulos.map((m) => (
                    <tr key={m.nombre}>
                      <td><strong>{m.nombre}</strong></td>
                      <td>{m.tipo}</td>
                      <td>{m.puerto}</td>
                      <td>
                        {m.conectado ? (
                          <span style={{ color: '#16a34a', display: 'flex', alignItems: 'center', gap: 4 }}>
                            <CheckCircle2 size={16} /> OK
                          </span>
                        ) : (
                          <span style={{ color: '#dc2626', display: 'flex', alignItems: 'center', gap: 4 }}>
                            <XCircle size={16} /> Offline
                          </span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>

          {health.stats?.counts && (
            <Card title="Registros en BD (asesor actual)" icon={Database} style={{ marginTop: 16 }}>
              <div className="cm-quick-grid">
                {Object.entries(health.stats.counts).map(([tabla, n]) => (
                  <div key={tabla} className="cm-quick" style={{ cursor: 'default' }}>
                    <strong style={{ textTransform: 'capitalize' }}>{tabla.replace(/_/g, ' ')}</strong>
                    <span style={{ fontSize: 22, fontWeight: 800, color: '#EC0000' }}>{n}</span>
                  </div>
                ))}
              </div>
            </Card>
          )}

          <Card title="Flujo end-to-end (rúbrica proyecto final)" icon={ArrowRightLeft} style={{ marginTop: 16 }}>
            <ol style={{ margin: 0, paddingLeft: 20, lineHeight: 1.8 }}>
              {FLUJO.map((paso) => (
                <li key={paso}>{paso}</li>
              ))}
            </ol>
          </Card>
        </>
      )}
    </>
  )
}
