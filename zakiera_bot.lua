-- ============================================================
--  ZAKIERA BOT v6 — Standalone (Bothax Android)
--  Fix: rate limit, bot ID cache, online threshold
--  Rate: status 5s (12/mnt) + command 3s (20/mnt) = 32/mnt
--  API List: io, MakeRequest
-- ============================================================

local ZAKIERA_URL      = "https://cdf9-118-99-118-190.ngrok-free.app"
local STATUS_INTERVAL  = 5000   -- 12/menit
local COMMAND_INTERVAL = 3000   -- 20/menit
local MAX_INV_ITEMS    = 50

-- ── Bot ID cache — FIX #1 ────────────────────────────────────
-- Jangan GetLocal() tiap request — cache nama, pakai saat nil (warp)
local _cachedBotId = nil

local function GetBotId()
    local ok, me = pcall(GetLocal)
    if ok and type(me) == "table" and me.name and me.name ~= "" then
        _cachedBotId = me.name  -- update cache
        return me.name
    end
    return _cachedBotId or "bot1"  -- pakai cache lama saat warp/nil
end

local function MakeHeaders()
    return {
        ["Content-Type"]               = "application/json",
        ["ngrok-skip-browser-warning"] = "1",
        ["User-Agent"]                 = "ZakieraBot/1.0",
        ["x-bot-id"]                   = GetBotId(),
    }
end

local function Log(msg)
    LogToConsole("`0[`6ZAKIERA`0] " .. tostring(msg))
end

local function JsonEsc(s)
    s = tostring(s or "")
    s = s:gsub("\\","\\\\"):gsub('"','\\"')
    s = s:gsub("\r","\\r"):gsub("\n","\\n"):gsub("\t","\\t")
    return s
end

-- ── Modfly ON ─────────────────────────────────────────────────
pcall(ChangeValue, "[C] ModFly", true)
Log("ModFly ON")

-- ── Safe HTTP helper ──────────────────────────────────────────
local function SafeReq(url, method, body)
    local ok, resp = pcall(MakeRequest, url, method, MakeHeaders(), body or "")
    if not ok then return nil end
    local content = type(resp) == "table" and (resp.content or "") or tostring(resp or "")
    if content:find("<!DOCTYPE", 1, true) or content:find("<html", 1, true) then return nil end
    return content
end

-- ── Tile safety ───────────────────────────────────────────────
local function IsSafe(tx, ty)
    if CheckPath then
        local ok, r = pcall(CheckPath, tx, ty)
        if ok then return r == true end
    end
    local ok, t = pcall(GetTile, tx, ty)
    if ok and t then return not t.collidable end
    return false
end

-- Tile info — lazy, hanya rebuild saat posisi berubah
local _lastTx, _lastTy = -1, -1
local _lastTileJson = "[]"

local function GetTileJson(px, py)
    if px == _lastTx and py == _lastTy then return _lastTileJson end
    _lastTx, _lastTy = px, py
    local arr = {}
    for dy = -2, 2 do
        for dx = -2, 2 do
            if not (dx==0 and dy==0) then
                local tx, ty = px+dx, py+dy
                arr[#arr+1] = string.format('{"x":%d,"y":%d,"safe":%s}',
                    tx, ty, IsSafe(tx,ty) and "true" or "false")
            end
        end
    end
    _lastTileJson = "[" .. table.concat(arr, ",") .. "]"
    return _lastTileJson
end

-- ── Inventory — max 50, kirim id+amount saja (ringan) ────────
local _lastInvJson  = "[]"
local _invTick      = 0

local function RebuildInv()
    local ok, inv = pcall(GetInventory)
    if not ok or not inv then return end
    local arr, n = {}, 0
    for _, item in pairs(inv) do
        if n >= MAX_INV_ITEMS then break end
        if item.id and item.amount and item.amount > 0 then
            arr[#arr+1] = string.format('{"id":%d,"amount":%d}', item.id, item.amount)
            n = n + 1
        end
    end
    _lastInvJson = "[" .. table.concat(arr, ",") .. "]"
end

-- ── Movement ──────────────────────────────────────────────────
local function MoveTo(tx, ty)
    if not IsSafe(tx, ty) then
        Log(string.format("BLOCKED (%d,%d)", tx, ty))
        return
    end
    local ok, me = pcall(GetLocal)
    if not ok or not me or not me.pos then return end
    if math.floor(me.pos.x/32) == tx and math.floor(me.pos.y/32) == ty then return end
    FindPath(tx, ty)
    Log(string.format("Move (%d,%d)", tx, ty))
end

local function DoUse()
    local ok, me = pcall(GetLocal)
    if not ok or not me or not me.pos then return end
    local px, py = math.floor(me.pos.x/32), math.floor(me.pos.y/32)
    SendPacketRaw(false, {type=3,state=0,value=18,px=px,py=py,x=px*32,y=py*32})
end

local function DoWarp(world)
    world = tostring(world or ""):upper()
    if world == "" then return end
    SendPacket(3, "action|join_request\nname|" .. world .. "\ninvitedWorld|0")
    Log("Warp " .. world)
end

-- ── Exec command ──────────────────────────────────────────────
local function ExecCmds(body)
    if not body or body == "" then return end
    for t, payload in body:gmatch('"type"%s*:%s*"([^"]+)".-"payload"%s*:%s*(%b{})') do
        if t == "move" then
            local x = tonumber(payload:match('"x"%s*:%s*(%-?%d+)'))
            local y = tonumber(payload:match('"y"%s*:%s*(%-?%d+)'))
            if x and y then pcall(MoveTo, x, y) end
        elseif t == "warp" then
            local w = payload:match('"world"%s*:%s*"([^"]*)"')
            if w and w ~= "" then pcall(DoWarp, w) end
        elseif t == "use" then
            pcall(DoUse)
        elseif t == "disconnect" then
            pcall(SendPacket, 3, "action|quit")
        elseif t == "modfly" then
            local on = payload:find('"on"%s*:%s*true') ~= nil
            pcall(ChangeValue, "[C] ModFly", on)
        end
    end
end

-- ── Status POST thread (5s = 12/menit) ───────────────────────
RunThread(function()
    while true do
        local ok, me = pcall(GetLocal)
        local px, py, lvl = 0, 0, 0
        if ok and type(me) == "table" and me.pos then
            px  = math.floor(me.pos.x/32)
            py  = math.floor(me.pos.y/32)
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

        -- Rebuild inventory tiap 3 tick (15 detik)
        _invTick = _invTick + 1
        if _invTick >= 3 then pcall(RebuildInv); _invTick = 0 end

        local tileJson = GetTileJson(px, py)
        local body = string.format(
            '{"x":%d,"y":%d,"world":"%s","status":"Online","level":%d,"gems":%d,"uptime":0,"botId":"%s","tileInfo":%s,"inventory":%s}',
            px, py, JsonEsc(world), lvl, gems, JsonEsc(GetBotId()), tileJson, _lastInvJson)

        SafeReq(ZAKIERA_URL .. "/api/status", "POST", body)
        Sleep(STATUS_INTERVAL)
    end
end)

-- ── Command GET thread (3s = 20/menit) ───────────────────────
RunThread(function()
    while true do
        local resp = SafeReq(ZAKIERA_URL .. "/api/command", "GET", nil)
        if resp then pcall(ExecCmds, resp) end
        Sleep(COMMAND_INTERVAL)
    end
end)

Log("Zakiera v6 aktif | status 5s | cmd 3s | rate ~32/mnt")
