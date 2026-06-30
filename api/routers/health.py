from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/")
def root():
    return {
        "service": "Core Mobile API — Banco Andino / Santander Consumer",
        "version": "1.0.0",
        "status": "ok",
    }


@router.get("/health")
def health():
    return {"status": "ok", "service": "core-mobile-api", "port": 8003}
