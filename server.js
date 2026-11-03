// zakiera backend v2 — multi-bot, fast poll
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

const PUBLIC_DIR = path.join('/Users/macbookpro/orca/projects/zakiera', 'public');
app.use(express.static(PUBLIC_DIR));
app.get('/', (_req, res) => res.sendFile(path.join(PUBLIC_DIR, 'index.html')));

// ── State ─────────────────────────────────────────────────────
const bots   = {};  // { botId: { x,y,world,status,level,gems,uptime,updatedAt } }
const queues = {};  // { botId: [ {id,type,payload,createdAt} ] }
let cmdId = 1;

function botId(req) {
  return (req.headers['x-bot-id'] || req.body?.botId || 'bot1').toString();
}

// ── Bot: POST status ──────────────────────────────────────────
app.post('/api/status', (req, res) => {
  const id = botId(req);
  const b  = req.body || {};
  const prev = bots[id] || {};
  bots[id] = {
    id,
    x:      typeof b.x      === 'number' ? b.x      : (prev.x      || 0),
    y:      typeof b.y      === 'number' ? b.y      : (prev.y      || 0),
    world:  typeof b.world  === 'string' ? b.world  : (prev.world  || ''),
    status: typeof b.status === 'string' ? b.status : (prev.status || 'Online'),
    level:  typeof b.level  === 'number' ? b.level  : (prev.level  || 0),
    gems:   typeof b.gems   === 'number' ? b.gems   : (prev.gems   || 0),
    uptime: typeof b.uptime === 'number' ? b.uptime : (prev.uptime || 0),
    updatedAt: Date.now(),
  };
  if (!queues[id]) queues[id] = [];
  res.json({ ok: true });
});

// ── Bot: GET command (consume queue) ──────────────────────────
app.get('/api/command', (req, res) => {
  const id   = (req.headers['x-bot-id'] || req.query.botId || 'bot1').toString();
  const cmds = (queues[id] || []).slice();
  queues[id] = [];
  res.json({ commands: cmds });
});

// ── Web: GET all bots ─────────────────────────────────────────
app.get('/api/bots', (_req, res) => {
  const now  = Date.now();
  const list = Object.values(bots).map(b => ({ ...b, online: now - b.updatedAt < 5000 }));
  res.json({ bots: list });
});

// ── Web: GET single bot status ────────────────────────────────
app.get('/api/status', (req, res) => {
  const id  = (req.query.botId || 'bot1').toString();
  const bot = bots[id];
  if (!bot) return res.json({ online:false, x:0, y:0, world:'', status:'Offline', level:0, gems:0, id });
  res.json({ ...bot, online: Date.now() - bot.updatedAt < 5000 });
});

// ── Web: POST command ─────────────────────────────────────────
app.post('/api/command', (req, res) => {
  const { type, payload, botId: bid } = req.body || {};
  const id = (bid || 'bot1').toString();
  if (!type) return res.status(400).json({ error: 'missing type' });
  const VALID = ['move', 'warp', 'use', 'disconnect', 'connect'];
  if (!VALID.includes(type)) return res.status(400).json({ error: 'unknown type' });
  if (!queues[id]) queues[id] = [];
  const cmd = { id: cmdId++, type, payload: payload || {}, createdAt: Date.now() };
  queues[id].push(cmd);
  if (queues[id].length > 100) queues[id] = queues[id].slice(-100);
  res.json({ ok: true, id: cmd.id });
});

app.get('/api/health', (_req, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 3001;
app.listen(PORT, '0.0.0.0', () => console.log(`zakiera v2 :${PORT}`));
