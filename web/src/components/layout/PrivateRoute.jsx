import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext.jsx'
import Loader from '../ui/Loader.jsx'

export default function PrivateRoute({ children }) {
  const { isAuthenticated, booting } = useAuth()
  const location = useLocation()

  if (booting) {
    return (
      <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
        <Loader text="Restaurando sesión…" />
      </div>
    )
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }
  return children
}
