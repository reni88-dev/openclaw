# 🦞 OpenClaw — Deploy ke EasyPanel (ARM64)

## Konsep

Container ini bekerja seperti **VPS** — sudah terinstall `openclaw`, `pm2`, `vim`, dan `rclone` secara global.
Setelah deploy, masuk ke terminal dan jalankan `openclaw onboard` untuk setup awal. Bot diawasi oleh PM2 sehingga bisa melakukan *restart* mandiri dari dalam container.

---

## Deploy via EasyPanel UI

### Langkah 1 — Buat Service

1. Buka EasyPanel → **Create Service** → **App** → **GitHub**
2. Arahkan ke repo ini
3. **Dockerfile Path**: `Dockerfile`
4. **Volume**: mount `/root/.openclaw` → agar data persistent (tidak hilang saat restart/rebuild)
5. **Port**: ⚠️ **Tidak wajib** — hanya perlu jika ingin akses Control UI via web
   - Jika butuh: Published `18789`, Target `18789`, Protocol `TCP`
   - Jika tidak butuh akses web: **skip, jangan buat port**
6. Klik **Deploy**, tunggu build selesai

### Langkah 2 — Onboarding (Pertama Kali Saja)

1. Buka tab **Terminal** di EasyPanel (atau via `docker exec -it openclaw bash`)
2. Jalankan:
   ```bash
   openclaw onboard