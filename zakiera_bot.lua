-- ============================================================
--  ZAKIERA BOT — Standalone Lua Script (Bothax Android)
--  Load via zakiera_loader.lua, BUKAN langsung
--  API List required: io, MakeRequest
-- ============================================================

local ZAKIERA_URL = "https://43dc-118-99-118-190.ngrok-free.app"

local HEADERS = {
    ["Content-Type"]               = "application/json",
    ["ngrok-skip-browser-warning"] = "1",
    ["User-Agent"]                 = "ZakieraBot/1.0",
}

local function Log(msg)
    LogToConsole("`0[`6ZAKIERA`0] " .. tostring(msg))
end

local function JsonEsc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
    s = s:gsub("\r", "\\r"):gsub("\n", "\\n"):gsub("\t", "\\t")
    return s
end

-- ── Movement ──────────────────────────────────────────────────
local function MoveTo(tx, ty)
    local me = GetLocal and GetLocal()
    if not me or not me.pos then return end
    if math.floor(me.pos.x/32) == tx and math.floor(me.pos.y/32) == ty then return end
    FindPath(tx, ty)
end

local function DoUse()
    local me = GetLocal and GetLocal()
    if not me or not me.pos then return end
    local px = math.floor(me.pos.x / 32)
    local py = math.floor(me.pos.y / 32)
    SendPacketRaw(false, { type=3, state=0, value=18, px=px, py=py, x=px*32, y=py*32 })
end

local function DoWarp(world)
    world = tostring(world or ""):upper()
    if world == "" then return end
    SendPacket(3, "action|join_request\nname|" .. world .. "\ninvitedWorld|0")
    Log("Warp " .. world)
end

-- ── POST status ───────────────────────────────────────────────
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
    pcall(MakeRequest, ZAKIERA_URL .. "/api/status", "POST", HEADERS, body)
end

-- ── GET & exec command ────────────────────────────────────────
local function FetchAndExec()
    local ok, resp = pcall(MakeRequest, ZAKIERA_URL .. "/api/command", "GET", HEADERS, "")
    if not ok then return end

    -- MakeRequest bisa return string atau table {content=...}
    local body = type(resp) == "table" and (resp.content or "") or tostring(resp or "")
    if body == "" then return end

    Log("RAW: " .. body:sub(1, 120))

    -- Cari semua command: type + x/y/world langsung dari full string
    -- Format: {"id":N,"type":"move","payload":{"x":30,"y":24},...}
    local found = false

    -- move
    for t, x, y in body:gmatch('"type"%s*:%s*"(move)"[^}]*"x"%s*:%s*(%-?%d+)[^}]*"y"%s*:%s*(%-?%d+)') do
        Log("Move " .. x .. "," .. y)
        pcall(MoveTo, tonumber(x), tonumber(y))
        found = true
    end
    -- move (payload setelah type)
    if not found then
        for x, y in body:gmatch('"payload"%s*:%s*%{[^}]*"x"%s*:%s*(%-?%d+)[^}]*"y"%s*:%s*(%-?%d+)') do
            if body:find('"type"%s*:%s*"move"') then
                Log("Move2 " .. x .. "," .. y)
                pcall(MoveTo, tonumber(x), tonumber(y))
                found = true
            end
        end
    end

    -- warp
    for world in body:gmatch('"type"%s*:%s*"warp".-"world"%s*:%s*"([^"]+)"') do
        pcall(DoWarp, world)
    end

    -- use
    if body:find('"type"%s*:%s*"use"') then
        pcall(DoUse)
    end

    -- disconnect
    if body:find('"type"%s*:%s*"disconnect"') then
        pcall(SendPacket, 3, "action|quit")
    end
end

-- ── Main ──────────────────────────────────────────────────────
Log("Zakiera v3 aktif → " .. ZAKIERA_URL)

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
