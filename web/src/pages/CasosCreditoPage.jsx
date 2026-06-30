import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  BookOpen, Search, CheckCircle2, AlertTriangle, XCircle, ArrowRight,
} from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Badge from '../components/ui/Badge.jsx'
import Money from '../components/ui/Money.jsx'
import { CASOS_CREDITO_30, RESUMEN_CASOS } from '../data/casosCredito30.js'
import { PASOS_FLUJO } from '../utils/creditoCalculator.js'

const FILTROS = ['Todos', 'APROBADO', 'CONDICIONADO', 'RECHAZADO']

function decisionTone(d) {
  if (d === 'APROBADO') return 'green'
  if (d === 'CONDICIONADO') return 'amber'
  return 'red'
}

function DecisionIcon({ decision }) {
  if (decision === 'APROBADO') return <CheckCircle2 size={16} color="#16a34a" />
  if (decision === 'CONDICIONADO') return <AlertTriangle size={16} color="#d97706" />
  return <XCircle size={16} color="#dc2626" />
}

export default function CasosCreditoPage() {
  const navigate = useNavigate()
  const [filtro, setFiltro] = useState('Todos')
  const [q, setQ] = useState('')

  const lista = useMemo(() => {
    return CASOS_CREDITO_30.filter((c) => {
      const okFiltro = filtro === 'Todos' || c.comite.decision === filtro
      const okQ =
        !q ||
        c.nombre.toLowerCase().includes(q.toLowerCase()) ||
        c.documento.includes(q) ||
        String(c.id).includes(q)
      return okFiltro && okQ
    })
  }, [filtro, q])

  return (
    <>
      <PageHead
        title="30 Casos de Crédito — Flujo Móvil"
        subtitle="Practica el flujo completo: App Clientes → Core → FVentas → Comité → Desembolso"
      />

      <div className="cm-kpis" style={{ marginBottom: 20 }}>
        <div className="cm-kpi">
          <span className="cm-kpi-ico" style={{ background: '#dcfce7', color: '#16a34a' }}>
            <CheckCircle2 size={22} />
          </span>
          <div>
            <div className="cm-kpi-label">Desembolsados</div>
            <span className="cm-kpi-val">{RESUMEN_CASOS.desembolsados}</span>
          </div>
        </div>
        <div className="cm-kpi" style={{ borderLeftColor: '#d97706' }}>
          <span className="cm-kpi-ico" style={{ background: '#fef3c7', color: '#d97706' }}>
            <AlertTriangle size={22} />
          </span>
          <div>
            <div className="cm-kpi-label">Condicionados</div>
            <span className="cm-kpi-val">{RESUMEN_CASOS.condicionados}</span>
          </div>
        </div>
        <div className="cm-kpi" style={{ borderLeftColor: '#dc2626' }}>
          <span className="cm-kpi-ico" style={{ background: '#fee2e2', color: '#dc2626' }}>
            <XCircle size={22} />
          </span>
          <div>
            <div className="cm-kpi-label">Rechazados</div>
            <span className="cm-kpi-val">{RESUMEN_CASOS.rechazados}</span>
          </div>
        </div>
      </div>

      <Card title="Flujo del estudiante (8 pasos)" icon={BookOpen}>
        <div className="cm-flow-steps">
          {PASOS_FLUJO.map((p) => (
            <div key={p.paso} className="cm-flow-step">
              <span className="cm-flow-num">{p.paso}</span>
              <div>
                <strong>{p.titulo}</strong>
                <small>{p.rol} · {p.app}</small>
              </div>
            </div>
          ))}
        </div>
        <p style={{ margin: '14px 0 0', fontSize: 13, color: 'var(--hb-muted)' }}>
          Tarifario: TEA 40.92 % (con seguro) · 43.92 % (sin seguro) · Cuota fija · TEM = (1+TEA)^(1/12)−1
        </p>
      </Card>

      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', margin: '20px 0 14px' }}>
        {FILTROS.map((f) => (
          <button
            key={f}
            className={`hb-chip ${filtro === f ? 'active' : ''}`}
            onClick={() => setFiltro(f)}
          >
            {f}
          </button>
        ))}
        <div className="cm-search-wrap" style={{ flex: 1, minWidth: 200 }}>
          <Search size={16} />
          <input
            placeholder="Buscar por nombre, DNI o caso #"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
      </div>

      <div className="hb-table-wrap">
        <table className="hb-table">
          <thead>
            <tr>
              <th>#</th>
              <th>Cliente</th>
              <th>DNI</th>
              <th className="num">Monto sol.</th>
              <th>Plazo</th>
              <th>Buró</th>
              <th>Decisión</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {lista.map((c) => (
              <tr key={c.id}>
                <td><strong>{c.id}</strong></td>
                <td>{c.nombre}<br /><small style={{ color: 'var(--hb-muted)' }}>{c.negocio}</small></td>
                <td>{c.documento}</td>
                <td className="num"><Money value={c.solicitud.monto} /></td>
                <td>{c.solicitud.plazo} meses</td>
                <td><Badge tone={c.buro.calificacion === 'NORMAL' ? 'green' : 'amber'}>{c.buro.calificacion}</Badge></td>
                <td>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                    <DecisionIcon decision={c.comite.decision} />
                    {c.comite.decision}
                  </span>
                </td>
                <td>
                  <button className="hb-btn hb-btn-sm" onClick={() => navigate(`/casos/${c.id}`)}>
                    Ver caso <ArrowRight size={14} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {lista.length === 0 && (
          <div className="hb-table-empty">No hay casos con ese filtro.</div>
        )}
      </div>
    </>
  )
}
