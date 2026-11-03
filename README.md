# ⚡ ZAKIERA — GT Bot Web Control

Web GUI untuk kontrol bot Growtopia (Bothax) secara remote.

- Live koordinat bot (x, y, world, gems)
- D-Pad movement (Up/Down/Left/Right/USE)
- 5×5 path grid — klik tile → bot `FindPath` ke sana
- Warp ke world
- Connect / Disconnect

---

## Cara Pakai

### 1. Clone & Install

```bash
git clone https://github.com/AkhmadZaki14/zakiera.git
cd zakiera
npm install
```

### 2. Jalankan Server + Ngrok

```bash
bash start.sh
```

Script ini otomatis:
- Jalankan server di port 3001
- Buka ngrok tunnel
- **Update URL ngrok di `zakiera_bot.lua` secara otomatis**
- Buka folder Finder

Output contoh:
```
===================================
 ZAKIERA RUNNING
 Web GUI : http://localhost:3001
 Bot URL : https://xxxx-xxx.ngrok-free.app
 Lua file: /path/to/zakiera/zakiera_bot.lua
===================================
```

### 3. Load Script di Bothax

Ambil file `zakiera_bot.lua` → load sebagai **script baru** di Bothax (terpisah dari script lain).

> Setiap kali `start.sh` dijalankan, URL ngrok otomatis update di file Lua.
> **Reload script di Bothax setelah jalankan start.sh.**

### 4. Buka Web GUI

Buka file langsung di browser:
```
zakiera/public/index.html
```

Atau akses via: `http://127.0.0.1:3001`

---

## Struktur File

```
zakiera/
├── server.js          — Express backend (API server)
├── public/
│   └── index.html     — Web GUI (vanilla JS, dark theme)
├── zakiera_bot.lua    — Script Bothax (load terpisah)
├── start.sh           — One-click start server + ngrok + update Lua
└── package.json
```

---

## API Endpoints

| Method | Path | Deskripsi |
|--------|------|-----------|
| POST | `/api/status` | Bot kirim status (x, y, world, gems, dll) |
| GET | `/api/status` | Web baca status bot |
| POST | `/api/command` | Web kirim perintah (move/warp/use) |
| GET | `/api/command` | Bot ambil antrian perintah |

---

## Requirements

- Node.js
- [ngrok](https://ngrok.com/download)
- Bothax (Android/Windows) dengan API: `io`, `MakeRequest`
