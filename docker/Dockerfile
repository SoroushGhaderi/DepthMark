# DepthMark - Production Dockerfile
# Multi-stage build for optimal image size

FROM python:3.11-slim as builder

# Set build arguments
ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies (libssl-dev needed to compile curl_cffi)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    python3-dev \
    libssl-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ============================================
# Final stage
# ============================================
FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH" \
    DEBIAN_FRONTEND=noninteractive \
    CHROME_BIN=/usr/bin/chromium \
    CHROMEDRIVER_PATH=/usr/bin/chromedriver \
    WDM_LOCAL=1 \
    WDM_LOG_LEVEL=0 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Install runtime dependencies (Chrome for Selenium)
# Install chromium-driver from apt to avoid runtime download issues
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-driver \
    chromium-sandbox \
    wget \
    gnupg \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    xdg-utils \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Configure Chrome to run in headless mode by default
RUN echo 'CHROMIUM_FLAGS="$CHROMIUM_FLAGS --no-sandbox --headless --disable-gpu --disable-dev-shm-usage"' >> /etc/chromium.d/default-flags

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Download Playwright's Chromium into a system-wide directory so that the
# non-root appuser can access it at runtime.
RUN /opt/venv/bin/playwright install chromium && \
    chmod -R o+rx /ms-playwright

# Create app user (non-root for security)
RUN useradd --create-home --shell /bin/bash appuser && \
    mkdir -p /app/data /app/logs /app/config && \
    chown -R appuser:appuser /app

# Set working directory
WORKDIR /app

# Copy application files
COPY --chown=appuser:appuser src/ ./src/
COPY --chown=appuser:appuser scripts/ ./scripts/
COPY --chown=appuser:appuser config/ ./config/
COPY --chown=appuser:appuser pytest.ini ./

# Copy entrypoint script (as root, then fix permissions)
COPY docker/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Switch to non-root user
USER appuser

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command (can be overridden in docker-compose)
CMD ["python", "-m", "src.cli", "--help"]
