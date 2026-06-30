/**
 * Logo de marca de Banco Andino.
 * Isotipo: flor andina multicolor — pétalos con los colores del textil
 * (magenta, naranja, amarillo, verde, turquesa, morado) y centro cálido.
 */
const PETALOS = [
  { a: 0, c: '#e6398b' },
  { a: 60, c: '#f7941e' },
  { a: 120, c: '#fbc02d' },
  { a: 180, c: '#4caf50' },
  { a: 240, c: '#00a9a5' },
  { a: 300, c: '#8e24aa' },
]

export default function Logo({
  size = 44,
  wordmark = true,
  variant = 'dark',
  subtitle = 'CORE FINANCIERO',
}) {
  const textColor = variant === 'light' ? '#ffffff' : '#e2132b'
  const subColor = variant === 'light' ? 'rgba(255,255,255,.85)' : '#6b6b7b'
  const nameSize = Math.round(size * 0.5)
  const subSize = Math.max(9, Math.round(size * 0.23))

  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 12 }}>
      <svg width={size} height={size} viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-label="Banco Andino" role="img">
        {PETALOS.map((p) => (
          <ellipse key={p.a} cx="24" cy="13" rx="6" ry="11" fill={p.c} transform={`rotate(${p.a} 24 24)`} opacity="0.95" />
        ))}
        <circle cx="24" cy="24" r="7" fill="#fbc02d" />
        <circle cx="24" cy="24" r="3.4" fill="#e2132b" />
      </svg>

      {wordmark && (
        <span style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.04 }}>
          <span style={{ fontWeight: 800, fontSize: nameSize, color: textColor, letterSpacing: '-0.5px' }}>
            Banco Andino
          </span>
          {subtitle && (
            <span style={{ fontSize: subSize, fontWeight: 700, color: subColor, letterSpacing: '1.2px' }}>
              {subtitle}
            </span>
          )}
        </span>
      )}
    </span>
  )
}
