import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Front Banking Santander — puerto 5173
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: true,
  },
})
