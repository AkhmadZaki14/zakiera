-- zakiera_loader.lua
-- Simpan file INI di Bothax, jangan zakiera_bot.lua langsung
-- Path: Android/media/com.rtsoft.growtopia/scripts/zakiera_loader.lua
-- Setiap dirun: auto-download zakiera_bot.lua terbaru dari GitHub lalu eksekusi

local URL = "https://raw.githubusercontent.com/AkhmadZaki14/zakiera/master/zakiera_bot.lua"
local SAVE_PATH = "zakiera_bot.lua" -- disimpan di folder scripts Bothax

LogToConsole("`0[`6ZAKIERA`0] Downloading latest bot...")

local ok, resp = pcall(MakeRequest, URL, "GET", { ["User-Agent"] = "ZakieraLoader/1.0" }, "")
if not ok then
    LogToConsole("`4[ZAKIERA] Download GAGAL: MakeRequest error")
    return
end

local content = type(resp) == "table" and resp.content or resp
if type(content) ~= "string" or #content < 100 then
    LogToConsole("`4[ZAKIERA] Download GAGAL: response kosong atau error")
    return
end

-- Simpan ke file
local f = io.open(SAVE_PATH, "w")
if not f then
    LogToConsole("`4[ZAKIERA] Gagal tulis file: " .. SAVE_PATH)
    -- Fallback: langsung load dari memory tanpa simpan
    local fn, err = load(content)
    if fn then
        LogToConsole("`2[ZAKIERA] Load dari memory OK")
        fn()
    else
        LogToConsole("`4[ZAKIERA] Load error: " .. tostring(err))
    end
    return
end
f:write(content)
f:close()

LogToConsole("`2[ZAKIERA] Download OK, menjalankan bot...")

-- Load dan eksekusi
local fn, err = loadfile(SAVE_PATH)
if fn then
    fn()
    LogToConsole("`2[ZAKIERA] Bot aktif!")
else
    LogToConsole("`4[ZAKIERA] loadfile error: " .. tostring(err))
    -- Fallback load dari memory
    local fn2 = load(content)
    if fn2 then fn2() end
end
