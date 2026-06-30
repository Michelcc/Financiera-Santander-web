import { Routes, Route, Navigate } from 'react-router-dom'
import PrivateRoute from './components/layout/PrivateRoute.jsx'
import Header from './components/layout/Header.jsx'

import LoginPage from './pages/LoginPage.jsx'
import DashboardPage from './pages/DashboardPage.jsx'
import CarteraPage from './pages/CarteraPage.jsx'
import FichaClientePage from './pages/FichaClientePage.jsx'
import SolicitudesPage from './pages/SolicitudesPage.jsx'
import NuevaSolicitudPage from './pages/NuevaSolicitudPage.jsx'
import EvaluacionPage from './pages/EvaluacionPage.jsx'
import CobranzaPage from './pages/CobranzaPage.jsx'
import ReportesPage from './pages/ReportesPage.jsx'
import CasosCreditoPage from './pages/CasosCreditoPage.jsx'
import CasoDetallePage from './pages/CasoDetallePage.jsx'
import EcosistemaPage from './pages/EcosistemaPage.jsx'
import AlertasPage from './pages/AlertasPage.jsx'

// Layout de las rutas autenticadas: cabecera + pestañas + contenido.
function PrivateLayout({ children }) {
  return (
    <PrivateRoute>
      <Header />
      <main className="cm-main">
        <div className="cm-container">{children}</div>
      </main>
    </PrivateRoute>
  )
}

export default function App() {
  return (
    <Routes>
      {/* Público */}
      <Route path="/login" element={<LoginPage />} />

      {/* Privado */}
      <Route path="/inicio" element={<PrivateLayout><DashboardPage /></PrivateLayout>} />
      <Route path="/cartera" element={<PrivateLayout><CarteraPage /></PrivateLayout>} />
      <Route path="/clientes/:clienteId/ficha" element={<PrivateLayout><FichaClientePage /></PrivateLayout>} />
      <Route path="/solicitudes" element={<PrivateLayout><SolicitudesPage /></PrivateLayout>} />
      <Route path="/solicitudes/nueva" element={<PrivateLayout><NuevaSolicitudPage /></PrivateLayout>} />
      <Route path="/evaluacion" element={<PrivateLayout><EvaluacionPage /></PrivateLayout>} />
      <Route path="/cobranza" element={<PrivateLayout><CobranzaPage /></PrivateLayout>} />
      <Route path="/reportes" element={<PrivateLayout><ReportesPage /></PrivateLayout>} />
      <Route path="/alertas" element={<PrivateLayout><AlertasPage /></PrivateLayout>} />
      <Route path="/ecosistema" element={<PrivateLayout><EcosistemaPage /></PrivateLayout>} />
      <Route path="/casos" element={<PrivateLayout><CasosCreditoPage /></PrivateLayout>} />
      <Route path="/casos/:casoId" element={<PrivateLayout><CasoDetallePage /></PrivateLayout>} />

      <Route path="/" element={<Navigate to="/inicio" replace />} />
      <Route path="*" element={<Navigate to="/inicio" replace />} />
    </Routes>
  )
}
