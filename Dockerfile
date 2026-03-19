# =============================================================================
# OpenClaw — Simple VPS-Style Container for ARM64 (EasyPanel)
# =============================================================================

FROM --platform=linux/arm64 node:22-bookworm

# Install essential tools
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

# Rclone config
RUN mkdir -p /root/.openclaw/rclone /root/.config \
    && ln -s /root/.openclaw/rclone /root/.config/rclone \
    && touch /root/.openclaw/rclone/rclone.conf

# Install OpenClaw and PM2 globally
RUN npm install -g openclaw@2026.3.13 pm2

# Create working directories
RUN mkdir -p /root/.openclaw /root/.openclaw/workspace

# Buat Bash Script untuk eksekusi yang aman oleh PM2
RUN echo 'openclaw gateway --port 18789' > /root/start.sh && chmod +x /root/start.sh

# Persistent data
VOLUME ["/root/.openclaw"]

EXPOSE 18789

# Gunakan PM2 untuk mengeksekusi bash script
CMD ["bash", "-c", "\
  echo '🦞 OpenClaw container started.'; \
  if ss -tlnp 2>/dev/null | grep -q ':18789'; then \
    echo '⚠️  Gateway already running on port 18789, skipping...'; \
  else \
    pm2 start /root/start.sh --name gateway >> /root/.openclaw/gateway.log 2>&1; \
    echo '🦞 Gateway launched via PM2 Script (logs: /root/.openclaw/gateway.log)'; \
  fi; \
  echo '💡 First time? Run: openclaw onboard'; \
  echo '🔄 To restart bot later, run: pm2 restart gateway'; \
  tail -f /dev/null"]