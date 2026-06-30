import { createContext, useContext, useState, useCallback, useMemo, useEffect } from 'react'
import * as authService from '../services/authService.js'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => authService.getStoredToken())
  const [user, setUser] = useState(() => authService.getStoredUser())
  const [booting, setBooting] = useState(true)

  useEffect(() => {
    authService
      .tryRestoreSession()
      .then((session) => {
        if (session?.token && session?.user) {
          authService.saveSession(session.token, session.user)
          setToken(session.token)
          setUser(session.user)
        }
      })
      .finally(() => setBooting(false))
  }, [])

  const login = useCallback(async (codigoEmpleado, password) => {
    const { token: newToken, user: newUser } = await authService.login(
      codigoEmpleado,
      password,
    )
    authService.saveSession(newToken, newUser)
    setToken(newToken)
    setUser(newUser)
    return newUser
  }, [])

  const logout = useCallback(async () => {
    await authService.clearSession()
    setToken(null)
    setUser(null)
  }, [])

  const value = useMemo(
    () => ({
      user,
      token,
      isAuthenticated: Boolean(token),
      booting,
      login,
      logout,
    }),
    [user, token, booting, login, logout],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth debe usarse dentro de <AuthProvider>')
  return ctx
}

export default useAuth
