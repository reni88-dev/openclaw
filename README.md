# 🦞 OpenClaw — Deploy ke EasyPanel (ARM64) + Gemini Proxy

## Konsep

Container ini bekerja seperti **VPS** — sudah terinstall `openclaw`, `vim`, dan `rclone` secara global.
Sudah include **Gemini Proxy** untuk menggunakan Google Gemini sebagai model AI utama.
Setelah deploy, masuk ke terminal dan jalankan `openclaw onboard` untuk setup awal.

---

## Deploy via EasyPanel UI

### Langkah 1 — Buat Service

1. Buka EasyPanel → **Create Service** → **App** → **GitHub**
2. Arahkan ke repo ini (branch `with-gemini-proxy`)
3. **Dockerfile Path**: `Dockerfile`
4. **Environment Variable**: Tambahkan `GEMINI_API_KEY` = `AIzaSy...` (dari [Google AI Studio](https://aistudio.google.com/app/apikey))
5. **Volume**: mount `/root/.openclaw` → agar data persistent (tidak hilang saat restart/rebuild)
6. **Port**: ⚠️ **Tidak wajib** — hanya perlu jika ingin akses Control UI via web
   - Jika butuh: Published `18789`, Target `18789`, Protocol `TCP`
   - Jika tidak butuh akses web: **skip, jangan buat port**
7. Klik **Deploy**, tunggu build selesai

### Langkah 2 — Onboarding (Pertama Kali Saja)

1. Buka tab **Terminal** di EasyPanel
2. Jalankan:
   ```bash
   openclaw onboard
   ```
3. Ikuti instruksi onboarding (setup Telegram bot, dll)
4. Sampai muncul pesan:
   ```
   Onboarding complete. Use the dashboard link above to control OpenClaw.
   ```

### Langkah 3 — Restart Container

> ⚠️ **PENTING**: Setelah onboarding selesai, **WAJIB restart container** agar gateway otomatis jalan.

1. Di EasyPanel → klik **Redeploy** atau **Restart** pada service OpenClaw
2. Setelah restart, **proxy Gemini** dan **gateway** akan otomatis berjalan di background
3. Coba chat ke bot Telegram — seharusnya sudah merespons ✅

### Langkah 4 — Konfigurasi OpenClaw untuk Gemini

Setelah onboarding & restart, masuk ke terminal dan konfigurasi agar OpenClaw menggunakan Gemini:

#### 4a. Update `openclaw.json`

```bash
# Edit config utama
vim ~/.openclaw/openclaw.json
```

Tambahkan/update section `providers`:
```json
{
  "providers": {
    "gemini": {
      "name": "Google Gemini (via proxy)",
      "baseUrl": "http://127.0.0.1:9998",
      "api": "openai-completions",
      "models": [
        {
          "id": "models/gemini-2.5-flash",
          "name": "gemini-2.5-flash",
          "reasoning": false,
          "input": ["text", "image"],
          "contextWindow": 1048576,
          "maxTokens": 65536
        },
        {
          "id": "models/gemini-2.5-pro",
          "name": "gemini-2.5-pro",
          "reasoning": true,
          "input": ["text", "image"],
          "contextWindow": 1048576,
          "maxTokens": 65536
        }
      ]
    }
  }
}
```

Set `defaults.model.primary`:
```json
{
  "defaults": {
    "model": {
      "primary": "gemini/models/gemini-2.5-flash",
      "fallbacks": ["deepseek/deepseek-chat"]
    }
  }
}
```

#### 4b. Update `auth-profiles.json` untuk setiap agent

> `GEMINI_API_KEY` sudah tersedia di environment container (dari EasyPanel), jadi tinggal pakai langsung:

```bash
for agent in agent1 agent2 agent3 agent4 main; do
  python3 -c "
import json, os
path = os.path.expanduser('~/.openclaw/agents/$agent/agent/auth-profiles.json')
try:
    d = json.load(open(path))
except:
    d = {'profiles': {}}
d['profiles']['google:default'] = {
    'provider': 'google',
    'key': '$GEMINI_API_KEY',
    'Authorization': 'Bearer $GEMINI_API_KEY'
}
json.dump(d, open(path, 'w'), indent=2)
print(f'Updated {path}')
"
done
```

#### 4c. Restart OpenClaw

```bash
openclaw restart
```

### Langkah 5 — Verifikasi Gemini

```bash
# Cek proxy jalan
curl -s http://127.0.0.1:9998/v1/models | python3 -m json.tool | head -20

# Test chat completion
curl -s -X POST "http://127.0.0.1:9998/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GEMINI_API_KEY" \
  -d '{"model":"gemini-2.5-flash","messages":[{"role":"user","content":"say hi"}],"max_tokens":50}' \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])"
```

### Langkah 6 — Setup Rclone (Opsional)

Rclone sudah terinstall dan config file kosong sudah tersedia.
Config disimpan di volume persistent (`/root/.openclaw/rclone/`), jadi **tidak hilang** saat rebuild.

```bash
vim /root/.config/rclone/rclone.conf
```

---

## Deploy via Docker Compose (Opsional)

```bash
# 1. Set API key
export GEMINI_API_KEY=AIzaSy...

# 2. Build & jalankan
docker compose up -d

# 3. Masuk ke terminal container
docker exec -it openclaw bash

# 4. Jalankan onboarding
openclaw onboard

# 5. Restart container setelah onboarding
docker restart openclaw

# 6. Konfigurasi Gemini (lihat Langkah 4 di atas)
```

---

## Alur Ringkasan

```
Deploy Container (set GEMINI_API_KEY)
    ↓
Container Start → Gemini Proxy ✅ → Gateway GAGAL (belum onboarding) → Container tetap hidup
    ↓
Buka Terminal → openclaw onboard
    ↓
Onboarding Selesai
    ↓
⚠️ RESTART Container di EasyPanel
    ↓
Container Start → Proxy ✅ → Gateway ✅
    ↓
Konfigurasi openclaw.json + auth-profiles.json
    ↓
openclaw restart → Bot Telegram aktif dengan Gemini 🎉
```

---

## Tools yang Tersedia di Container

| Tool | Kegunaan |
|------|----------|
| `openclaw` | AI assistant via Telegram |
| `vim` | Text editor |
| `rclone` | Sync/transfer file ke cloud storage (GDrive, S3, dll) |
| `nano` | Text editor alternatif |
| `git` | Version control |
| `htop` | Monitor proses |
| `curl` | HTTP request |
| `python3` | Runtime untuk Gemini Proxy |

---

## Perintah Berguna

```bash
openclaw onboard                          # Setup awal (pertama kali)
openclaw gateway --port 18789 &           # Jalankan gateway manual (jika perlu)
openclaw doctor                           # Diagnostik
openclaw restart                          # Restart agents
openclaw update                           # Update ke versi terbaru
rclone lsd gdrive:                        # Test koneksi rclone
```

---

## Struktur Persistent Data

Semua data penting disimpan di volume `/root/.openclaw/` agar survive rebuild:

```
/root/.openclaw/
├── rclone/
│   └── rclone.conf          ← Config rclone
├── workspace/                ← Working directory openclaw
├── gateway.log               ← Log gateway
├── gemini-proxy.log          ← Log proxy Gemini
├── openclaw.json             ← Config utama
├── agents/
│   └── */agent/
│       └── auth-profiles.json ← API keys per agent
└── ...
```

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Bot Telegram tidak merespons | Pastikan gateway jalan: `ps aux \| grep openclaw`. Jika tidak ada, restart container |
| Gemini error 400 | Pastikan proxy jalan: `curl http://127.0.0.1:9998/v1/models`. Cek log: `cat /root/.openclaw/gemini-proxy.log` |
| Agent pakai OpenRouter, bukan Gemini | Cek `defaults.model.primary` di `openclaw.json` — pastikan `gemini/models/gemini-2.5-flash` |
| Agent fallback ke DeepSeek terus | Ketik `/new` di Telegram atau jalankan `openclaw restart` |
| "User location not supported" | IP server di negara tidak didukung. Gunakan server di US/SG/EU, atau set `HTTPS_PROXY` (lihat `gemini-proxy.md`) |
| Container exit sendiri | Pastikan `restart: unless-stopped` aktif |
| Perlu update openclaw | `npm install -g openclaw@latest` |
| Rclone config hilang setelah rebuild | Cek volume mount di EasyPanel |
