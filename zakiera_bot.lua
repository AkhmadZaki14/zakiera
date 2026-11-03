-- ============================================================
--  ZAKIERA BOT — Standalone Lua Script (Bothax)
--  Load sebagai script terpisah di Bothax, BUKAN di zakicit
--  API List required: io, MakeRequest
-- ============================================================

local ZAKIERA_URL = "https://dd27-118-99-118-190.ngrok-free.app"

-- ── Util ──────────────────────────────────────────────────────
local function NowTime()
    local ok, t = pcall(os.time)
    return ok and t or 0
end

local function JsonEsc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\r", "\\r")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\t", "\\t")
    return s
end

local function Log(msg)
    LogToConsole("`0[`6ZAKIERA`0] " .. tostring(msg))
end

-- ── Movement ──────────────────────────────────────────────────
local function MoveTo(tx, ty)
    local me = GetLocal and GetLocal()
    if not me or not me.pos then return end
    local cx = math.floor(me.pos.x / 32)
    local cy = math.floor(me.pos.y / 32)
    if cx == tx and cy == ty then return end
    -- Step-by-step A* via FindPath bawaan Bothax
    FindPath(tx, ty)
end

local function DoUse()
    local me = GetLocal and GetLocal()
    if not me or not me.pos then return end
    local px = math.floor(me.pos.x / 32)
    local py = math.floor(me.pos.y / 32)
    SendPacketRaw(false, { type = 3, state = 0, value = 18, px = px, py = py, x = px*32, y = py*32 })
end

local function DoWarp(world)
    world = tostring(world or ""):upper()
    if world == "" then return end
    SendPacket(3, "action|join_request\nname|" .. world .. "\ninvitedWorld|0")
    Log("Warp → " .. world)
end

-- ── Status POST ───────────────────────────────────────────────
local function PostStatus()
    local me = GetLocal and GetLocal()
    local px, py, lvl = 0, 0, 0
    if type(me) == "table" and me.pos then
        px  = math.floor(me.pos.x / 32)
        py  = math.floor(me.pos.y / 32)
        lvl = me.level or 0
    end

    local gems = 0
    pcall(function()
        local info = GetPlayerInfo()
        if info then gems = info.gems or 0 end
    end)

    local world = ""
    pcall(function()
        local w = GetWorld()
        if w and w.name then world = w.name:upper() end
    end)

    local body = string.format(
        '{"x":%d,"y":%d,"world":"%s","status":"Online","level":%d,"gems":%d,"uptime":0}',
        px, py, JsonEsc(world), lvl, gems)

    pcall(MakeRequest, ZAKIERA_URL .. "/api/status", "POST",
        { ["Content-Type"] = "application/json" }, body)
end

-- ── Command GET & exec ────────────────────────────────────────
local function FetchAndExec()
    local ok, body = pcall(MakeRequest, ZAKIERA_URL .. "/api/command", "GET", {}, "")
    if not ok or type(body) ~= "string" or body == "" then return end

    for block in body:gmatch('%{[^{}]+%}') do
        local t     = block:match('"type"%s*:%s*"([^"]+)"')
        local px    = tonumber(block:match('"x"%s*:%s*(%-?%d+)'))
        local py    = tonumber(block:match('"y"%s*:%s*(%-?%d+)'))
        local world = block:match('"world"%s*:%s*"([^"]*)"')
        if t == "move" and px and py then
            Log(string.format("Move → (%d,%d)", px, py))
            pcall(MoveTo, px, py)
        elseif t == "warp" and world and world ~= "" then
            pcall(DoWarp, world)
        elseif t == "use" then
            pcall(DoUse)
        elseif t == "disconnect" then
            Log("Disconnect")
            pcall(SendPacket, 3, "action|quit")
        end
    end
end

-- ── Main loop ─────────────────────────────────────────────────
Log("Zakiera web control aktif → " .. ZAKIERA_URL)

RunThread(function()
    while true do
        pcall(PostStatus)
        Sleep(1000)
    end
end)

RunThread(function()
    while true do
        pcall(FetchAndExec)
        Sleep(1000)
    end
end)
