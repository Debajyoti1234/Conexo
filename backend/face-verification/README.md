# Conexo Face Verification Backend

## Purpose

This service provides server-authoritative 1:1 profile-photo face matching for Conexo. It compares a live selfie captured by the user against their current primary Conexo profile photo and returns a match result. The backend owns the final verification authority; the Flutter client never sets verification state locally.

**This is NOT KYC or government-ID verification.** It only verifies that the live face matches the user's current primary profile photo.

## Current Status

**Phase 10.3F.2.7 — Testing complete**

The backend is fully implemented and tested:
- Configuration loading via `pydantic-settings`.
- Supabase JWT validation with JWKS caching.
- Authenticated user ID extraction from verified `sub` claim.
- Supabase profile and Storage integration with primary-photo resolution.
- InsightFace buffalo_l face detection and ArcFace embedding generation.
- Cosine similarity matching with configurable threshold.
- `/api/v1/verify-face` endpoint with validation and error handling.
- Per-user rate limiting (5 attempts per hour).
- 30-second request timeout.
- Generic error responses without sensitive data exposure.
- Full pytest suite: 46 tests passing.

## Local Setup

```powershell
cd backend\face-verification
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Environment

Create a local `.env` file (do not commit it) based on `.env.example`.

You must provide:

```text
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

**Never commit the real service-role key to source control.**

## Running

```powershell
python -m uvicorn app.main:app --reload --port 8000
```

## Health Check

```text
GET http://127.0.0.1:8000/health
```

Expected response:

```json
{
  "status": "ok"
}
```

## Authentication

```text
GET http://127.0.0.1:8000/api/v1/auth/me
Authorization: Bearer <Supabase access token>
```

Successful response:

```json
{
  "user_id": "<uuid>"
}
```

Unauthenticated requests return `401 Unauthorized`.

## Profile Primary Photo

```text
GET http://127.0.0.1:8000/api/v1/profile/primary-photo
Authorization: Bearer <Supabase access token>
```

Successful response:

```json
{
  "user_id": "<uuid>",
  "photo_id": "camera_1234567890",
  "storage_path": "profiles/<user-id>/photos/<photo-id>.jpg",
  "size_bytes": 184532
}
```

This endpoint:

- requires Supabase authentication
- reads the authenticated user's profile
- resolves the current primary photo
- downloads the private Storage object internally
- returns only metadata

Unauthenticated requests return `401 Unauthorized`.

## Verification Endpoint

```text
POST http://127.0.0.1:8000/api/v1/verify-face
Authorization: Bearer <Supabase access token>
Content-Type: multipart/form-data

Field: selfie (image file, max 5 MB)
```

Successful match response:

```json
{
  "match": true,
  "threshold": 0.6,
  "reason": "match",
  "similarity": 0.85xx
}
```

No-match response:

```json
{
  "match": false,
  "threshold": 0.6,
  "reason": "low_similarity",
  "similarity": 0.4xxx
}
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SUPABASE_URL` | Yes | — | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | — | Supabase service role key (backend only) |
| `VERIFICATION_THRESHOLD` | No | `0.6` | Cosine similarity threshold (0.0–1.0) |
| `MAX_SELFIE_SIZE_MB` | No | `5` | Max upload size in MB |
| `RATE_LIMIT_WINDOW_SECONDS` | No | `3600` | Rate limit window (1 hour) |
| `RATE_LIMIT_MAX_ATTEMPTS` | No | `5` | Max attempts per window |
| `ALLOWED_ORIGINS` | No | localhost fallbacks | Comma-separated CORS origins |
| `PORT` | No | `8000` | Server port |
| `LOG_LEVEL` | No | `INFO` | Logging level |

### Required production secrets

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

These must be provided as server environment variables. Never commit them to source control. Never expose the service-role key to the Flutter client.

### Configurable values

All other variables have safe defaults and can be tuned per environment.

## CORS

`ALLOWED_ORIGINS` controls which origins may call the API.

- Do NOT use `*` in production.
- For local development, empty configuration falls back to localhost origins.
- The mobile app does not rely on browser CORS; the web client does.

## Deployment

### Docker build

```powershell
docker build -t conexo-face-verification .
```

### Docker run (local)

```powershell
docker run --rm -p 8000:8000 `
  -e SUPABASE_URL="https://your-project.supabase.co" `
  -e SUPABASE_SERVICE_ROLE_KEY="your-service-role-key" `
  conexo-face-verification
```

### Production VPS deployment (Docker Compose + Caddy)

For a production VPS (e.g., DigitalOcean Droplet), use `docker-compose.yml` with a Caddy
reverse proxy that provides automatic HTTPS via Let's Encrypt.

```powershell
cd backend\face-verification
copy .env.example .env
# Edit .env: set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ALLOWED_ORIGINS
# Edit Caddyfile: replace {your-domain.example.com} with your real domain
docker compose up -d
```

- Caddy terminates HTTPS and proxies to FastAPI on the internal network.
- FastAPI (`face-verification`) is **never** exposed directly to the public internet.
- The Caddyfile uses a placeholder domain — replace it before deploying.
- See the **Production Security Checklist** below for production hardening steps.

### Railway deployment

1. Create a Railway project and add a new service.
2. Connect the repository to Railway.
3. Set the service root directory to `backend/face-verification`.
4. Railway will detect and use the existing `Dockerfile`.
5. Configure the following environment variables in Railway:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `ALLOWED_ORIGINS` (set to your production Conexo web origin, e.g. `https://conexo-seven.vercel.app`)
   - `VERIFICATION_THRESHOLD` (optional, defaults to `0.6`)
   - Other variables have safe defaults.
6. Generate a public Railway domain (e.g. `conexo-face-verification.up.railway.app`).
7. Verify the deployment:
   ```text
   GET https://your-railway-domain.up.railway.app/health
   ```
   Expected: `{"status": "ok"}`
8. Update `ALLOWED_ORIGINS` if needed after the domain is live.
9. **Do not update `FACE_VERIFICATION_API_URL` in the Flutter client until the Railway domain is confirmed working.**
10. Never commit Railway secrets, API tokens, or service-role keys to source control.

**Notes:**
- Railway provides HTTPS automatically; no Caddy or reverse proxy configuration is required.
- The container listens on `0.0.0.0` and uses Railway's `$PORT` environment variable.
- The existing `docker-compose.yml` and `Caddyfile` remain for VPS / local deployments only.

### Health check

```text
GET http://127.0.0.1:8000/health
```

Expected:

```json
{
  "status": "ok"
}
```

### Production deployment options

Recommended infrastructure:

- **DigitalOcean Droplet**: 2 vCPU / 4 GB RAM, always-on
- **Railway**: 2 vCPU / 4 GB RAM container

Both provide sufficient RAM for InsightFace buffalo_l and CPU-only inference.

### Reverse proxy / HTTPS

Production deployments should terminate HTTPS at a reverse proxy:

```text
Internet
  ↓
HTTPS reverse proxy / TLS  (Caddy / Nginx)
  ↓
FastAPI container :8000
```

Do not expose the FastAPI container directly to the public internet when a reverse proxy is available.

## Model / Cache Notes

- InsightFace buffalo_l is downloaded/initialized on first run.
- First startup may take additional time while model assets are obtained.
- Recommended baseline: 4 GB RAM.
- The container creates a writable home directory for model cache.
- Monitor startup time and memory in production.

## Production Security Checklist

- [ ] HTTPS enabled via reverse proxy
- [ ] Service-role key stored as server environment secret only
- [ ] No `.env` committed to Git
- [ ] No wildcard CORS (`*`) in production
- [ ] Rate limiting enabled (5 attempts per hour per user)
- [ ] 5 MB selfie limit enforced
- [ ] 30-second verification timeout enabled
- [ ] Generic error responses enabled
- [ ] Sensitive data excluded from logs
- [ ] Backend health monitoring enabled
- [ ] Firewall configured to expose only required ports
- [ ] FastAPI not directly exposed to public internet when reverse proxy is available
- [ ] Production logs monitored for anomalies

## Testing

```powershell
python -m pytest -q
```

Expected: 46 passed, 0 failed

## Security Note

- The Supabase service-role key must never be committed to source control.
- The service-role key must never be included in or exposed to the Flutter client.
- Access tokens and JWT contents are never logged.
- No biometric data is persisted. Selfies and embeddings are processed in memory only.
- The `profiles.verification_status` field is the only persistent verification state in Supabase.
