-- ============================================================
--  ZAKIERA BOT v4 — Standalone Lua Script (Bothax Android)
--  Load via zakiera_loader.lua
--  API List required: io, MakeRequest
-- ============================================================

local ZAKIERA_URL = "https://43dc-118-99-118-190.ngrok-free.app"
local BOT_ID      = GetLocal and GetLocal() and GetLocal().name or "bot1"

local HEADERS = {
    ["Content-Type"]               = "application/json",
    ["ngrok-skip-browser-warning"] = "1",
    ["User-Agent"]                 = "ZakieraBot/1.0",
    ["x-bot-id"]                   = BOT_ID,
}

local function Log(msg)
    LogToConsole("`0[`6ZAKIERA`0] " .. tostring(msg))
end

local function JsonEsc(s)
    s = tostring(s or "")
    s = s:gsub("\\","\\\\"):gsub('"','\\"')
    s = s:gsub("\r","\\r"):gsub("\n","\\n"):gsub("\t","\\t")
    return s
end

-- ── Modfly ON saat start ──────────────────────────────────────
pcall(ChangeValue, "[C] ModFly", true)
Log("ModFly ON")

-- ── Tile safety check ─────────────────────────────────────────
local function IsSafe(tx, ty)
    if CheckPath then
        local ok, r = pcall(CheckPath, tx, ty)
        if ok then return r == true end
    end
    local t = GetTile and GetTile(tx, ty)
    if not t then return false end
    if t.collidable then return false end
    return true
end

-- Build tile info 5x5 sekitar posisi bot
local function BuildTileInfo(cx, cy)
    local arr = {}
    for dy = -2, 2 do
        for dx = -2, 2 do
            if not (dx == 0 and dy == 0) then
                local tx, ty = cx+dx, cy+dy
                local safe = IsSafe(tx, ty)
                arr[#arr+1] = string.format('{"x":%d,"y":%d,"safe":%s}', tx, ty, safe and "true" or "false")
            end
        end
    end
    return "[" .. table.concat(arr, ",") .. "]"
end

-- ── Movement ──────────────────────────────────────────────────
local function MoveTo(tx, ty)
    if not IsSafe(tx, ty) then
        Log(string.format("BLOCKED (%d,%d) tidak bisa dilewati", tx, ty))
        return
    end
    local me = GetLocal and GetLocal()
    if not me or not me.pos then return end
    if math.floor(me.pos.x/32) == tx and math.floor(me.pos.y/32) == ty then return end
    Log(string.format("FindPath (%d,%d)", tx, ty))
    FindPath(tx, ty)
end

local function DoUse()
    local me = GetLocal and GetLocal()
    if not me or not me.pos then return end
    local px = math.floor(me.pos.x/32)
    local py = math.floor(me.pos.y/32)
    SendPacketRaw(false, {type=3,state=0,value=18,px=px,py=py,x=px*32,y=py*32})
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
    local tileInfo = pcall and BuildTileInfo(px, py) or "[]"
    local body = string.format(
        '{"x":%d,"y":%d,"world":"%s","status":"Online","level":%d,"gems":%d,"uptime":0,"botId":"%s","tileInfo":%s}',
        px, py, JsonEsc(world), lvl, gems, JsonEsc(BOT_ID), tileInfo)
    pcall(MakeRequest, ZAKIERA_URL .. "/api/status", "POST", HEADERS, body)
end

-- ── GET & exec command ────────────────────────────────────────
local function FetchAndExec()
    local ok, resp = pcall(MakeRequest, ZAKIERA_URL .. "/api/command", "GET", HEADERS, "")
    if not ok then return end
    local body = type(resp) == "table" and (resp.content or "") or tostring(resp or "")
    if body == "" or body:find("<!DOCTYPE", 1, true) then return end

    -- move: cari type=move lalu x,y dari payload
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
        end
    end
end

-- ── Main ──────────────────────────────────────────────────────
-- Re-resolve BOT_ID saat sudah in-game
RunThread(function()
    Sleep(2000)
    local me = GetLocal and GetLocal()
    if me and me.name then
        BOT_ID = me.name
        HEADERS["x-bot-id"] = BOT_ID
        Log("Bot ID: " .. BOT_ID)
    end
end)

Log("Zakiera v4 aktif → " .. ZAKIERA_URL)

RunThread(function()
    while true do pcall(PostStatus); Sleep(300) end
end)

RunThread(function()
    while true do pcall(FetchAndExec); Sleep(300) end
end)
