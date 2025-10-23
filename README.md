# n8n Local Desktop Stack

## Persiapan
1. Salin berkas `.env.example` menjadi `.env` dan isi nilai `NGROK_AUTHTOKEN` sesuai akun ngrok Anda.
2. (Opsional) Atur `PUBLIC_BASE_URL` jika ingin mengunci URL publik tertentu. Kosongkan untuk auto-detect dari ngrok.

## Menjalankan
1. Jalankan stack: `docker compose up -d`.
2. Akses antarmuka n8n secara lokal melalui http://localhost.
3. Untuk melihat URL publik HTTPS, buka n8n → Settings → System Information dan periksa nilai **Webhook URL**. Nilai ini berasal dari ngrok dan akan digunakan untuk integrasi eksternal seperti Telegram.

## Integrasi Telegram
1. Buat bot baru lewat BotFather dan simpan tokennya di kredensial Telegram n8n.
2. Tambahkan node **Telegram Trigger** pada workflow, pilih kredensial bot, dan aktifkan workflow. n8n akan mengatur webhook ke URL publik ngrok (port 443) secara otomatis.

## Catatan
- Postgres berjalan tanpa diekspos ke host dan hanya diakses oleh n8n.
- Reverse proxy Caddy mendengarkan pada port 80 lokal dan meneruskan trafik ke n8n.
- Layanan ngrok menyediakan endpoint HTTPS publik sehingga layanan seperti Telegram dapat melakukan webhook.
