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
    CastDelay = 0.6,      -- Durasi mouse hold saat cast (hold duration)
    ReelTiming = 0.6,     -- Delay sebelum klik reel
    HookTiming = 0.1      -- Interval spam click untuk hook minigame
}

-- State tracking
local isFishing = false
local isMinigameActive = false
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
    
    -- Method 1: Fire ChargeFishingRod remote directly (most reliable)
    local packages = ReplicatedStorage:FindFirstChild("Packages", true)
    if packages then
        local chargeFishingRod = packages:FindFirstChild("ChargeFishingRod", true)
        if chargeFishingRod and chargeFishingRod:IsA("RemoteFunction") then
            local success = pcall(function()
                chargeFishingRod:InvokeServer()
                print("✅ ChargeFishingRod invoked!")
            end)
            if success then
                isFishing = true
                print("🎣 Cast rod!")
                return
            end
        end
    end
    
    -- Method 2: Hold mouse for 0.6 seconds then release (charge casting)
    pcall(function()
        mouse1press()
        print("🖱️ Holding mouse for 0.6 seconds...")
        task.wait(0.6)
        mouse1release()
        print("✅ Mouse released - cast!")
    end)
    
    print("🎣 Cast rod!")
    isFishing = true
end

local reelMinigameDetectedTime = 0
local reelDone = false
local lastHookClickTime = 0
local wasMinigameActive = false
local minigameActiveFromRemote = false -- Track if minigame triggered from remote

-- Listen to RequestFishingMinigameStarted (UNIVERSAL - no hook needed!)
local function setupRemoteListener()
    local packages = ReplicatedStorage:FindFirstChild("Packages", true)
    if packages then
        -- Method 1: Listen to FishingMinigameChanged event
        local minigameChangedEvent = packages:FindFirstChild("FishingMinigameChanged", true)
        if minigameChangedEvent and minigameChangedEvent:IsA("RemoteEvent") then
            minigameChangedEvent.OnClientEvent:Connect(function(minigameType)
                minigameActiveFromRemote = true
                print("✅ FishingMinigameChanged event fired - Type:", tostring(minigameType))
            end)
            print("🎣 Listening to FishingMinigameChanged event")
        end
        
        -- Method 2: Intercept RequestFishingMinigameStarted RemoteFunction (NO HOOK!)
        local minigameRemote = packages:FindFirstChild("RequestFishingMinigameStarted", true)
        if minigameRemote and minigameRemote:IsA("RemoteFunction") then
            -- Store original function
            local originalFunc = minigameRemote.OnClientInvoke
            
            -- Wrap it to detect when it's called
            minigameRemote.OnClientInvoke = function(...)
                minigameActiveFromRemote = true
                print("✅ RequestFishingMinigameStarted detected!")
                
                -- Call original if it exists
                if originalFunc then
                    return originalFunc(...)
                end
            end
            print("🎣 Intercepting RequestFishingMinigameStarted (universal)")
        end
    end
end

-- Setup listener on load
task.spawn(setupRemoteListener)

local function handleAutoReel()
    if not Settings.AutoCast then 
        -- Reset everything when auto cast is off
        reelMinigameDetectedTime = 0
        reelDone = false
        lastHookClickTime = 0
        wasMinigameActive = false
        minigameActiveFromRemote = false
        return 
    end
    
    -- Look for fishing minigame with MORE SPECIFIC checks
    local fishingGui = LocalPlayer.PlayerGui:FindFirstChild("Fishing")
    if not fishingGui then 
        -- Reset immediately if GUI not found
        reelMinigameDetectedTime = 0
        reelDone = false
        lastHookClickTime = 0
        wasMinigameActive = false
        minigameActiveFromRemote = false
        return 
    end
    
    local minigameDisplay = fishingGui:FindFirstChild("Main", true)
    if not minigameDisplay then 
        -- Reset immediately if display not found
        reelMinigameDetectedTime = 0
        reelDone = false
        lastHookClickTime = 0
        wasMinigameActive = false
        minigameActiveFromRemote = false
        return 
    end
    
    local minigame = minigameDisplay:FindFirstChild("Minigame", true)
    
    -- CRITICAL FIX: Only proceed if minigame exists AND is visible
    if not minigame or not minigame.Visible then
        -- Minigame closed or not visible - IMMEDIATELY reset everything and STOP
        reelMinigameDetectedTime = 0
        reelDone = false
        lastHookClickTime = 0
        wasMinigameActive = false
        minigameActiveFromRemote = false
        return -- EXIT FUNCTION - Don't click anything!
    end
    
    -- ADDITIONAL GUARD: Check if minigame container has Size (is rendered)
    if minigame:IsA("GuiObject") and minigame.AbsoluteSize.X == 0 and minigame.AbsoluteSize.Y == 0 then
        -- Minigame has no size - not actually visible
        reelMinigameDetectedTime = 0
        reelDone = false
        lastHookClickTime = 0
        wasMinigameActive = false
        minigameActiveFromRemote = false
        return
    end
    
    -- Minigame is visible - proceed with handling
    wasMinigameActive = true
    
    -- Detect which minigame is active (MUTUAL EXCLUSIVE - only one can be true)
    local isReelMinigame = false
    local isHookMinigame = false
    
    -- Check for reel minigame (appears right after cast, has bar/indicator)
    local indicator = minigame:FindFirstChild("Indicator", true) or minigame:FindFirstChild("Bar", true)
    if indicator and indicator:IsA("GuiObject") and indicator.Visible then
        isReelMinigame = true
    end
    
    -- Check for hook minigame (appears when fish bites, usually has shake/pull indicator)
    local shake = minigame:FindFirstChild("Shake", true) or minigame:FindFirstChild("Pull", true)
    if shake and shake:IsA("GuiObject") and shake.Visible then
        isHookMinigame = true
    end
    
    -- If we can't detect specifically, assume it's hook if not reel
    if not isReelMinigame and not isHookMinigame then
        isHookMinigame = true
    end
    
    -- CRITICAL FIX: Make detection mutual exclusive - reel takes priority
    if isReelMinigame and isHookMinigame then
        isHookMinigame = false -- Prioritize reel detection
    end
    
    -- Handle Reel Minigame ONLY - click once after delay
    if isReelMinigame then
        -- Reset hook tracking when reel is active
        lastHookClickTime = 0
        
        if reelMinigameDetectedTime == 0 then
            reelMinigameDetectedTime = tick()
            reelDone = false
        end
        
        if not reelDone and tick() - reelMinigameDetectedTime >= Settings.ReelTiming then
            -- Single click for reel (Virtual Input)
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                print("✅ Reel clicked!")
            end)
            
            reelDone = true
        end
    -- Handle Hook Minigame ONLY - spam with interval (ONLY runs if NOT reel)
    elseif isHookMinigame then
        -- Reset reel tracking when hook is active
        reelMinigameDetectedTime = 0
        reelDone = false
        
        local currentTime = tick()
        
        -- SIMPLIFIED GUARD: GUI visibility + has size (NO remote dependency!)
        local guardPassed = false
        
        if minigame and minigame.Visible and minigame:IsA("GuiObject") then
            -- Check if minigame has actual size (is rendered)
            local hasSize = minigame.AbsoluteSize.X > 0 and minigame.AbsoluteSize.Y > 0
            
            if hasSize then
                guardPassed = true
            end
        end
        
        -- Spam click if guard passes
        if guardPassed then
            -- Click every Settings.HookTiming seconds - INDEPENDENT from CastDelay!
            if currentTime - lastHookClickTime >= Settings.HookTiming then
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.01) -- Very short delay, just for press/release
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end)
                
                lastHookClickTime = currentTime
                print("🎯 Hook click @ " .. Settings.HookTiming .. "s interval")
            end
        end
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
local lastCastTime = 0
local minCastInterval = 2 -- Minimum 2 seconds between casts

RunService.Heartbeat:Connect(function()
    if Settings.AutoCast then
        local currentTime = tick()
        
        -- ULTRA-SPECIFIC minigame detection (don't cast during minigame)
        local isMinigameActive = false
        local fishingGui = LocalPlayer.PlayerGui:FindFirstChild("Fishing")
        
        if fishingGui then
            local minigameDisplay = fishingGui:FindFirstChild("Main", true)
            if minigameDisplay and minigameDisplay.Visible then
                local minigame = minigameDisplay:FindFirstChild("Minigame", true)
                
                -- Check if minigame is truly active (visible + has size + has active elements)
                if minigame and minigame.Visible and minigame:IsA("GuiObject") then
                    -- Check if has actual size (is rendered)
                    if minigame.AbsoluteSize.X > 0 and minigame.AbsoluteSize.Y > 0 then
                        -- Check if has any active minigame elements
                        local hasActiveElement = false
                        local elementsToCheck = {
                            minigame:FindFirstChild("Indicator", true),
                            minigame:FindFirstChild("Bar", true),
                            minigame:FindFirstChild("Shake", true),
                            minigame:FindFirstChild("Pull", true),
                            minigame:FindFirstChild("Fish", true),
                            minigame:FindFirstChild("Hook", true),
                            minigame:FindFirstChild("Mover", true)
                        }
                        
                        for _, element in ipairs(elementsToCheck) do
                            if element and element:IsA("GuiObject") and element.Visible then
                                hasActiveElement = true
                                break
                            end
                        end
                        
                        if hasActiveElement then
                            isMinigameActive = true
                        end
                    end
                end
            end
        end
        
        -- ONLY cast if: minigame is NOT active AND minimum interval has passed
        if not isMinigameActive and currentTime - lastCastTime >= minCastInterval then
            lastCastTime = currentTime
            
            -- DON'T reset remote flag here - let it stay active during minigame
            -- minigameActiveFromRemote will only reset when minigame closes
            
            -- Method 1: Fire ChargeFishingRod remote (prioritize this)
            local packages = ReplicatedStorage:FindFirstChild("Packages", true)
            if packages then
                local chargeFishingRod = packages:FindFirstChild("ChargeFishingRod", true)
                if chargeFishingRod and chargeFishingRod:IsA("RemoteFunction") then
                    pcall(function()
                        chargeFishingRod:InvokeServer()
                    end)
                end
            end
            
            -- Method 2: Hold mouse for Settings.CastDelay seconds then release (Virtual Input)
            -- This runs ONCE per minCastInterval, NOT spammed
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                print("🖱️ Holding mouse for", Settings.CastDelay, "seconds...")
                task.wait(Settings.CastDelay)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                print("🎣 Cast executed (mouse press hold)")
            end)
        end
    end
    
    -- Check for minigames every frame (instant/aggressive)
    if Settings.AutoCast then
        handleAutoReel()
    end
end)

-- GUI Elements - Main Tab
MainTab:Toggle{
    Name = "Auto Cast & Reel",
    StartingState = false,
    Description = "Auto cast, auto reel, and auto hook with timing",
    Callback = function(state)
        Settings.AutoCast = state
        
        -- Reset all states when toggling
        if not state then
            reelMinigameDetectedTime = 0
            reelDone = false
            lastHookClickTime = 0
            wasMinigameActive = false
        end
        
        print("🎣 Auto Cast:", state and "ON" or "OFF")
        
        GUI:Notification{
            Title = state and "Auto Fishing ON" or "Auto Fishing OFF",
            Text = state and "Auto fishing with realistic timing" or "Stopped fishing",
            Duration = 2
        }
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
    Name = "Sell All Fish",
    Description = "Instantly sell all fish in inventory",
    Callback = function()
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("💰 [SELL] Selling all fish...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        -- Find and fire all sell-related remotes
        local packages = ReplicatedStorage:FindFirstChild("Packages", true)
        if not packages then
            print("❌ Packages not found")
            GUI:Notification{
                Title = "Sell Failed",
                Text = "Could not find Packages folder",
                Duration = 3
            }
            return
        end
        
        local soldCount = 0
        
        -- Method 1: Fire SellAllFish remote
        for _, obj in pairs(packages:GetDescendants()) do
            if obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent") then
                local name = obj.Name:lower()
                if name:find("sell") then
                    pcall(function()
                        if obj:IsA("RemoteFunction") then
                            obj:InvokeServer()
                            print("✅ Invoked RemoteFunction:", obj.Name)
                        else
                            obj:FireServer()
                            print("✅ Fired RemoteEvent:", obj.Name)
                        end
                        soldCount = soldCount + 1
                    end)
                end
            end
        end
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("💰 Fired", soldCount, "sell remotes")
        
        GUI:Notification{
            Title = "Sell All Fish",
            Text = "Fired " .. soldCount .. " sell remotes!",
            Duration = 3
        }
    end
}

-- GUI Elements - Settings Tab
SettingsTab:Textbox{
    Name = "Cast Delay",
    Placeholder = "0.6",
    Description = "Mouse hold duration when casting (seconds)",
    Callback = function(text)
        local value = tonumber(text)
        if value and value > 0 then
            Settings.CastDelay = value
            print("⏱️ Cast Delay:", value)
            GUI:Notification{
                Title = "Cast Delay Updated",
                Text = "Mouse hold " .. value .. " seconds",
                Duration = 2
            }
        else
            GUI:Notification{
                Title = "Invalid Input",
                Text = "Please enter a valid number greater than 0",
                Duration = 2
            }
        end
    end
}

SettingsTab:Textbox{
    Name = "Reel Timing",
    Placeholder = "0.6",
    Description = "Delay before reeling (tunggu sebelum klik reel)",
    Callback = function(text)
        local value = tonumber(text)
        if value and value > 0 then
            Settings.ReelTiming = value
            print("🎣 Reel Timing:", value)
            GUI:Notification{
                Title = "Reel Timing Updated",
                Text = "Set to " .. value .. " seconds",
                Duration = 2
            }
        else
            GUI:Notification{
                Title = "Invalid Input",
                Text = "Please enter a valid number greater than 0",
                Duration = 2
            }
        end
    end
}

SettingsTab:Textbox{
    Name = "Hook Timing",
    Placeholder = "0.1",
    Description = "Click interval for hook minigame (spam speed)",
    Callback = function(text)
        local value = tonumber(text)
        if value and value > 0 then
            Settings.HookTiming = value
            print("✨ Hook Timing:", value)
            GUI:Notification{
                Title = "Hook Timing Updated",
                Text = "Set to " .. value .. " seconds (spam interval)",
                Duration = 2
            }
        else
            GUI:Notification{
                Title = "Invalid Input",
                Text = "Please enter a valid number greater than 0",
                Duration = 2
            }
        end
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
print("🎣 Features: Auto Cast, Auto Reel, and Auto Hook")
print("⚙️ Configure settings in the Settings tab")
