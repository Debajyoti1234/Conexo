FROM python:3.10-slim

# System dependencies for OpenCV, InsightFace, and ONNX Runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    curl \
    g++ \
    patchelf \
    libheif1 \
    libheif-dev \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Fix ONNX Runtime executable-stack requirement for Railway compatibility
RUN find /usr/local/lib/python* -name '*onnxruntime*.so' -exec patchelf --clear-execstack {} +

# Copy application code
COPY app/ ./app/

# Create writable cache directory for InsightFace model assets
RUN mkdir -p /home/appuser/.insightface && chown -R appuser:appgroup /home/appuser/.insightface

# Switch to non-root user
USER appuser

# Environment defaults
ENV PORT=8000 \
    LOG_LEVEL=INFO \
    MAX_SELFIE_SIZE_MB=5 \
    RATE_LIMIT_WINDOW_SECONDS=3600 \
    RATE_LIMIT_MAX_ATTEMPTS=5 \
    VERIFICATION_THRESHOLD=0.6

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:$PORT/health || exit 1

CMD uvicorn app.main:app --host 0.0.0.0 --port $PORT
