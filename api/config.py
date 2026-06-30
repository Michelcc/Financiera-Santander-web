from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    supabase_url: str = "https://jyuclilkqegictxmunfb.supabase.co"
    supabase_anon_key: str = "sb_publishable_1MEOuTvmRbHlDXDFelOtrQ_JPtyRAIN"
    supabase_service_role_key: str = ""
    api_host: str = "0.0.0.0"
    api_port: int = 8003


settings = Settings()
