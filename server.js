// zakiera backend v4 — Vercel + Upstash Redis (stateful serverless)
const express = require('express');
const cors    = require('cors');
const path    = require('path');

const app = express();
app.use(cors());
app.use(express.json());

const PUBLIC_DIR = path.join('/Users/macbookpro/orca/projects/zakiera', 'public');
app.use(express.static(PUBLIC_DIR));
app.get('/', (_req, res) => res.sendFile(path.join(PUBLIC_DIR, 'index.html')));

// ── Upstash Redis REST ────────────────────────────────────────
const REDIS_URL   = process.env.UPSTASH_REDIS_URL   || 'https://loved-foxhound-247910.upstash.io';
const REDIS_TOKEN = process.env.UPSTASH_REDIS_TOKEN || 'gQAAAAAAA8hmAQIgcDI2YzUxMmYwMDg0OTA0ODYzYjdiY2FlMGNkOTM1OWI1Ng';
const ONLINE_MS   = 15000;

async function redis(...args) {
  const r = await fetch(REDIS_URL, {
    method:  'POST',
    headers: { Authorization: `Bearer ${REDIS_TOKEN}`, 'Content-Type': 'application/json' },
    body:    JSON.stringify(args),
  });
  const j = await r.json();
  return j.result;
}

// helpers
const botKey   = id => `bot:${id}`;
const queueKey = id => `queue:${id}`;
const botsSet  = 'bots';

function isOnline(updatedAt) {
  return Date.now() - updatedAt < ONLINE_MS;
}

// ── Bot: POST status ──────────────────────────────────────────
app.post('/api/status', async (req, res) => {
  try {
    const id = (req.headers['x-bot-id'] || req.body?.botId || 'bot1').toString();
    const b  = req.body || {};
    const now = Date.now();
    const data = {
      id,
      x:         b.x         ?? 0,
      y:         b.y         ?? 0,
      world:     b.world     ?? '',
      status:    b.status    ?? 'Online',
      level:     b.level     ?? 0,
      gems:      b.gems      ?? 0,
      uptime:    b.uptime    ?? 0,
      updatedAt: now,
      inventory: JSON.stringify(b.inventory || []),
      tileInfo:  JSON.stringify(b.tileInfo  || []),
    };
    await Promise.all([
      redis('HSET', botKey(id), ...Object.entries(data).flat()),
      redis('EXPIRE', botKey(id), 120),   // auto-expire 2 menit
      redis('SADD', botsSet, id),
    ]);
    res.json({ ok: true });
  } catch(e) { res.status(500).json({ error: e.message }); }
});

// ── Bot: GET command ──────────────────────────────────────────
app.get('/api/command', async (req, res) => {
  try {
    const id = (req.headers['x-bot-id'] || req.query.botId || 'bot1').toString();
    // update lastSeen
    await redis('HSET', botKey(id), 'updatedAt', Date.now());
    // RPOP semua command dari queue (max 20)
    const cmds = [];
    for (let i = 0; i < 20; i++) {
      const raw = await redis('LPOP', queueKey(id));
      if (!raw) break;
      try { cmds.push(JSON.parse(raw)); } catch {}
    }
    res.json({ commands: cmds });
  } catch(e) { res.status(500).json({ commands: [] }); }
});

// ── Web: GET all bots ─────────────────────────────────────────
app.get('/api/bots', async (_req, res) => {
  try {
    const ids = await redis('SMEMBERS', botsSet);
    if (!ids || !ids.length) return res.json({ bots: [] });
    const bots = await Promise.all(ids.map(async id => {
      const raw = await redis('HGETALL', botKey(id));
      if (!raw || !raw.length) return null;
      const obj = {};
      for (let i = 0; i < raw.length; i += 2) obj[raw[i]] = raw[i+1];
      if (!obj.updatedAt) return null;
      return {
        id,
        x:         Number(obj.x)      || 0,
        y:         Number(obj.y)      || 0,
        world:     obj.world          || '',
        status:    obj.status         || 'Online',
        level:     Number(obj.level)  || 0,
        gems:      Number(obj.gems)   || 0,
        online:    isOnline(Number(obj.updatedAt)),
        inventory: JSON.parse(obj.inventory || '[]'),
        tileInfo:  JSON.parse(obj.tileInfo  || '[]'),
      };
    }));
    // prune null + offline yang sudah lama
    const live = bots.filter(Boolean);
    res.json({ bots: live });
  } catch(e) { res.status(500).json({ bots: [] }); }
});

// ── Web: POST command ─────────────────────────────────────────
app.post('/api/command', async (req, res) => {
  try {
    const { type, payload, botId: bid } = req.body || {};
    const id = (bid || 'bot1').toString();
    if (!type) return res.status(400).json({ error: 'missing type' });
    const VALID = ['move', 'warp', 'use', 'disconnect', 'connect', 'modfly'];
    if (!VALID.includes(type)) return res.status(400).json({ error: 'unknown type' });

    // Untuk move: replace command lama di queue (dedup)
    if (type === 'move') {
      await redis('DEL', queueKey(id));
    }
    const cmd = JSON.stringify({ type, payload: payload || {}, createdAt: Date.now() });
    await redis('RPUSH', queueKey(id), cmd);
    await redis('EXPIRE', queueKey(id), 60);
    res.json({ ok: true });
  } catch(e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/health', (_req, res) => res.json({ ok: true, redis: REDIS_URL }));

const PORT = process.env.PORT || 3001;
app.listen(PORT, '0.0.0.0', () => console.log(`zakiera v4 :${PORT}`));
