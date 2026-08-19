# Conexo Phase 10.3F.2 — Self-Hosted Face Verification Backend Plan

## 1. Current Architecture Findings

### Project Structure
- **Flutter app** at repo root: standard multi-platform Flutter project (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`).
- **No existing backend code**: no `backend/`, `server/`, `functions/`, or Python files outside of `create_migrations.py` and iOS debug helpers.
- **No Docker / docker-compose** files exist.
- **Git**: current branch `conexo-supabase`, remote `https://github.com/Debajyoti1234/Conexo.git`.
- **Tooling**: `tool/build_apk.ps1`, `tool/run.ps1`, `tool/supabase_dev.json`, `tool/supabase_vercel.json`.

### Supabase Configuration
- **URL/keys**: injected via `--dart-define-from-file=tool/supabase_dev.json` or `tool/supabase_vercel.json`.
- **Flutter client** uses only `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` (anon key).
- **Service role key** exists only in `scripts/seed-demo-users.js` as `process.env.SUPABASE_SERVICE_ROLE_KEY`. Never exposed to Flutter.
- **Auth**: email/password, Google Sign-In, phone OTP via `supabase_flutter`.

### Existing `profiles` Schema
- **Table**: `profiles` with `id UUID PRIMARY KEY DEFAULT auth.uid()`.
- **Photos**: `photos JSONB NOT NULL DEFAULT '[]'::jsonb`.
- **Verification**: `verification_status TEXT NOT NULL DEFAULT 'notVerified'`.
- **No `photo_verified` column** exists.
- **RLS**: owner-only write (`auth.uid() = id`); authenticated users can SELECT public profiles.

### Photos JSONB Structure
Each photo object in the `photos` array:
```json
{
  "id": "camera_1234567890",
  "assetPath": "/data/user/0/...",
  "isPrimary": true,
  "remoteUrl": "profiles/{userId}/photos/{photoId}.jpg",
  "uploadStatus": "uploaded"
}
```

### Primary Photo Rules (enforced by Flutter)
- `_normalizePrimary()` sets `isPrimary = (index == 0)`.
- First photo in the ordered array is always primary.
- Primary-photo invalidation logic was implemented in Phase 10.3F.1.

### Storage
- **Bucket**: `profile-photos` (private, assumed).
- **Path pattern**: `profiles/{userId}/photos/{photoId}.{ext}`.
- **Signed URLs**: 3600s TTL via `createSignedUrl()`.
- **No storage RLS migrations** in the repo — bucket must be configured manually in Supabase Dashboard.

### Existing Verification Status Architecture
- **Enum**: `VerificationStatus { notVerified, pending, verified }`.
- **Persistence**: `verification_status` column in `profiles`.
- **Save/load**: `saveProfile()` writes `verification_status`; `loadProfile()` reads it via `_snakeToCamel()`.
- **UI**: `PrivacyVerificationScreen`, `VerificationSection`, `VerifiedBadge`.
- **Cross-profile propagation**: Discovery, Connections, Chat, Profile Hero all read `verificationStatus`.

### Environment/Configuration Conventions
- Dart defines loaded from JSON files in `tool/`.
- No `.env` convention in the Flutter app.
- Secrets are never committed (`.gitignore` excludes `tool/supabase_dev.json`).

---

## 2. Recommended Backend Architecture

**Single Python FastAPI service** deployed as a standalone container/VPS process.

```text
Flutter App
    │
    │ Supabase access token + multipart selfie
    ▼
Self-Hosted Verification Service (Python FastAPI)
    │
    ├── Validate Supabase JWT (python-jose + JWKS)
    ├── Load profile from Supabase Postgres
    ├── Resolve primary photo from photos JSONB
    ├── Download primary photo from private Storage (service role key)
    ├── Face detection on selfie (insightface)
    │   └── Reject if 0 faces or >1 face
    ├── Face detection on primary photo (insightface)
    │   └── Reject if 0 faces or >1 face
    ├── ArcFace embedding generation (insightface buffalo_l)
    ├── Cosine similarity
    ├── Threshold check (configurable env var)
    │
    ├── Update profiles.verification_status = 'verified' | 'notVerified'
    │   (via Supabase Postgres API or direct Postgres with service role key)
    │
    ├── Delete temp selfie file (if any)
    └── Return { match: bool, threshold: float }
```

### Why not other options
- **On-device Flutter**: Cannot provide server-side authority. Client could be tampered with.
- **Supabase Edge Functions**: Deno runtime, limited memory (128–512 MB), short timeouts. No mature face-recognition runtime. InsightFace requires native libraries (CUDA/CPU OpenCV) that are not available in Deno/Edge.
- **Separate backend**: Only viable option for genuine 1:1 face matching with proper authority.

---

## 3. Proposed Repository Structure

```
backend/
  face-verification/
    README.md
    requirements.txt
    .env.example
    .gitignore
    app/
      __init__.py
      main.py                 # FastAPI app entrypoint
      config.py               # Environment/config loading
      models.py               # Pydantic request/response models
      auth.py                 # Supabase JWT validation
      storage.py              # Supabase Storage download helper
      face.py                 # InsightFace detection + embedding
      matching.py             # Cosine similarity + threshold
      verification.py         # Core verification orchestrator
    tests/
      __init__.py
      test_health.py
      test_auth.py
      test_verification.py
      test_face.py
      conftest.py
    scripts/
      seed_test_data.py       # Create test profiles/photos (non-production)
```

### Why this structure
- **Isolated from Flutter**: The backend lives in its own root directory. No coupling to Flutter build system.
- **Standard Python layout**: `app/` for source, `tests/` for pytest, `scripts/` for one-off utilities.
- **No monorepo tooling needed**: Each service is independently deployable.
- **Git-friendly**: Backend can have its own `.gitignore` without affecting the Flutter project.

---

## 4. API Contract

### GET /health
- **Purpose**: Liveness probe for deployment/load balancer.
- **Auth**: None.
- **Response**: `200 OK` with `{ "status": "ok" }`.

### POST /api/v1/verify-face
- **Purpose**: Compare live selfie against current primary profile photo.
- **Auth**: `Authorization: Bearer <Supabase access token>`.
- **Content-Type**: `multipart/form-data`.
- **Fields**:
  - `selfie` (file, required): Image file (JPEG/PNG/WebP), max 5 MB.
- **Success Response** (`200 OK`):
  ```json
  {
    "match": true,
    "threshold": 0.6,
    "reason": "match"
  }
  ```
- **Failure Responses**:
  - `400 Bad Request`: missing file, invalid file type, file too large.
  - `401 Unauthorized`: missing/invalid/expired Supabase token.
  - `404 Not Found`: user has no profile or no primary photo.
  - `422 Unprocessable Entity`: face detection found 0 or >1 faces in selfie or primary photo.
  - `429 Too Many Requests`: rate limit exceeded.
  - `500 Internal Server Error`: backend/model/storage failure.
- **Failure Body**:
  ```json
  {
    "match": false,
    "threshold": 0.6,
    "reason": "no_face | multiple_faces | invalid_primary_photo | low_similarity"
  }
  ```

### Rate Limiting
- **Per user**: 5 verification attempts per rolling 1-hour window.
- Enforced by user ID extracted from JWT (`sub` claim).
- Return `Retry-After` header on 429.

### Timeout
- Backend processing timeout: **30 seconds** (InsightFace CPU inference ~1–3s, plus I/O).
- Flutter client timeout: **45 seconds** to allow for network latency.

---

## 5. Authentication Design

### JWT Validation
1. Flutter sends `Authorization: Bearer <supabase_access_token>`.
2. Backend extracts the token.
3. Backend fetches Supabase JWKS from `https://<supabase_url>/auth/v1/.well-known/jwks.json`.
4. Backend validates signature, `exp`, `iss`, `aud`.
5. Backend extracts `sub` claim as the user ID.
6. **Never trust a user ID from request body/params.**

### Backend-to-Supabase Auth
- Backend uses **service role key** for:
  - Querying `profiles` table.
  - Downloading from `profile-photos` Storage.
  - Updating `profiles.verification_status`.
- Service role key is stored as an **environment variable** on the backend host.
- Never sent to Flutter, never logged, never exposed in responses.

---

## 6. Primary-Photo Resolution Design

### Algorithm
1. Load profile row: `SELECT photos FROM profiles WHERE id = <user_id>`.
2. Parse `photos` JSONB array.
3. Find the primary photo:
   - Iterate array; first element with `isPrimary == true` is primary.
   - If none marked primary, first element is primary (matches Flutter `_normalizePrimary()` fallback).
4. Extract `remoteUrl` from the primary photo object.
5. Validate `remoteUrl` starts with `profiles/` (expected Storage path prefix).
6. Download file from `profile-photos` bucket at that path using service role key.
7. If download fails or path is missing, return `404 Not Found` with reason `invalid_primary_photo`.

### Why this matches Flutter exactly
- Flutter's `_normalizePrimary()` enforces exactly one primary: first in array.
- Backend uses the same first-element-with-isPrimary-true-or-first-element logic.
- No new photo-ordering system is invented.

---

## 7. Face Detection / Matching Design

### Pipeline
1. **Decode image**: OpenCV `cv2.imdecode()` from bytes. Supports JPEG, PNG, WebP.
2. **Face detection**: `insightface.get()` on decoded image.
   - Returns list of face objects with bounding box and landmarks.
3. **Exactly-one validation**:
   - If `len(faces) == 0`: return `no_face`.
   - If `len(faces) > 1`: return `multiple_faces`.
   - Take `faces[0]` when exactly one.
4. **Alignment/preprocessing**: InsightFace handles alignment internally via facial landmarks.
5. **Embedding generation**: `face.embedding` from InsightFace ArcFace (buffalo_l model).
6. **Cosine similarity**: `cosine_similarity(embedding_selfie, embedding_primary)`.
7. **Threshold check**: `similarity >= VERIFICATION_THRESHOLD` (env var, default `0.6`).

### Threshold Configuration
- Environment variable: `VERIFICATION_THRESHOLD` (float, `0.0` to `1.0`).
- Default: `0.6`.
- Must be configurable without code changes.
- Production tuning requires a validation set; do not assume `0.6` is final.

### Model/Runtime
- **Model**: `insightface` (buffalo_l / ArcFace). Downloaded automatically on first run.
- **Runtime**: CPU-only. No GPU required for low-throughput verification.
- **Memory**: ~1–2 GB RAM for model loading. Subsequent inferences are lightweight.
- **Latency**: ~200–500ms per image on modern x86_64 CPU. Total request ~1–3s.

### False Positive / Negative Considerations
- **False positive**: Different person with similar facial features passes. Higher threshold reduces this but increases false negatives.
- **False negative**: Same person with different lighting/angle fails. Lower threshold helps but increases false positives.
- **Mitigation**: Start with `0.6`, tune on real user data, allow retry.

---

## 8. Privacy Design

### What is NOT stored
- Selfie images: never written to disk, never uploaded to Supabase Storage.
- Face embeddings: in-memory only, never persisted.
- Biometric templates: never created.
- Raw face-recognition data: never logged.

### Temporary Data Handling
| Data | Location | Lifetime | Deletion |
|------|----------|----------|----------|
| Selfie bytes | Memory + optional temp file | Single request (~1–3s) | Python garbage collection; if temp file written, delete in `finally` block |
| Embeddings | NumPy arrays in memory | Single request | GC after request completes |

### Logging
- Log only: user ID, timestamp, match result, reason, processing time.
- **Never log**: image data, embeddings, tokens, secrets.

### Supabase Storage
- Backend **never uploads** selfies to `profile-photos` or any bucket.
- Backend **only reads** primary photos from `profile-photos`.
- Backend **only writes** `verification_status` to the `profiles` table.

---

## 9. Security Design

### Service Role Key
- Stored as `SUPABASE_SERVICE_ROLE_KEY` environment variable on backend host.
- Never committed, never logged, never sent to Flutter.
- Used only for Supabase Postgres/Storage operations from the backend.

### JWT Validation
- Verify signature against Supabase JWKS.
- Check `exp`, `iss`, `aud`.
- Reject tokens that fail any check.

### Request Protection
- **Max selfie size**: 5 MB. Reject larger with `400`.
- **Allowed content types**: `image/jpeg`, `image/png`, `image/webp`.
- **Rate limiting**: 5 attempts per user per hour.
- **Timeout**: 30s hard limit on inference.

### CORS
- Backend must allow only the Conexo app origins.
- For production: exact domain(s).
- For development: localhost.

### HTTPS
- Backend must be served over HTTPS in production.
- No HTTP in production.

### Error Handling
- Do not leak internal error details to client.
- Generic `500` message for unexpected failures.
- Log full traceback server-side only.

---

## 10. Infrastructure Recommendation

### Suitable Options

| Provider | Type | CPU | RAM | Cold Start | Cost (est.) | InsightFace Fit |
|----------|------|-----|-----|------------|-------------|-----------------|
| **DigitalOcean Droplet** | VPS | 2 vCPU | 4 GB | None (always on) | $24/mo | Excellent |
| **Railway** | Container | 2 vCPU | 4 GB | Low (~2s) | ~$10–20/mo | Good |
| **Fly.io** | Container | Shared | 256 MB–1 GB | Low | ~$5–15/mo | Marginal (RAM) |
| **Render** | Container | Shared | 512 MB | Medium | ~$7–25/mo | Marginal (RAM) |
| **AWS EC2 t3.small** | VPS | 2 vCPU | 2 GB | None | ~$15/mo | Good |

### Recommendation
**DigitalOcean Droplet (2 vCPU, 4 GB RAM)** or **Railway (2 vCPU, 4 GB RAM)**.

Rationale:
- Always-on process avoids cold-start latency.
- 4 GB RAM comfortably loads InsightFace buffalo_l.
- Simple deployment: Docker container or direct `uvicorn` process.
- Low cost for low traffic.
- No complex orchestration needed.

### Deployment Model
- Docker container with Python 3.10-slim base.
- Expose port 8000.
- Reverse proxy (Caddy/Nginx) for HTTPS + CORS.
- Health check endpoint for process monitoring.

---

## 11. Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SUPABASE_URL` | Yes | — | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | — | Supabase service role key (backend only) |
| `VERIFICATION_THRESHOLD` | No | `0.6` | Cosine similarity threshold (0.0–1.0) |
| `MAX_SELFIE_SIZE_MB` | No | `5` | Max upload size in MB |
| `RATE_LIMIT_WINDOW_SECONDS` | No | `3600` | Rate limit window (1 hour) |
| `RATE_LIMIT_MAX_ATTEMPTS` | No | `5` | Max attempts per window |
| `ALLOWED_ORIGINS` | Yes | — | Comma-separated CORS origins |
| `PORT` | No | `8000` | Server port |
| `LOG_LEVEL` | No | `INFO` | Logging level |

---

## 12. Dependencies

### `requirements.txt`
```
fastapi==0.111.0
uvicorn[standard]==0.30.0
insightface==0.7.3
opencv-python-headless==4.9.0.80
supabase==2.3.1
python-jose[cryptography]==3.3.0
python-multipart==0.0.9
pydantic==2.7.1
pydantic-settings==2.2.1
slowapi==0.1.9
```

### Notes
- `insightface` bundles the buffalo_l model automatically on first import.
- `opencv-python-headless` avoids GUI dependencies.
- `slowapi` provides rate limiting for FastAPI.
- `pydantic-settings` loads config from environment variables.

---

## 13. Testing Strategy

### Unit Tests (`tests/`)
1. **`test_health.py`**: GET `/health` returns 200.
2. **`test_auth.py`**:
   - Missing token → 401.
   - Invalid token → 401.
   - Expired token → 401.
   - Valid token → extracts correct user ID.
3. **`test_verification.py`**:
   - Missing profile → 404.
   - Missing primary photo → 404.
   - Invalid image bytes → 400.
   - Zero faces → 422 (`no_face`).
   - Multiple faces → 422 (`multiple_faces`).
   - Matching faces → 200 with `match: true`.
   - Non-matching faces → 200 with `match: false`.
   - Low similarity → 200 with `match: false`.
   - Oversized upload → 400.
   - Rate limit exceeded → 429.
   - Backend timeout → 500 (simulated).
   - Supabase Storage failure → 500.
   - InsightFace init failure → 500.

### Integration Tests
- Use small synthetic test images (not real user photos) with known face detection results.
- Mock Supabase responses for deterministic tests.
- Test that selfie temp files are deleted after processing.

### Privacy Validation Tests
- Assert that no temp files remain after request completion.
- Assert that logs do not contain image data or embeddings (scan log output).
- Assert that service role key is not present in any response.

### Test Data
- `scripts/seed_test_data.py` creates non-production test profiles with synthetic photos.
- Never run against production Supabase.

---

## 14. Exact Implementation Phases

### 10.3F.2.1 — Backend project scaffolding
- Create `backend/face-verification/` directory structure.
- Add `requirements.txt`, `.env.example`, `README.md`, `.gitignore`.
- Add `app/main.py` with FastAPI app, `/health`, and CORS middleware.

### 10.3F.2.2 — Configuration and auth
- Implement `app/config.py` with `pydantic-settings`.
- Implement `app/auth.py` with Supabase JWT validation via JWKS.
- Add dependency injection for authenticated user ID.

### 10.3F.2.3 — Supabase integration
- Implement `app/storage.py`:
  - Load profile row.
  - Parse `photos` JSONB.
  - Resolve primary photo using existing Conexo ordering rules.
  - Download primary photo from `profile-photos` bucket.
- Implement `verification_status` update via Supabase Postgres client.

### 10.3F.2.4 — Face detection and matching
- Implement `app/face.py`:
  - Image decoding with OpenCV.
  - InsightFace initialization (buffalo_l).
  - Face detection with exactly-one validation.
  - Embedding extraction.
- Implement `app/matching.py`:
  - Cosine similarity.
  - Threshold comparison using env var.

### 10.3F.2.5 — Core verification endpoint
- Implement `app/verification.py`:
  - Orchestrate the full pipeline.
  - Handle all failure modes with appropriate HTTP status codes.
  - Ensure temp file cleanup in `finally` blocks.
- Wire into `POST /api/v1/verify-face`.

### 10.3F.2.6 — Security hardening
- Add rate limiting (`slowapi`).
- Add request size limits.
- Add CORS with `ALLOWED_ORIGINS`.
- Add request timeout middleware.
- Ensure no secrets in logs.

### 10.3F.2.7 — Testing
- Write pytest suite for all endpoints and edge cases.
- Add CI-ready test command.
- Validate privacy constraints (no temp files, no secrets in logs).

### 10.3F.2.8 — Deployment preparation
- Add `Dockerfile`.
- Add `.dockerignore`.
- Document deployment steps for DigitalOcean / Railway.
- Add health check configuration.

---

## 15. Files That Will Eventually Be Created

| File | Purpose |
|------|---------|
| `backend/face-verification/README.md` | Service overview and deployment docs |
| `backend/face-verification/requirements.txt` | Python dependencies |
| `backend/face-verification/.env.example` | Environment variable template |
| `backend/face-verification/.gitignore` | Python/node/IDE ignores |
| `backend/face-verification/Dockerfile` | Container build |
| `backend/face-verification/.dockerignore` | Docker build context |
| `backend/face-verification/app/__init__.py` | Package marker |
| `backend/face-verification/app/main.py` | FastAPI entrypoint |
| `backend/face-verification/app/config.py` | Config loading |
| `backend/face-verification/app/models.py` | Pydantic schemas |
| `backend/face-verification/app/auth.py` | JWT validation |
| `backend/face-verification/app/storage.py` | Supabase profile/photo access |
| `backend/face-verification/app/face.py` | InsightFace detection/embedding |
| `backend/face-verification/app/matching.py` | Similarity + threshold |
| `backend/face-verification/app/verification.py` | Core orchestrator |
| `backend/face-verification/tests/__init__.py` | Test package |
| `backend/face-verification/tests/conftest.py` | Test fixtures |
| `backend/face-verification/tests/test_health.py` | Health endpoint tests |
| `backend/face-verification/tests/test_auth.py` | Auth tests |
| `backend/face-verification/tests/test_verification.py` | Verification tests |
| `backend/face-verification/tests/test_face.py` | Face model tests |
| `backend/face-verification/scripts/seed_test_data.py` | Test data seeder |

---

## 16. Existing Files That Will Eventually Need Modification

| File | Modification |
|------|--------------|
| `lib/features/profile/profile_data.dart` | Add `photoVerified` field in later phase |
| `lib/features/profile/supabase_profile_repository.dart` | Map `photo_verified` in later phase |
| `lib/features/profile/privacy_verification_screen.dart` | Wire to backend in later phase |
| `lib/features/profile/privacy_verification_sections.dart` | Update UI copy in later phase |
| `lib/features/profile/privacy_verification_widgets.dart` | Update widgets in later phase |
| `lib/features/profile/public_profile_widgets.dart` | Badge wiring in later phase |
| `lib/features/profile/profile_navigation_mapper.dart` | Propagation in later phase |
| `lib/features/profile/profile_management_screen.dart` | Replace photo invalidation already done |
| `lib/features/profile/profile_creation_sections.dart` | Already has invalidation logic |
| `pubspec.yaml` | Add `camera` dependency in later phase |
| `tool/supabase_dev.json` | Add backend URL for dev if needed |

**None of these are modified during Phase 10.3F.2.**

---

## 17. Supabase Changes

### Required for this phase
**None.**

### Rationale
- `verification_status` already exists in `profiles`.
- Backend updates this existing column directly via service role key.
- No new columns, no new tables, no new Storage buckets, no Edge Functions.
- No migration file is needed at this stage.

### Future considerations (not this phase)
- If `photo_verified` is ever added, it would be a separate decision.
- If audit logging is needed, a `verification_attempts` table could be added later.

---

## 18. Risks and Limitations

### Face matching without liveness
- Printed photos, screen replay, or deepfakes can pass 1:1 matching.
- Conexo must label this clearly as "profile photo match," not identity verification or KYC.
- Liveness detection is **deferred** to a future phase.

### ML runtime limitations
- InsightFace on CPU: ~200–500ms per image.
- Requires always-on process; serverless cold starts are too slow.
- Model download on first run (~100 MB) must be handled in deployment.

### Android performance
- No heavy ML on device. Only JPEG capture and upload.
- Upload size: ~100–500 KB per selfie.

### False positives / false negatives
- Threshold `0.6` is a starting point, not production-ready.
- Must be tuned on real data before production launch.
- Lighting, angle, occlusion affect results.

### Privacy implications
- Users send a live face photo to a server.
- Must disclose clearly in UI and privacy policy.
- Backend must be trusted not to retain data.

### Infrastructure risk
- New point of failure for verification.
- Need monitoring, health checks, and graceful degradation.
- If backend is down, show "Verification temporarily unavailable" in Flutter.

### Deployment complexity
- Python/InsightFace deployment is more complex than a typical Node.js API.
- Requires correct system libraries (libGL, etc.) in container.
- Model caching must persist across container restarts (volume mount).

---

## 19. Recommended Next Implementation Task

**10.3F.2.1 — Backend project scaffolding**

Create the `backend/face-verification/` directory structure, `requirements.txt`, `.env.example`, `README.md`, `.gitignore`, and `app/main.py` with FastAPI app, `/health` endpoint, and CORS middleware.

---

## Final Summary

- **PLAN ONLY — NO FILES CHANGED**
- **Supabase migration required at this stage**: NO — `verification_status` already exists.
- **Flutter changes required at this stage**: NO — this phase is backend-only planning.
- **Exact next implementation step**: 10.3F.2.1 — Backend project scaffolding (create `backend/face-verification/` directory, `requirements.txt`, `.env.example`, `app/main.py` with `/health`).
