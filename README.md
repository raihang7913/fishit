-- Auto Fishing Loader
print("🎣 Loading Auto Fishing Script...")

local success, result = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/raihang7913/fishit/refs/heads/main/pisit.lua")
end)

if success then
    print("✅ Script downloaded successfully!")
    local loadSuccess, loadError = pcall(function()
        loadstring(result)()
    end)
    
    if not loadSuccess then
        warn("❌ Error loading script:", loadError)
    end
else
    warn("❌ Failed to download script:", result)
end
