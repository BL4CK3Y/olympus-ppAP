-- Olympus AP loader
local SCRIPT_URL = "https://raw.githubusercontent.com/BL4CK3Y/olympus-ppAP/main/olympus.lua"

local ok, err = pcall(function()
    local src = game:HttpGet(SCRIPT_URL)
    local fn, loadErr = loadstring(src)
    if not fn then error(loadErr) end
    fn()
end)

if not ok then
    warn("[Olympus] Load failed:", err)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Olympus",
            Text = "Load failed — check file name / repo",
            Duration = 5,
        })
    end)
end