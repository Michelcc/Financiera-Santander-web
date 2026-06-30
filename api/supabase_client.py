from supabase import Client, create_client

from config import settings

_anon: Client | None = None


def get_anon_client() -> Client:
    global _anon
    if _anon is None:
        _anon = create_client(settings.supabase_url, settings.supabase_anon_key)
    return _anon


def client_with_jwt(jwt: str) -> Client:
    client = create_client(settings.supabase_url, settings.supabase_anon_key)
    client.postgrest.auth(jwt)
    return client
