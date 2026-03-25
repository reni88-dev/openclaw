# =============================================================================
# OpenClaw — Simple VPS-Style Container for ARM64 (EasyPanel) + Gemini Proxy
# =============================================================================
# Konsep: Container ini seperti VPS kosong yang sudah terinstall openclaw
#         + Gemini proxy untuk pakai Google Gemini sebagai model utama.
#
# Build:  docker build --platform linux/arm64 -t openclaw:arm64 .
# Run:    docker run -d --name openclaw -e GEMINI_API_KEY=AIzaSy... -p 18789:18789 openclaw:arm64
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
      python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set timezone to Asia/Jakarta (WIB)
ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Rclone config — stored in persistent volume, symlinked to default path
RUN mkdir -p /root/.openclaw/rclone /root/.config \
    && ln -s /root/.openclaw/rclone /root/.config/rclone \
    && touch /root/.openclaw/rclone/rclone.conf

# Install OpenClaw globally
RUN npm install -g openclaw@2026.3.13

# Install Gemini Proxy
RUN git clone https://github.com/Aris-Setyawan/gemini-proxy.git /opt/gemini-proxy

# Create working directories
RUN mkdir -p /root/.openclaw /root/.openclaw/workspace

# Entrypoint script — starts proxy + gateway
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Persistent data
VOLUME ["/root/.openclaw"]

EXPOSE 18789

CMD ["/usr/local/bin/start.sh"]
