// zakiera backend — in-memory state, no DB needed
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());
const PUBLIC_DIR = path.join('/Users/macbookpro/orca/projects/zakiera', 'public');
app.use(express.static(PUBLIC_DIR));
app.get('/', (_req, res) => res.sendFile(path.join(PUBLIC_DIR, 'index.html')));

// ── State ────────────────────────────────────────────────────
let botStatus = {
  x: 0, y: 0,
  world: '',
  status: 'Offline',
  level: 0,
  gems: 0,
  uptime: 0,
  updatedAt: 0,
};

// Command queue: [{ id, type, payload, createdAt }]
let cmdQueue = [];
let cmdIdCounter = 1;

// ── Bot endpoints (called by Lua bot) ───────────────────────

// Bot POST status setiap ~1 detik
app.post('/api/status', (req, res) => {
  const b = req.body;
  botStatus = {
    x:         typeof b.x === 'number'      ? b.x      : botStatus.x,
    y:         typeof b.y === 'number'      ? b.y      : botStatus.y,
    world:     typeof b.world === 'string'  ? b.world  : botStatus.world,
    status:    typeof b.status === 'string' ? b.status : botStatus.status,
    level:     typeof b.level === 'number'  ? b.level  : botStatus.level,
    gems:      typeof b.gems === 'number'   ? b.gems   : botStatus.gems,
    uptime:    typeof b.uptime === 'number' ? b.uptime : botStatus.uptime,
    updatedAt: Date.now(),
  };
  res.json({ ok: true });
});

// Bot GET command — ambil semua perintah pending, lalu clear
app.get('/api/command', (req, res) => {
  const cmds = cmdQueue.slice();
  cmdQueue = [];
  res.json({ commands: cmds });
});

// ── Web endpoints (called by frontend) ──────────────────────

// Web GET status
app.get('/api/status', (req, res) => {
  const online = botStatus.updatedAt > 0 && (Date.now() - botStatus.updatedAt) < 5000;
  res.json({ ...botStatus, online });
});

// Web POST command
// body: { type: 'move'|'warp'|'use', payload: { x, y } | { world } }
app.post('/api/command', (req, res) => {
  const { type, payload } = req.body;
  if (!type) return res.status(400).json({ error: 'missing type' });

  const VALID = ['move', 'warp', 'use'];
  if (!VALID.includes(type)) return res.status(400).json({ error: 'unknown type' });

  const cmd = { id: cmdIdCounter++, type, payload: payload || {}, createdAt: Date.now() };
  cmdQueue.push(cmd);

  // Trim queue — jangan numpuk kalau bot offline
  if (cmdQueue.length > 50) cmdQueue = cmdQueue.slice(-50);

  res.json({ ok: true, id: cmd.id });
});

// Health
app.get('/api/health', (_req, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 3001;
app.listen(PORT, '0.0.0.0', () => console.log(`zakiera running on http://localhost:${PORT}`));
