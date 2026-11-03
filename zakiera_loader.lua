-- zakiera_loader.lua
-- Simpan file INI di Bothax
-- Path: Android/media/com.rtsoft.growtopia/scripts/zakiera_loader.lua

local URL = "https://raw.githubusercontent.com/AkhmadZaki14/zakiera/master/zakiera_bot.lua"

LogToConsole("`0[`6ZAKIERA`0] Downloading latest bot...")

local ok, resp = pcall(MakeRequest, URL, "GET", { ["User-Agent"] = "ZakieraLoader/1.0" }, "")
if not ok then
    LogToConsole("`4[ZAKIERA] Download GAGAL")
    return
end

local content = type(resp) == "table" and (resp.content or "") or tostring(resp or "")
if #content < 100 then
    LogToConsole("`4[ZAKIERA] Response kosong atau error")
    return
end

LogToConsole("`2[ZAKIERA] Download OK (" .. #content .. " bytes), loading...")

local fn, err = load(content)
if fn then
    fn()
    LogToConsole("`2[ZAKIERA] Bot aktif!")
else
    LogToConsole("`4[ZAKIERA] Load error: " .. tostring(err))
end
