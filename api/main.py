from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import alertas, auth, cartera, cliente, cobranza, evaluacion, health, reportes, solicitudes

app = FastAPI(
    title="Core Mobile — Santander Consumer Perú",
    description="FastAPI — FVentas + Front Banking + App Clientes. "
    "Guía: mobile_backend_core_andino_fastapi (BD Supabase).",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:3000",
        "*",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(cartera.router)
app.include_router(solicitudes.router)
app.include_router(cobranza.router)
app.include_router(evaluacion.router)
app.include_router(reportes.router)
app.include_router(alertas.router)
app.include_router(cliente.router)


@app.get("/")
def root():
    return {
        "sistema": "Core Mobile Santander Consumer Perú",
        "version": "1.0.0",
        "status": "ok",
        "docs": "/docs",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=True,
    )
