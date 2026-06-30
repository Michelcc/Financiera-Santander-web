/**
 * Logo oficial Santander — assets/branding/santander_logo.png
 */
export default function Logo({
  height = 36,
  variant = 'dark',
  subtitle = 'FRONT BANKING',
  wordmark = true,
}) {
  const subColor = variant === 'light' ? 'rgba(255,255,255,.88)' : '#6b7280'
  const onRedHeader = variant === 'light'

  return (
    <span className={`sc-logo ${onRedHeader ? 'sc-logo--on-red' : ''}`}>
      <img
        src="/santander-logo.png"
        alt="Santander"
        className="sc-logo-img"
        height={height}
        style={{ height }}
      />
      {wordmark && subtitle && (
        <span className="sc-logo-sub" style={{ color: subColor }}>
          {subtitle}
        </span>
      )}
    </span>
  )
}
