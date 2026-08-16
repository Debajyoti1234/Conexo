from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field, field_validator


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str
    VERIFICATION_THRESHOLD: float = Field(default=0.6, ge=0.0, le=1.0)
    MAX_SELFIE_SIZE_MB: int = Field(default=5, gt=0)
    RATE_LIMIT_WINDOW_SECONDS: int = Field(default=3600, gt=0)
    RATE_LIMIT_MAX_ATTEMPTS: int = Field(default=5, gt=0)
    ALLOWED_ORIGINS: str = ""
    PORT: int = Field(default=8000, gt=0, le=65535)
    LOG_LEVEL: str = Field(default="INFO")

    @field_validator("SUPABASE_URL")
    @classmethod
    def validate_supabase_url(cls, v: str) -> str:
        v = v.strip().rstrip("/")
        if not v.startswith("https://"):
            raise ValueError("SUPABASE_URL must start with https://")
        return v

    @property
    def allowed_origins(self) -> list[str]:
        raw = self.ALLOWED_ORIGINS.strip()
        if not raw:
            return [
                "http://localhost:5000",
                "http://127.0.0.1:5000",
                "http://localhost:3000",
                "http://127.0.0.1:3000",
            ]
        return [_normalize_origin(origin.strip()) for origin in raw.split(",") if origin.strip()]


_settings: Settings | None = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings


def _normalize_origin(origin: str) -> str:
    origin = origin.strip()
    if not origin.startswith(("http://", "https://")):
        return f"https://{origin}"
    return origin
