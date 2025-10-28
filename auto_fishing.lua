-- AUTO FISHING SCRIPT WITH MERCURY GUI
-- Universal auto fishing for Roblox fishing games

print("🎣 Loading Auto Fishing Script...")

-- Load Mercury Library
local Mercury = loadstring(game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua"))()

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Variables
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

-- Settings
local Settings = {
    AutoCast = false,
    PerfectCast = false,
    AutoReel = false,
    CastDelay = 0.5,
    ReelSpeed = 0.01,
    PerfectTiming = 0.1,
    AutoShake = false,
    ShakeSpeed = 0.05
}

-- State tracking
local isFishing = false
local isMinigameActive = false
local fishHooked = false
local currentRod = nil

-- Create GUI
local GUI = Mercury:Create{
    Name = "Auto Fishing",
    Size = UDim2.fromOffset(600, 400),
    Theme = Mercury.Themes.Dark,
    Link = "https://discord.gg/yourlink"
}

-- Main Tab
local MainTab = GUI:Tab{
    Name = "Main Features",
    Icon = "rbxassetid://8569322835"
}

-- Settings Tab
local SettingsTab = GUI:Tab{
    Name = "Settings",
    Icon = "rbxassetid://8569322835"
}

-- Helper Functions
local function findFishingRod()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    -- Check equipped tool first (priority)
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            print("🔍 Found equipped tool:", tool.Name)
            return tool
        end
    end
    
    -- Check backpack for fishing-related tools
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            -- Check if it's fishing-related by name
            if tool.Name:lower():find("rod") or tool.Name:lower():find("fish") or tool.Name:lower():find("pole") then
                print("🔍 Found fishing rod in backpack:", tool.Name)
                return tool
            end
        end
    end
    
    -- If no fishing-specific tool found, return any tool from backpack
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            print("🔍 Found tool in backpack:", tool.Name)
            return tool
        end
    end
    
    return nil
end

local function equipRod()
    local rod = findFishingRod()
    if rod and rod.Parent == LocalPlayer.Backpack then
        Humanoid:EquipTool(rod)
        wait(0.3)
        return true
    end
    return rod ~= nil
end

local function castRod()
    if not Settings.AutoCast then return end
    
    print("🎣 Attempting to cast...")
    
    -- Method 1: Fire ChargeFishingRod remote
    local chargeFishingRod = ReplicatedStorage:FindFirstChild("Packages", true)
    if chargeFishingRod then
        chargeFishingRod = chargeFishingRod:FindFirstChild("ChargeFishingRod", true)
        if chargeFishingRod and chargeFishingRod:IsA("RemoteFunction") then
            pcall(function()
                chargeFishingRod:InvokeServer()
                print("✅ ChargeFishingRod invoked!")
            end)
        end
    end
    
    -- Method 2: Click mobile fishing button (works for both mobile and PC)
    local mobileButton = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    if mobileButton then
        mobileButton = mobileButton:FindFirstChild("MobileFishingButton", true)
        if mobileButton and mobileButton:IsA("GuiButton") then
            pcall(function()
                for _, connection in pairs(getconnections(mobileButton.MouseButton1Click)) do
                    connection:Fire()
                end
                print("✅ Mobile fishing button clicked!")
            end)
        end
    end
    
    -- Method 3: Mouse click simulation as fallback
    pcall(function()
        mouse1press()
        wait(0.1)
        mouse1release()
        print("✅ Simulated mouse click")
    end)
    
    print("🎣 Cast rod!")
    isFishing = true
end

local function handlePerfectCast()
    if not Settings.PerfectCast then return end
    
    -- Look for fishing minigame
    local fishingGui = LocalPlayer.PlayerGui:FindFirstChild("Fishing")
    if not fishingGui then return end
    
    local minigame = fishingGui:FindFirstChild("Main", true)
    if minigame then
        minigame = minigame:FindFirstChild("Minigame", true)
        if minigame and minigame.Visible then
            print("🎮 Minigame detected!")
            
            -- Wait for perfect timing
            wait(Settings.PerfectTiming)
            
            -- Release click for perfect cast
            pcall(function()
                mouse1release()
                print("✨ Perfect cast attempted!")
            end)
            
            return
        end
    end
end

local function autoReel()
    if not Settings.AutoReel or not fishHooked then return end
    
    -- Spam click to reel in fish
    while fishHooked and Settings.AutoReel do
        pcall(function()
            mouse1click()
        end)
        
        -- Try to find reel remote
        for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                if remote.Name:lower():find("reel") or remote.Name:lower():find("catch") then
                    pcall(function()
                        if remote:IsA("RemoteEvent") then
                            remote:FireServer()
                        else
                            remote:InvokeServer()
                        end
                    end)
                end
            end
        end
        
        wait(Settings.ReelSpeed)
    end
end

local function autoShake()
    if not Settings.AutoShake then return end
    
    -- Shake/wiggle for some fishing games
    while fishHooked and Settings.AutoShake do
        -- Simulate mouse movement or key presses
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.A, false, game)
            wait(Settings.ShakeSpeed)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.A, false, game)
            
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.D, false, game)
            wait(Settings.ShakeSpeed)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game)
        end)
        
        wait(Settings.ShakeSpeed * 2)
    end
end

local function detectFishBite()
    -- Method 1: Check for fishing minigame visibility
    local fishingGui = LocalPlayer.PlayerGui:FindFirstChild("Fishing")
    if fishingGui then
        local minigame = fishingGui:FindFirstChild("Main", true)
        if minigame then
            minigame = minigame:FindFirstChild("Minigame", true)
            if minigame and minigame.Visible then
                return true
            end
        end
    end
    
    -- Method 2: Check for FishCaught event (listen to remote)
    local fishCaughtRemote = ReplicatedStorage:FindFirstChild("Packages", true)
    if fishCaughtRemote then
        fishCaughtRemote = fishCaughtRemote:FindFirstChild("FishCaught", true)
        if fishCaughtRemote then
            return true
        end
    end
    
    return false
end

-- Main Auto Fishing Loop
RunService.Heartbeat:Connect(function()
    if Settings.AutoCast and not isFishing then
        wait(Settings.CastDelay)
        castRod()
        
        -- Wait a bit then check for perfect cast minigame
        wait(0.5)
        handlePerfectCast()
    end
    
    -- Detect fish bite
    if isFishing and detectFishBite() then
        fishHooked = true
        isFishing = false
        print("🐟 Fish hooked!")
        
        -- Start auto reel
        spawn(autoReel)
        spawn(autoShake)
        
        -- Reset after some time
        wait(5)
        fishHooked = false
        isFishing = false
    end
end)

-- GUI Elements - Main Tab
MainTab:Toggle{
    Name = "Auto Cast",
    StartingState = false,
    Description = "Automatically cast fishing rod",
    Callback = function(state)
        Settings.AutoCast = state
        print("🎣 Auto Cast:", state and "ON" or "OFF")
    end
}

MainTab:Toggle{
    Name = "Perfect Cast",
    StartingState = false,
    Description = "Automatically get perfect cast timing",
    Callback = function(state)
        Settings.PerfectCast = state
        print("✨ Perfect Cast:", state and "ON" or "OFF")
    end
}

MainTab:Toggle{
    Name = "Auto Reel",
    StartingState = false,
    Description = "Automatically spam click to reel in fish",
    Callback = function(state)
        Settings.AutoReel = state
        print("🎯 Auto Reel:", state and "ON" or "OFF")
    end
}

MainTab:Toggle{
    Name = "Auto Shake",
    StartingState = false,
    Description = "Automatically shake/wiggle while reeling",
    Callback = function(state)
        Settings.AutoShake = state
        print("🌊 Auto Shake:", state and "ON" or "OFF")
    end
}

MainTab:Button{
    Name = "Cast Now",
    Description = "Manually cast fishing rod once",
    Callback = function()
        castRod()
    end
}

MainTab:Button{
    Name = "Find Fishing Rod",
    Description = "Search for fishing rod in inventory",
    Callback = function()
        local rod = findFishingRod()
        if rod then
            GUI:Notification{
                Title = "Rod Found",
                Text = "Found: " .. rod.Name,
                Duration = 3
            }
        else
            GUI:Notification{
                Title = "No Rod",
                Text = "No fishing rod found in inventory!",
                Duration = 3
            }
        end
    end
}

MainTab:Button{
    Name = "Scan All Tools",
    Description = "List all tools in character and backpack",
    Callback = function()
        print("========== TOOL SCAN ==========")
        
        -- Scan equipped tools
        print("\n📦 EQUIPPED TOOLS:")
        local equippedCount = 0
        if LocalPlayer.Character then
            for _, item in pairs(LocalPlayer.Character:GetChildren()) do
                if item:IsA("Tool") then
                    print("  ✅ " .. item.Name .. " (Class: " .. item.ClassName .. ")")
                    equippedCount = equippedCount + 1
                end
            end
        end
        if equippedCount == 0 then
            print("  ❌ No equipped tools")
        end
        
        -- Scan backpack
        print("\n🎒 BACKPACK TOOLS:")
        local backpackCount = 0
        for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
            if item:IsA("Tool") then
                print("  ✅ " .. item.Name .. " (Class: " .. item.ClassName .. ")")
                backpackCount = backpackCount + 1
            end
        end
        if backpackCount == 0 then
            print("  ❌ No tools in backpack")
        end
        
        print("\n📊 Total: " .. (equippedCount + backpackCount) .. " tools found")
        print("===============================\n")
        
        GUI:Notification{
            Title = "Tool Scan Complete",
            Text = "Found " .. (equippedCount + backpackCount) .. " tools. Check console!",
            Duration = 3
        }
    end
}

MainTab:Button{
    Name = "Scan Remotes",
    Description = "Find all RemoteEvents and RemoteFunctions",
    Callback = function()
        print("========== REMOTE SCAN ==========")
        
        local output = "========== REMOTE SCAN ==========\n\n"
        local remoteCount = 0
        
        for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                local line = "🌐 " .. remote:GetFullName() .. " (" .. remote.ClassName .. ")\n"
                print(line)
                output = output .. line
                remoteCount = remoteCount + 1
            end
        end
        
        local summary = "\n📊 Total: " .. remoteCount .. " remotes found\n=================================\n"
        print(summary)
        output = output .. summary
        
        -- Save to clipboard (if supported by executor)
        pcall(function()
            setclipboard(output)
            print("✅ Output copied to clipboard!")
        end)
        
        -- Also save to file
        writefile("fishing_remotes_scan.txt", output)
        print("✅ Output saved to: fishing_remotes_scan.txt")
        
        GUI:Notification{
            Title = "Remote Scan Complete",
            Text = "Found " .. remoteCount .. " remotes. Saved to file!",
            Duration = 3
        }
    end
}

MainTab:Button{
    Name = "Scan UI Elements",
    Description = "Find fishing-related UI elements",
    Callback = function()
        print("========== UI SCAN ==========")
        
        local output = "========== UI SCAN ==========\n\n"
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        local uiCount = 0
        
        for _, gui in pairs(playerGui:GetDescendants()) do
            local name = gui.Name:lower()
            -- Look for fishing-related UI
            if name:find("fish") or name:find("rod") or name:find("cast") or name:find("reel") or name:find("catch") or name:find("bite") then
                local line = "🎨 " .. gui:GetFullName() .. " (" .. gui.ClassName .. ")\n"
                print(line)
                output = output .. line
                
                if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                    local buttonInfo = "   └─ 🔘 BUTTON - Can be clicked!\n"
                    print(buttonInfo)
                    output = output .. buttonInfo
                end
                uiCount = uiCount + 1
            end
        end
        
        local summary = "\n📊 Total: " .. uiCount .. " fishing UI elements found\n=============================\n"
        print(summary)
        output = output .. summary
        
        -- Save to clipboard (if supported by executor)
        pcall(function()
            setclipboard(output)
            print("✅ Output copied to clipboard!")
        end)
        
        -- Also save to file
        writefile("fishing_ui_scan.txt", output)
        print("✅ Output saved to: fishing_ui_scan.txt")
        
        GUI:Notification{
            Title = "UI Scan Complete",
            Text = "Found " .. uiCount .. " UI elements. Saved to file!",
            Duration = 3
        }
    end
}

-- GUI Elements - Settings Tab
SettingsTab:Slider{
    Name = "Cast Delay",
    Default = 0.5,
    Min = 0.1,
    Max = 5,
    Callback = function(value)
        Settings.CastDelay = value
        print("⏱️ Cast Delay:", value)
    end
}

SettingsTab:Slider{
    Name = "Reel Speed",
    Default = 0.01,
    Min = 0.001,
    Max = 0.1,
    Callback = function(value)
        Settings.ReelSpeed = value
        print("🎯 Reel Speed:", value)
    end
}

SettingsTab:Slider{
    Name = "Perfect Timing",
    Default = 0.1,
    Min = 0.01,
    Max = 1,
    Callback = function(value)
        Settings.PerfectTiming = value
        print("✨ Perfect Timing:", value)
    end
}

SettingsTab:Slider{
    Name = "Shake Speed",
    Default = 0.05,
    Min = 0.01,
    Max = 0.2,
    Callback = function(value)
        Settings.ShakeSpeed = value
        print("🌊 Shake Speed:", value)
    end
}

-- Credits
GUI:Credit{
    Name = "Script Creator",
    Description = "Auto Fishing Script",
    Discord = "Your Discord"
}

-- Notifications
GUI:Notification{
    Title = "Auto Fishing Loaded",
    Text = "Script loaded successfully! Toggle features in the Main tab.",
    Duration = 5
}

print("✅ Auto Fishing Script loaded successfully!")
print("🎣 Features: Auto Cast, Perfect Cast, Auto Reel, Auto Shake")
print("⚙️ Configure settings in the Settings tab")
