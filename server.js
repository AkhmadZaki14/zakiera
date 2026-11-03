// zakiera backend v3 — multi-bot, stable
// Fix: online threshold 15s, GET cmd update lastSeen, ghost bot1 cleanup
const express = require('express');
const cors    = require('cors');
const path    = require('path');

const app = express();
app.use(cors());
app.use(express.json());

const PUBLIC_DIR = path.join('/Users/macbookpro/orca/projects/zakiera', 'public');
app.use(express.static(PUBLIC_DIR));
app.get('/', (_req, res) => res.sendFile(path.join(PUBLIC_DIR, 'index.html')));

// ── Config ────────────────────────────────────────────────────
const ONLINE_MS = 15000;  // was 5000 — toleransi ngrok spike + warp
const PRUNE_MS  = 60000;  // hapus bot entry setelah 60s tidak ada kabar

// ── State ─────────────────────────────────────────────────────
const bots   = {};  // { botId: { ...fields, updatedAt } }
const queues = {};  // { botId: [ cmd, ... ] }
let cmdId = 1;

function getBotId(req) {
  // header wins, fallback body, fallback bot1
  return (req.headers['x-bot-id'] || req.body?.botId || 'bot1').toString();
}

function isOnline(bot) {
  return Date.now() - bot.updatedAt < ONLINE_MS;
}

// Hapus ghost "bot1" kalau sudah ada bot dengan nama asli
function pruneGhost(realId) {
  if (realId !== 'bot1' && bots['bot1'] && !isOnline(bots['bot1'])) {
    delete bots['bot1'];
    delete queues['bot1'];
  }
}

// Prune bot lama tiap 30s
setInterval(() => {
  const now = Date.now();
  for (const id of Object.keys(bots)) {
    if (now - bots[id].updatedAt > PRUNE_MS) {
      delete bots[id];
      delete queues[id];
    }
  }
}, 30000);

// ── Bot: POST status ──────────────────────────────────────────
app.post('/api/status', (req, res) => {
  const id   = getBotId(req);
  const b    = req.body || {};
  const prev = bots[id] || {};
  bots[id] = {
    id,
    x:         typeof b.x      === 'number' ? b.x      : (prev.x      || 0),
    y:         typeof b.y      === 'number' ? b.y      : (prev.y      || 0),
    world:     typeof b.world  === 'string' ? b.world  : (prev.world  || ''),
    status:    typeof b.status === 'string' ? b.status : (prev.status || 'Online'),
    level:     typeof b.level  === 'number' ? b.level  : (prev.level  || 0),
    gems:      typeof b.gems   === 'number' ? b.gems   : (prev.gems   || 0),
    uptime:    typeof b.uptime === 'number' ? b.uptime : (prev.uptime || 0),
    updatedAt: Date.now(),
    inventory: Array.isArray(b.inventory) ? b.inventory : (prev.inventory || []),
    tileInfo:  Array.isArray(b.tileInfo)  ? b.tileInfo  : (prev.tileInfo  || []),
  };
  if (!queues[id]) queues[id] = [];
  pruneGhost(id);
  res.json({ ok: true });
});

// ── Bot: GET command ──────────────────────────────────────────
app.get('/api/command', (req, res) => {
  const id = (req.headers['x-bot-id'] || req.query.botId || 'bot1').toString();
  // GET command juga update lastSeen — biar bot tetap online saat status POST telat
  if (bots[id]) bots[id].updatedAt = Date.now();
  const cmds = (queues[id] || []).slice();
  queues[id] = [];
  res.json({ commands: cmds });
});

// ── Web: GET all bots ─────────────────────────────────────────
app.get('/api/bots', (_req, res) => {
  const list = Object.values(bots).map(b => ({ ...b, online: isOnline(b) }));
  res.json({ bots: list });
});

// ── Web: GET single bot ───────────────────────────────────────
app.get('/api/status', (req, res) => {
  const id  = (req.query.botId || 'bot1').toString();
  const bot = bots[id];
  if (!bot) return res.json({ online:false, x:0, y:0, world:'', status:'Offline', level:0, gems:0, id });
  res.json({ ...bot, online: isOnline(bot) });
});

// ── Web: POST command ─────────────────────────────────────────
app.post('/api/command', (req, res) => {
  const { type, payload, botId: bid } = req.body || {};
  const id = (bid || 'bot1').toString();
  if (!type) return res.status(400).json({ error: 'missing type' });
  const VALID = ['move', 'warp', 'use', 'disconnect', 'connect', 'modfly'];
  if (!VALID.includes(type)) return res.status(400).json({ error: 'unknown type' });
  if (!queues[id]) queues[id] = [];
  const cmd = { id: cmdId++, type, payload: payload || {}, createdAt: Date.now() };
  queues[id].push(cmd);
  if (queues[id].length > 100) queues[id] = queues[id].slice(-100);
  res.json({ ok: true, id: cmd.id });
});

app.get('/api/health', (_req, res) => res.json({ ok: true, bots: Object.keys(bots).length }));

const PORT = process.env.PORT || 3001;
app.listen(PORT, '0.0.0.0', () => console.log(`zakiera v3 :${PORT}`));
