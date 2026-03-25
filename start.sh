#!/bin/bash
# =============================================================================
# OpenClaw + Gemini Proxy — Entrypoint Script
# =============================================================================
# Starts gemini-proxy (background) → waits until ready → starts openclaw gateway
#
# Environment Variables:
#   GEMINI_API_KEY   — single Gemini API key (backward compatible)
#   GEMINI_API_KEYS  — comma-separated list of keys for auto-rotation
#                      Example: "AIzaSy_KEY1,AIzaSy_KEY2,AIzaSy_KEY3"
# =============================================================================

echo '🦞 OpenClaw container started.'

# ---------------------------------------------------------------------------
# Helper: resolve the list of API keys
# ---------------------------------------------------------------------------
resolve_keys() {
  if [ -n "$GEMINI_API_KEYS" ]; then
    echo "$GEMINI_API_KEYS"
  elif [ -n "$GEMINI_API_KEY" ]; then
    echo "$GEMINI_API_KEY"
  fi
}

KEYS_CSV=$(resolve_keys)

# ---------------------------------------------------------------------------
# 1. Start Gemini Proxy (if any key is set)
# ---------------------------------------------------------------------------
if [ -n "$KEYS_CSV" ]; then
  # Use first key for proxy .env
  FIRST_KEY=$(echo "$KEYS_CSV" | cut -d',' -f1 | tr -d ' ')
  echo "🔑 Gemini API key(s) detected — starting Gemini Proxy..."

  # Write .env for the proxy (uses first key as default)
  cat > /opt/gemini-proxy/.env <<EOF
GEMINI_API_KEY=$FIRST_KEY
PROXY_PORT=9998
PROXY_HOST=127.0.0.1
EOF

  # Start proxy in background
  cd /opt/gemini-proxy
  python3 proxy.py >> /root/.openclaw/gemini-proxy.log 2>&1 &
  PROXY_PID=$!
  echo "🔄 Gemini Proxy starting (PID: $PROXY_PID)..."

  # Wait until proxy is ready (max 15 seconds)
  for i in $(seq 1 30); do
    if ss -tlnp 2>/dev/null | grep -q ':9998'; then
      echo "✅ Gemini Proxy ready on port 9998"
      break
    fi
    if [ $i -eq 30 ]; then
      echo "⚠️  Gemini Proxy may not be ready yet — check /root/.openclaw/gemini-proxy.log"
    fi
    sleep 0.5
  done

  # -------------------------------------------------------------------
  # 2. Auto-configure OpenClaw auth profiles with all keys
  # -------------------------------------------------------------------
  CONFIG_DIR="$HOME/.openclaw"
  OPENCLAW_JSON="$CONFIG_DIR/openclaw.json"

  if [ -f "$OPENCLAW_JSON" ]; then
    KEY_COUNT=0
    IFS=',' read -ra KEY_ARRAY <<< "$KEYS_CSV"

    for KEY in "${KEY_ARRAY[@]}"; do
      KEY=$(echo "$KEY" | tr -d ' ')
      [ -z "$KEY" ] && continue
      KEY_COUNT=$((KEY_COUNT + 1))
    done

    echo "🔑 Configuring $KEY_COUNT Gemini API key(s) in OpenClaw auth profiles..."

    # Update auth-profiles.json for each agent
    for agent_dir in "$CONFIG_DIR"/agents/*/agent; do
      [ -d "$agent_dir" ] || continue
      AUTH_FILE="$agent_dir/auth-profiles.json"

      python3 -c "
import json, sys

keys_csv = '''$KEYS_CSV'''
keys = [k.strip() for k in keys_csv.split(',') if k.strip()]

try:
    with open('$AUTH_FILE') as f:
        data = json.load(f)
except:
    data = {'profiles': {}}

if 'profiles' not in data:
    data['profiles'] = {}

for i, key in enumerate(keys, 1):
    profile_id = 'google:key{}'.format(i)
    data['profiles'][profile_id] = {
        'provider': 'google',
        'key': key,
        'Authorization': 'Bearer ' + key
    }

with open('$AUTH_FILE', 'w') as f:
    json.dump(data, f, indent=2)

print('  Updated: $AUTH_FILE ({} keys)'.format(len(keys)))
"
    done

    # Update openclaw.json — set auth.order for google
    python3 -c "
import json

keys_csv = '''$KEYS_CSV'''
keys = [k.strip() for k in keys_csv.split(',') if k.strip()]

try:
    with open('$OPENCLAW_JSON') as f:
        data = json.load(f)
except:
    data = {}

# Set auth.order.google
if 'auth' not in data:
    data['auth'] = {}
if 'order' not in data['auth']:
    data['auth']['order'] = {}

profile_ids = ['google:key{}'.format(i) for i in range(1, len(keys) + 1)]
data['auth']['order']['google'] = profile_ids

with open('$OPENCLAW_JSON', 'w') as f:
    json.dump(data, f, indent=2)

print('  Updated: $OPENCLAW_JSON (auth.order.google = {})'.format(profile_ids))
"

    echo "✅ Multi-key rotation configured ($KEY_COUNT keys)"
  else
    echo "⚠️  $OPENCLAW_JSON not found — skip auth config (run openclaw onboard first)"
  fi

else
  echo '⚠️  GEMINI_API_KEY / GEMINI_API_KEYS not set — Gemini Proxy skipped.'
  echo '💡 Set GEMINI_API_KEY or GEMINI_API_KEYS environment variable to enable Gemini.'
fi

# ---------------------------------------------------------------------------
# 3. Start OpenClaw Gateway (same logic as original Dockerfile)
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
