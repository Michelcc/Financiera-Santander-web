import { useMemo } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  ChevronLeft, MapPin, FileText, ShieldCheck, Calculator, Ban,
} from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Badge from '../components/ui/Badge.jsx'
import Money from '../components/ui/Money.jsx'
import Alert from '../components/ui/Alert.jsx'
import { getCasoById } from '../data/casosCredito30.js'
import {
  PASOS_FLUJO,
  ESTADOS_EXPEDIENTE,
  calcularCuota,
  generarCronograma,
  buroPorDocumento,
  preEvaluacionCapacidad,
  TEA_CON_SEGURO,
  TEA_SIN_SEGURO,
} from '../utils/creditoCalculator.js'
import { formatDate } from '../utils/format.js'

export default function CasoDetallePage() {
  const { casoId } = useParams()
  const navigate = useNavigate()
  const caso = getCasoById(Number(casoId))

  const calc = useMemo(() => {
    if (!caso) return null
    const montoCalc =
      caso.comite.decision === 'CONDICIONADO'
        ? caso.comite.montoAprobado
        : caso.comite.decision === 'RECHAZADO'
          ? caso.solicitud.monto
          : caso.comite.montoAprobado
    const tea = caso.solicitud.conSeguro ? TEA_CON_SEGURO : TEA_SIN_SEGURO
    const cuotaCalc = calcularCuota(
      montoCalc,
      caso.solicitud.plazo,
      tea,
      caso.solicitud.conSeguro,
    )
    const buroSim = buroPorDocumento(caso.documento)
    const preSim = preEvaluacionCapacidad(
      caso.ingreso,
      caso.gasto,
      caso.solicitud.cuotaReferencia,
    )
    const cronograma =
      caso.desembolso &&
      generarCronograma(
        caso.comite.montoAprobado,
        caso.solicitud.plazo,
        tea,
        caso.solicitud.conSeguro,
        caso.desembolso.fecha,
        caso.desembolso.diaPago,
      )
    return { cuotaCalc, buroSim, preSim, cronograma, tea }
  }, [caso])

  if (!caso) {
    return (
      <>
        <Alert tipo="error">Caso no encontrado.</Alert>
        <button className="hb-btn" onClick={() => navigate('/casos')}>
          Volver al listado
        </button>
      </>
    )
  }

  const bloqueadoBuro = caso.buro.inhabilitado || caso.buro.calificacion === 'PERDIDA'

  return (
    <>
      <button className="hb-btn hb-btn-ghost" onClick={() => navigate('/casos')} style={{ marginBottom: 12 }}>
        <ChevronLeft size={18} /> Volver a los 30 casos
      </button>

      <PageHead
        title={`Caso ${caso.id} — ${caso.nombre}`}
        subtitle={`DNI ${caso.documento} · ${caso.negocio} · ${caso.distrito}`}
      />

      {caso.comite.decision === 'RECHAZADO' && (
        <Alert tipo="error">
          <Ban size={16} style={{ verticalAlign: 'middle', marginRight: 6 }} />
          {caso.comite.motivoRechazo}
        </Alert>
      )}

      <div className="cm-detail-grid">
        <Card title="Datos del solicitante" icon={FileText}>
          <dl className="cm-dl">
            <dt>Teléfono</dt><dd>{caso.telefono}</dd>
            <dt>Antigüedad negocio</dt><dd>{caso.antiguedadMeses} meses</dd>
            <dt>Ingreso / Gasto</dt><dd><Money value={caso.ingreso} /> / <Money value={caso.gasto} /></dd>
            <dt>Ubicación GPS</dt><dd><MapPin size={14} /> {caso.lat}, {caso.lng}</dd>
          </dl>
        </Card>

        <Card title="Solicitud (App Clientes)" icon={FileText}>
          <dl className="cm-dl">
            <dt>Producto</dt><dd>{caso.solicitud.producto}</dd>
            <dt>Monto / Plazo</dt><dd><Money value={caso.solicitud.monto} /> · {caso.solicitud.plazo} meses</dd>
            <dt>TEA</dt><dd>{caso.solicitud.conSeguro ? '40.92 % con seguro' : '43.92 % sin seguro'}</dd>
            <dt>Garantía / Destino</dt><dd>{caso.solicitud.garantia} · {caso.solicitud.destino}</dd>
            <dt>Cuota referencia</dt><dd><strong><Money value={caso.solicitud.cuotaReferencia} /></strong></dd>
            <dt>Estado inicial</dt><dd><Badge tone="turq">{caso.solicitud.estado}</Badge></dd>
          </dl>
        </Card>

        <Card title="Pre-evaluación y buró (paso 5)" icon={ShieldCheck}>
          <dl className="cm-dl">
            <dt>Pre-eval. esperada</dt>
            <dd>{caso.preEvaluacion.resultado} (puntaje {caso.preEvaluacion.puntaje})</dd>
            <dt>Pre-eval. simulada</dt>
            <dd>{calc.preSim.resultado} (puntaje {calc.preSim.puntaje})</dd>
            <dt>Buró esperado</dt>
            <dd>
              {caso.buro.calificacion} · {caso.buro.entidades} ent. ·{' '}
              <Money value={caso.buro.deudaTotal} /> · {caso.buro.moraDias} d mora
            </dd>
            <dt>Buró simulado (últ. dígito DNI)</dt>
            <dd>{calc.buroSim.sbs} · {calc.buroSim.entidades} ent.</dd>
          </dl>
          {bloqueadoBuro && (
            <Alert tipo="warn">Bloqueo en paso 5: cliente en lista de inhabilitados.</Alert>
          )}
        </Card>

        <Card title="Comité y desembolso (paso 8)" icon={Calculator}>
          <dl className="cm-dl">
            <dt>Decisión</dt>
            <dd><Badge tone={caso.comite.decision === 'APROBADO' ? 'green' : caso.comite.decision === 'CONDICIONADO' ? 'amber' : 'red'}>{caso.comite.decision}</Badge></dd>
            <dt>Monto aprobado</dt>
            <dd>{caso.comite.montoAprobado > 0 ? <Money value={caso.comite.montoAprobado} /> : '—'}</dd>
            {caso.desembolso && (
              <>
                <dt>Desembolso</dt><dd>{formatDate(caso.desembolso.fecha)}</dd>
                <dt>Cuota mensual</dt>
                <dd>
                  PDF: <Money value={caso.desembolso.cuotaMensual} /> ·
                  Calc: <Money value={calc.cuotaCalc} />
                </dd>
              </>
            )}
          </dl>
          {caso.comite.motivoRechazo && caso.comite.decision !== 'RECHAZADO' && (
            <p style={{ fontSize: 13, color: 'var(--hb-muted)' }}>{caso.comite.motivoRechazo}</p>
          )}
        </Card>
      </div>

      <Card title="Checklist del flujo" icon={FileText} style={{ marginTop: 16 }}>
        <ol className="cm-checklist">
          {PASOS_FLUJO.map((p) => (
            <li key={p.paso}>
              <strong>Paso {p.paso}:</strong> {p.titulo} <em>({p.app})</em>
            </li>
          ))}
        </ol>
        <p style={{ marginTop: 12, fontSize: 13 }}>
          <strong>Login cliente:</strong> DNI <code>{caso.documento}</code> · clave demo{' '}
          <code>santander2026</code> ·{' '}
          <strong>Asesor:</strong> OP001
        </p>
      </Card>

      {calc.cronograma && calc.cronograma.length > 0 && (
        <Card title="Cronograma (amortización francesa)" icon={Calculator} style={{ marginTop: 16 }}>
          <div className="hb-table-wrap">
            <table className="hb-table">
              <thead>
                <tr>
                  <th>N°</th>
                  <th>Fecha pago</th>
                  <th className="num">Cuota</th>
                  <th className="num">Capital</th>
                  <th className="num">Interés</th>
                  <th className="num">Saldo</th>
                </tr>
              </thead>
              <tbody>
                {calc.cronograma.slice(0, 3).map((f) => (
                  <tr key={f.n}>
                    <td>{f.n}</td>
                    <td>{formatDate(f.fecha)}</td>
                    <td className="num"><Money value={f.cuota} /></td>
                    <td className="num"><Money value={f.capital} /></td>
                    <td className="num"><Money value={f.interes} /></td>
                    <td className="num"><Money value={f.saldo} /></td>
                  </tr>
                ))}
                <tr><td colSpan={6} style={{ textAlign: 'center', color: 'var(--hb-muted)' }}>…</td></tr>
                {calc.cronograma.slice(-1).map((f) => (
                  <tr key={`last-${f.n}`}>
                    <td>{f.n}</td>
                    <td>{formatDate(f.fecha)}</td>
                    <td className="num"><Money value={f.cuota} /></td>
                    <td className="num"><Money value={f.capital} /></td>
                    <td className="num"><Money value={f.interes} /></td>
                    <td className="num"><Money value={f.saldo} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      <div style={{ marginTop: 16, display: 'flex', gap: 10, flexWrap: 'wrap' }}>
        <button className="hb-btn hb-btn-ghost" onClick={() => navigate('/cartera')}>Ir a cartera</button>
        <button className="hb-btn" onClick={() => navigate('/casos')}>Listado 30 casos</button>
      </div>

      <Card title="Estados del expediente" style={{ marginTop: 16 }}>
        <div className="cm-estados">
          {ESTADOS_EXPEDIENTE.map((e) => (
            <span key={e} className="cm-estado-chip">{e}</span>
          ))}
        </div>
      </Card>
    </>
  )
}
