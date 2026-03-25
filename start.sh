#!/bin/bash
# =============================================================================
# OpenClaw + Gemini Proxy — Entrypoint Script
# =============================================================================
# Starts gemini-proxy (background) → waits until ready → starts openclaw gateway
# =============================================================================

echo '🦞 OpenClaw container started.'

# ---------------------------------------------------------------------------
# 1. Start Gemini Proxy (if GEMINI_API_KEY is set)
# ---------------------------------------------------------------------------
if [ -n "$GEMINI_API_KEY" ]; then
  echo '🔑 GEMINI_API_KEY detected — starting Gemini Proxy...'

  # Write .env for the proxy
  cat > /opt/gemini-proxy/.env <<EOF
GEMINI_API_KEY=$GEMINI_API_KEY
PROXY_PORT=9998
PROXY_HOST=127.0.0.1
EOF

  # Start proxy in background
  cd /opt/gemini-proxy
  python3 gemini-proxy.py >> /root/.openclaw/gemini-proxy.log 2>&1 &
  PROXY_PID=$!
  echo "🔄 Gemini Proxy starting (PID: $PROXY_PID)..."

  # Wait until proxy is ready (max 15 seconds)
  for i in $(seq 1 30); do
    if curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9998/v1/models 2>/dev/null | grep -q '200\|401'; then
      echo "✅ Gemini Proxy ready on port 9998"
      break
    fi
    if [ $i -eq 30 ]; then
      echo "⚠️  Gemini Proxy may not be ready yet — check /root/.openclaw/gemini-proxy.log"
    fi
    sleep 0.5
  done
else
  echo '⚠️  GEMINI_API_KEY not set — Gemini Proxy skipped.'
  echo '💡 Set GEMINI_API_KEY environment variable to enable Gemini.'
fi

# ---------------------------------------------------------------------------
# 2. Start OpenClaw Gateway (same logic as original Dockerfile)
# ---------------------------------------------------------------------------
if ss -tlnp 2>/dev/null | grep -q ':18789'; then
  echo '⚠️  Gateway already running on port 18789, skipping...'
else
  openclaw gateway --port 18789 >> /root/.openclaw/gateway.log 2>&1 &
  echo $! > /run/openclaw-gateway.pid
  echo "🦞 Gateway launched (PID: $!, logs: /root/.openclaw/gateway.log)"
fi

echo '💡 First time? Run: openclaw onboard'

# Keep container alive
tail -f /dev/null
