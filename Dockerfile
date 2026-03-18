# =============================================================================
# OpenClaw — Simple VPS-Style Container for ARM64 (EasyPanel)
# =============================================================================
# Konsep: Container ini seperti VPS kosong yang sudah terinstall openclaw.
# Tinggal exec ke terminal dan jalankan: openclaw onboard
#
# Build:  docker build --platform linux/arm64 -t openclaw:arm64 .
# Run:    docker run -d --name openclaw -p 18789:18789 openclaw:arm64
# Exec:   docker exec -it openclaw bash
# =============================================================================

FROM --platform=linux/arm64 node:22-bookworm

# Install essential tools (like a real VPS)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      git \
      nano \
      vim \
      htop \
      procps \
      rclone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set timezone to Asia/Jakarta (WIB)
ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Rclone config — stored in persistent volume, symlinked to default path
RUN mkdir -p /root/.openclaw/rclone /root/.config \
    && ln -s /root/.openclaw/rclone /root/.config/rclone \
    && touch /root/.openclaw/rclone/rclone.conf

# Install OpenClaw dan PM2 secara global
RUN npm install -g openclaw@2026.3.13 pm2

# Create working directories
RUN mkdir -p /root/.openclaw /root/.openclaw/workspace

# Persistent data
VOLUME ["/root/.openclaw"]

EXPOSE 18789

# Menjalankan PM2 sebagai process manager, dilanjutkan dengan tail untuk menahan container
CMD ["bash", "-c", "\
  echo '🦞 OpenClaw container started.'; \
  if ss -tlnp 2>/dev/null | grep -q ':18789'; then \
    echo '⚠️  Gateway already running on port 18789, skipping...'; \
  else \
    pm2 start openclaw --name gateway -- gateway --port 18789 >> /root/.openclaw/gateway.log 2>&1; \
    echo '🦞 Gateway launched via PM2 (logs: /root/.openclaw/gateway.log)'; \
  fi; \
  echo '💡 First time? Run: openclaw onboard'; \
  echo '🔄 To restart bot later, run: pm2 restart gateway'; \
  tail -f /dev/null"]