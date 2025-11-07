-- AUTO FISHING SCRIPT WITH MERCURY GUI
-- Universal auto fishing for Roblox fishing games

print("🎣 Loading Auto Fishing Script...")

-- Check executor compatibility
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔍 Checking executor compatibility...")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

local hasHookMetamethod = hookmetamethod ~= nil
local hasGetNamecallMethod = getnamecallmethod ~= nil
local hasMouse1 = mouse1press ~= nil and mouse1release ~= nil

print("✓ hookmetamethod:", hasHookMetamethod and "AVAILABLE" or "❌ NOT AVAILABLE")
print("✓ getnamecallmethod:", hasGetNamecallMethod and "AVAILABLE" or "❌ NOT AVAILABLE")
print("✓ mouse1press/release:", hasMouse1 and "AVAILABLE" or "❌ NOT AVAILABLE")

if not hasHookMetamethod then
    warn("⚠️ WARNING: hookmetamethod not available - Instant Fishing will be disabled!")
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Load Mercury Library
local Mercury
local GUI
local useFallbackGUI = false

local mercurySuccess, mercuryError = pcall(function()
    Mercury = loadstring(game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua"))()
end)

if not mercurySuccess then
    warn("⚠️ Mercury GUI failed to load, using fallback mobile-friendly GUI")
    warn("Error:", tostring(mercuryError))
    useFallbackGUI = true
else
    print("✅ Mercury GUI loaded successfully!")
end

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
    InstantFishing = false, -- Hook metamethod untuk instant fishing
    AutoPerfect = true,    -- Auto perfect catch (detect perfect zone)
    AutoQuest = false,     -- Auto complete quest
    CatchDelay = 0.3,     -- Delay sebelum ikan tertangkap (seconds)
    CastDelay = 0.6,      -- Durasi mouse hold saat cast (hold duration)
    ReelTiming = 0.6,     -- Delay sebelum klik reel
    HookTiming = 0.1,     -- Interval spam click untuk hook minigame
    PerfectThreshold = 10 -- Pixel threshold untuk perfect zone (semakin kecil = lebih perfect)
}

-- Instant Fishing Variables
local oldNamecall
local oldIndex
local instantFishingActive = false
local catchDelayActive = false -- Track if catch delay is in progress

-- State tracking
local isFishing = false
local isMinigameActive = false
local currentRod = nil

-- ═══════════════════════════════════════════════════════════════
-- MOBILE-FRIENDLY FALLBACK GUI
-- ═══════════════════════════════════════════════════════════════

local function createFallbackGUI()
    print("🎨 Creating mobile-friendly fallback GUI...")
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoFishingGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 350, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -225)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    -- Add corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.BorderSizePixel = 0
    title.Text = "🎣 Auto Fishing (Mobile)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = title
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.white
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 5)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Content Frame
    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -20, 1, -60)
    content.Position = UDim2.new(0, 10, 0, 50)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 6
    content.CanvasSize = UDim2.new(0, 0, 0, 600)
    content.Parent = mainFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content
    
    -- Helper function to create toggle
    local yPos = 0
    local function createToggle(name, description, defaultState, callback)
        local toggle = Instance.new("Frame")
        toggle.Size = UDim2.new(1, -10, 0, 60)
        toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        toggle.BorderSizePixel = 0
        toggle.Parent = content
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 8)
        toggleCorner.Parent = toggle
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -70, 0, 25)
        label.Position = UDim2.new(0, 10, 0, 5)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.white
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = toggle
        
        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -70, 0, 20)
        desc.Position = UDim2.new(0, 10, 0, 30)
        desc.BackgroundTransparency = 1
        desc.Text = description
        desc.TextColor3 = Color3.fromRGB(180, 180, 180)
        desc.TextSize = 10
        desc.Font = Enum.Font.Gotham
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextWrapped = true
        desc.Parent = toggle
        
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 50, 0, 30)
        button.Position = UDim2.new(1, -60, 0.5, -15)
        button.BackgroundColor3 = defaultState and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(100, 100, 100)
        button.Text = defaultState and "ON" or "OFF"
        button.TextColor3 = Color3.white
        button.TextSize = 12
        button.Font = Enum.Font.GothamBold
        button.Parent = toggle
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = button
        
        local state = defaultState
        button.MouseButton1Click:Connect(function()
            state = not state
            button.BackgroundColor3 = state and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(100, 100, 100)
            button.Text = state and "ON" or "OFF"
            callback(state)
        end)
        
        yPos = yPos + 70
        return toggle
    end
    
    -- Helper function to create button
    local function createButton(name, description, callback)
        local btnFrame = Instance.new("Frame")
        btnFrame.Size = UDim2.new(1, -10, 0, 50)
        btnFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        btnFrame.BorderSizePixel = 0
        btnFrame.Parent = content
        
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 8)
        frameCorner.Parent = btnFrame
        
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -20, 1, -10)
        button.Position = UDim2.new(0, 10, 0, 5)
        button.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
        button.Text = name
        button.TextColor3 = Color3.white
        button.TextSize = 14
        button.Font = Enum.Font.GothamBold
        button.Parent = btnFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = button
        
        button.MouseButton1Click:Connect(callback)
        
        yPos = yPos + 60
        return btnFrame
    end
    
    -- Helper function to create textbox
    local function createTextbox(name, placeholder, description, callback)
        local boxFrame = Instance.new("Frame")
        boxFrame.Size = UDim2.new(1, -10, 0, 70)
        boxFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        boxFrame.BorderSizePixel = 0
        boxFrame.Parent = content
        
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 8)
        frameCorner.Parent = boxFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 0, 20)
        label.Position = UDim2.new(0, 10, 0, 5)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.white
        label.TextSize = 12
        label.Font = Enum.Font.GothamBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = boxFrame
        
        local textbox = Instance.new("TextBox")
        textbox.Size = UDim2.new(1, -20, 0, 30)
        textbox.Position = UDim2.new(0, 10, 0, 30)
        textbox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        textbox.PlaceholderText = placeholder
        textbox.Text = ""
        textbox.TextColor3 = Color3.white
        textbox.TextSize = 12
        textbox.Font = Enum.Font.Gotham
        textbox.ClearTextOnFocus = false
        textbox.Parent = boxFrame
        
        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 5)
        boxCorner.Parent = textbox
        
        textbox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                callback(textbox.Text)
            end
        end)
        
        yPos = yPos + 80
        return boxFrame
    end
    
    -- Create notification function
    local function showNotification(title, text, duration)
        local notif = Instance.new("Frame")
        notif.Size = UDim2.new(0, 300, 0, 80)
        notif.Position = UDim2.new(1, -320, 0, 20)
        notif.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        notif.BorderSizePixel = 0
        notif.Parent = screenGui
        
        local notifCorner = Instance.new("UICorner")
        notifCorner.CornerRadius = UDim.new(0, 8)
        notifCorner.Parent = notif
        
        local notifTitle = Instance.new("TextLabel")
        notifTitle.Size = UDim2.new(1, -20, 0, 25)
        notifTitle.Position = UDim2.new(0, 10, 0, 5)
        notifTitle.BackgroundTransparency = 1
        notifTitle.Text = title
        notifTitle.TextColor3 = Color3.white
        notifTitle.TextSize = 14
        notifTitle.Font = Enum.Font.GothamBold
        notifTitle.TextXAlignment = Enum.TextXAlignment.Left
        notifTitle.Parent = notif
        
        local notifText = Instance.new("TextLabel")
        notifText.Size = UDim2.new(1, -20, 0, 40)
        notifText.Position = UDim2.new(0, 10, 0, 30)
        notifText.BackgroundTransparency = 1
        notifText.Text = text
        notifText.TextColor3 = Color3.fromRGB(200, 200, 200)
        notifText.TextSize = 11
        notifText.Font = Enum.Font.Gotham
        notifText.TextXAlignment = Enum.TextXAlignment.Left
        notifText.TextWrapped = true
        notifText.Parent = notif
        
        task.delay(duration or 3, function()
            notif:TweenPosition(UDim2.new(1, 20, 0, 20), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.5, true, function()
                notif:Destroy()
            end)
        end)
    end
    
    screenGui.Parent = game:GetService("CoreGui")
    
    return {
        Toggle = createToggle,
        Button = createButton,
        Textbox = createTextbox,
        Notification = showNotification
    }
end

-- Create GUI
if useFallbackGUI then
    GUI = createFallbackGUI()
    print("✅ Fallback mobile GUI created!")
else
    GUI = Mercury:Create{
        Name = "Auto Fishing",
        Size = UDim2.fromOffset(600, 400),
        Theme = Mercury.Themes.Dark,
        Link = "https://discord.gg/yourlink"
    }
end

-- Main Tab
local MainTab
local SettingsTab

if not useFallbackGUI then
    MainTab = GUI:Tab{
        Name = "Main Features",
        Icon = "rbxassetid://8569322835"
    }
    
    -- Settings Tab
    SettingsTab = GUI:Tab{
        Name = "Settings",
        Icon = "rbxassetid://8569322835"
    }
end

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
local perfectZoneDetected = false -- Track if we're in perfect zone

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

-- ═══════════════════════════════════════════════════════════════
-- AUTO QUEST COMPLETION - FORCE COMPLETE WITHOUT CATCHING FISH
-- ═══════════════════════════════════════════════════════════════

local function forceCompleteQuest()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🎯 [QUEST] Force completing all quests...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local packages = ReplicatedStorage:FindFirstChild("Packages", true)
    if not packages then
        warn("❌ Packages not found!")
        return 0
    end
    
    local completedCount = 0
    
    -- Scan all remotes
    for _, remote in pairs(packages:GetDescendants()) do
        if remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent") then
            local remoteName = remote.Name:lower()
            
            -- Pattern 1: Quest completion remotes
            if remoteName:find("quest") and (remoteName:find("complete") or remoteName:find("finish") or remoteName:find("claim")) then
                pcall(function()
                    if remote:IsA("RemoteFunction") then
                        -- Try multiple argument patterns
                        local results = {
                            remote:InvokeServer(),
                            remote:InvokeServer(true),
                            remote:InvokeServer("SecretFish"),
                            remote:InvokeServer({completed = true}),
                            remote:InvokeServer({quest = "SecretFish", completed = true})
                        }
                        print("✅ [QUEST] Invoked:", remote.Name)
                    else
                        remote:FireServer()
                        remote:FireServer(true)
                        remote:FireServer("SecretFish")
                        remote:FireServer({completed = true})
                        print("✅ [QUEST] Fired:", remote.Name)
                    end
                    completedCount = completedCount + 1
                end)
            end
            
            -- Pattern 2: Quest progress remotes - set to max
            if remoteName:find("quest") and remoteName:find("progress") then
                pcall(function()
                    if remote:IsA("RemoteFunction") then
                        remote:InvokeServer(999)
                        remote:InvokeServer({progress = 999, completed = true})
                    else
                        remote:FireServer(999)
                        remote:FireServer({progress = 999, completed = true})
                    end
                    print("✅ [QUEST] Set progress to 999:", remote.Name)
                    completedCount = completedCount + 1
                end)
            end
            
            -- Pattern 3: Objective/task remotes
            if remoteName:find("objective") or remoteName:find("task") then
                if remoteName:find("complete") or remoteName:find("finish") then
                    pcall(function()
                        if remote:IsA("RemoteFunction") then
                            remote:InvokeServer(true)
                            remote:InvokeServer("SecretFish", true)
                        else
                            remote:FireServer(true)
                            remote:FireServer("SecretFish", true)
                        end
                        print("✅ [QUEST] Completed objective:", remote.Name)
                        completedCount = completedCount + 1
                    end)
                end
            end
            
            -- Pattern 4: Specific fish catch remotes (untuk quest "catch secret fish")
            if remoteName:find("fish") and remoteName:find("catch") then
                pcall(function()
                    if remote:IsA("RemoteFunction") then
                        -- Simulate catching secret fish
                        remote:InvokeServer("SecretFish")
                        remote:InvokeServer({fish = "SecretFish", rarity = "Secret"})
                        remote:InvokeServer({name = "SecretFish", caught = true})
                    else
                        remote:FireServer("SecretFish")
                        remote:FireServer({fish = "SecretFish", rarity = "Secret"})
                        remote:FireServer({name = "SecretFish", caught = true})
                    end
                    print("✅ [QUEST] Simulated fish catch:", remote.Name)
                    completedCount = completedCount + 1
                end)
            end
            
            -- Pattern 5: Claim/reward remotes
            if remoteName:find("claim") or remoteName:find("reward") then
                pcall(function()
                    if remote:IsA("RemoteFunction") then
                        remote:InvokeServer()
                        remote:InvokeServer(true)
                    else
                        remote:FireServer()
                        remote:FireServer(true)
                    end
                    print("✅ [QUEST] Claimed reward:", remote.Name)
                    completedCount = completedCount + 1
                end)
            end
        end
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🎯 Total quest remotes triggered:", completedCount)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    return completedCount
end

local function scanQuestSystem()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔍 [QUEST] Scanning quest system...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local questRemotes = {}
    local packages = ReplicatedStorage:FindFirstChild("Packages", true)
    
    if packages then
        for _, remote in pairs(packages:GetDescendants()) do
            if remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent") then
                local name = remote.Name:lower()
                if name:find("quest") or name:find("objective") or name:find("task") or name:find("reward") then
                    table.insert(questRemotes, remote)
                    print("📋", remote.ClassName, ":", remote.Name)
                end
            end
        end
    end
    
    -- Check PlayerGui for quest UI
    local questGuis = {}
    for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
        local guiName = gui.Name:lower()
        if guiName:find("quest") or guiName:find("objective") or guiName:find("task") then
            table.insert(questGuis, gui)
            print("🖥️ Quest GUI found:", gui.Name)
        end
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 Found", #questRemotes, "quest remotes")
    print("📊 Found", #questGuis, "quest GUIs")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    return questRemotes
end

local function autoQuestLoop()
    while Settings.AutoQuest do
        task.wait(5) -- Check every 5 seconds
        
        print("🔄 [AUTO QUEST] Auto-completing quests...")
        forceCompleteQuest()
    end
end

-- ═══════════════════════════════════════════════════════════════
-- INSTANT FISHING - HOOKMETAMETHOD IMPLEMENTATION
-- ═══════════════════════════════════════════════════════════════

local function enableInstantFishing()
    -- Check if hookmetamethod is available
    if not hookmetamethod or not getnamecallmethod then
        warn("❌ hookmetamethod or getnamecallmethod not available in this executor!")
        GUI:Notification{
            Title = "Instant Fishing Error",
            Text = "Your executor doesn't support hookmetamethod!",
            Duration = 5
        }
        return
    end
    
    if instantFishingActive then
        print("⚡ Instant Fishing already active!")
        return
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("⚡ [INSTANT FISHING] Hooking metamethods...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    -- Hook __namecall metamethod
    local success, error = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Intercept fishing-related remote calls
            if method == "FireServer" or method == "InvokeServer" then
                local remoteName = self.Name:lower()
                
                -- Intercept catch/complete remotes with delay
                if remoteName:find("complete") or remoteName:find("finish") or remoteName:find("result") or remoteName:find("catch") then
                    if remoteName:find("fish") or remoteName:find("minigame") then
                        print("⏱️ [CATCH DELAY] Delaying catch for", Settings.CatchDelay, "seconds...")
                        
                        -- Store original call info
                        local originalSelf = self
                        local originalArgs = args
                        
                        -- Delay the catch
                        task.spawn(function()
                            catchDelayActive = true
                            task.wait(Settings.CatchDelay)
                            
                            -- Now execute the actual catch
                            pcall(function()
                                if method == "InvokeServer" then
                                    oldNamecall(originalSelf, unpack(originalArgs))
                                else
                                    oldNamecall(originalSelf, unpack(originalArgs))
                                end
                                print("✅ [CATCH DELAY] Fish caught after", Settings.CatchDelay, "seconds!")
                            end)
                            
                            catchDelayActive = false
                        end)
                        
                        -- Return nil to prevent immediate execution
                        return nil
                    end
                end
                
                -- Auto-complete minigame remotes (with catch delay)
                if remoteName:find("minigame") or remoteName:find("reel") or remoteName:find("hook") then
                    print("⚡ [INSTANT] Intercepted:", self.Name, "| Method:", method)
                    
                    -- Return success/perfect result (but catch will be delayed above)
                    if remoteName:find("result") or remoteName:find("complete") or remoteName:find("finish") then
                        print("✅ [INSTANT] Forcing perfect result!")
                        -- Return perfect/max score
                        return oldNamecall(self, 100, true, "perfect", ...)
                    end
                    
                    -- Auto-succeed minigame checks
                    if remoteName:find("check") or remoteName:find("validate") then
                        print("✅ [INSTANT] Bypassing validation!")
                        return true
                    end
                end
                
                -- Instant reel (skip timing) but respect catch delay
                if remoteName:find("requestfishingminigamestarted") then
                    print("⚡ [INSTANT] Minigame detected - auto-completing...")
                    
                    -- Call original to start minigame
                    local result = oldNamecall(self, ...)
                    
                    -- Immediately complete it (with catch delay)
                    task.spawn(function()
                        task.wait(0.1)
                        
                        -- Find and fire completion remote
                        local packages = ReplicatedStorage:FindFirstChild("Packages", true)
                        if packages then
                            for _, remote in pairs(packages:GetDescendants()) do
                                if remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent") then
                                    local name = remote.Name:lower()
                                    if name:find("complete") or name:find("finish") or name:find("result") then
                                        -- Apply catch delay here
                                        print("⏱️ [CATCH DELAY] Waiting", Settings.CatchDelay, "seconds before completion...")
                                        catchDelayActive = true
                                        task.wait(Settings.CatchDelay)
                                        
                                        pcall(function()
                                            if remote:IsA("RemoteFunction") then
                                                remote:InvokeServer(100, true) -- Perfect score
                                            else
                                                remote:FireServer(100, true)
                                            end
                                            print("✅ [INSTANT] Auto-completed minigame via:", remote.Name)
                                        end)
                                        
                                        catchDelayActive = false
                                    end
                                end
                            end
                        end
                    end)
                    
                    return result
                end
            end
            
            return oldNamecall(self, ...)
        end)
    end)
    
    if not success then
        warn("❌ Failed to hook __namecall:", error)
        GUI:Notification{
            Title = "Hook Failed",
            Text = "Failed to hook __namecall metamethod!",
            Duration = 5
        }
        return
    end
    
    -- Hook __index metamethod (for reading properties)
    success, error = pcall(function()
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            -- Force minigame success properties
            if typeof(self) == "Instance" then
                local name = self.Name:lower()
                
                -- Make minigame always show as completed/perfect
                if name:find("minigame") or name:find("fishing") then
                    if key == "Visible" and Settings.InstantFishing then
                        -- Hide minigame UI instantly (looks like instant completion)
                        if name:find("minigame") and self.Parent and self.Parent.Name == "Main" then
                            return false
                        end
                    end
                    
                    if key == "Value" or key == "Score" then
                        return 100 -- Perfect score
                    end
                    
                    if key == "Success" or key == "Completed" then
                        return true
                    end
                end
            end
            
            return oldIndex(self, key)
        end)
    end)
    
    if not success then
        warn("❌ Failed to hook __index:", error)
        GUI:Notification{
            Title = "Hook Failed",
            Text = "Failed to hook __index metamethod!",
            Duration = 5
        }
        return
    end
    
    instantFishingActive = true
    print("✅ [INSTANT FISHING] Metamethods hooked!")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

local function disableInstantFishing()
    if not instantFishingActive then
        print("⚡ Instant Fishing already disabled!")
        return
    end
    
    print("⏹️ [INSTANT FISHING] Disabling hooks...")
    
    -- Restore original metamethods
    if oldNamecall then
        hookmetamethod(game, "__namecall", oldNamecall)
    end
    
    if oldIndex then
        hookmetamethod(game, "__index", oldIndex)
    end
    
    instantFishingActive = false
    print("✅ [INSTANT FISHING] Hooks removed!")
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO PERFECT CATCH - DETECT PERFECT ZONE
-- ═══════════════════════════════════════════════════════════════

local function isInPerfectZone(minigame)
    if not Settings.AutoPerfect then return false end
    
    -- Method 1: Check for "Perfect" indicator/zone element
    local perfectZone = minigame:FindFirstChild("Perfect", true) or 
                       minigame:FindFirstChild("PerfectZone", true) or
                       minigame:FindFirstChild("GreenZone", true) or
                       minigame:FindFirstChild("TargetZone", true)
    
    if perfectZone and perfectZone:IsA("GuiObject") and perfectZone.Visible then
        -- Find moving indicator/bar
        local indicator = minigame:FindFirstChild("Indicator", true) or 
                         minigame:FindFirstChild("Bar", true) or
                         minigame:FindFirstChild("Mover", true) or
                         minigame:FindFirstChild("Slider", true)
        
        if indicator and indicator:IsA("GuiObject") then
            -- Calculate if indicator is within perfect zone
            local indicatorPos = indicator.AbsolutePosition.X + (indicator.AbsoluteSize.X / 2)
            local zoneStart = perfectZone.AbsolutePosition.X
            local zoneEnd = zoneStart + perfectZone.AbsoluteSize.X
            
            -- Check if indicator center is within perfect zone (with threshold)
            local distance = math.min(
                math.abs(indicatorPos - zoneStart),
                math.abs(indicatorPos - zoneEnd)
            )
            
            if indicatorPos >= zoneStart and indicatorPos <= zoneEnd then
                print("✨ [PERFECT] Indicator in perfect zone! Distance:", distance, "px")
                return true
            end
        end
    end
    
    -- Method 2: Check color-based perfect zone (green = perfect)
    local colorBar = minigame:FindFirstChild("Bar", true) or 
                    minigame:FindFirstChild("ColorBar", true)
    
    if colorBar and colorBar:IsA("GuiObject") and colorBar.BackgroundColor3 then
        local color = colorBar.BackgroundColor3
        
        -- Green color = perfect zone (R < 0.3, G > 0.7, B < 0.3)
        if color.R < 0.3 and color.G > 0.7 and color.B < 0.3 then
            print("✨ [PERFECT] Green zone detected!")
            return true
        end
    end
    
    -- Method 3: Check for text indicator showing "Perfect!"
    for _, obj in pairs(minigame:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = obj.Text:lower()
            if text:find("perfect") or text:find("excellent") or text:find("great") then
                if obj.Visible then
                    print("✨ [PERFECT] Perfect text detected!")
                    return true
                end
            end
        end
    end
    
    -- Method 4: Position-based calculation (center of minigame = perfect)
    local indicator = minigame:FindFirstChild("Indicator", true) or 
                     minigame:FindFirstChild("Mover", true)
    
    if indicator and indicator:IsA("GuiObject") then
        local minigameCenter = minigame.AbsolutePosition.X + (minigame.AbsoluteSize.X / 2)
        local indicatorCenter = indicator.AbsolutePosition.X + (indicator.AbsoluteSize.X / 2)
        local distance = math.abs(minigameCenter - indicatorCenter)
        
        -- If indicator is within threshold pixels of center = perfect
        if distance <= Settings.PerfectThreshold then
            print("✨ [PERFECT] Indicator at center! Distance:", distance, "px")
            return true
        end
    end
    
    return false
end

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
            perfectZoneDetected = false
        end
        
        -- Check for perfect zone if auto perfect is enabled
        if Settings.AutoPerfect and not reelDone then
            if isInPerfectZone(minigame) then
                perfectZoneDetected = true
                
                -- Instant click when in perfect zone!
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    print("✨✅ PERFECT REEL CLICKED!")
                end)
                
                reelDone = true
            end
        -- Fallback: Normal timing if perfect not detected or disabled
        elseif not reelDone and tick() - reelMinigameDetectedTime >= Settings.ReelTiming then
            -- Single click for reel (Virtual Input)
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                print("✅ Reel clicked! (normal timing)")
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
if useFallbackGUI then
    -- Mobile GUI Elements
    GUI.Toggle("⚡ Instant Fishing", "Instant catch with metamethod", false, function(state)
        Settings.InstantFishing = state
        if state then
            enableInstantFishing()
            GUI.Notification("⚡ Instant Fishing ON", "Metamethods hooked!", 3)
        else
            disableInstantFishing()
            GUI.Notification("⚡ Instant Fishing OFF", "Hooks removed", 2)
        end
    end)
    
    GUI.Toggle("✨ Auto Perfect", "Auto perfect catch", true, function(state)
        Settings.AutoPerfect = state
        GUI.Notification(state and "✨ Auto Perfect ON" or "Auto Perfect OFF", 
            state and "Will detect perfect zone!" or "Using normal timing", 2)
    end)
    
    GUI.Toggle("🎣 Auto Cast & Reel", "Auto fishing", false, function(state)
        Settings.AutoCast = state
        if not state then
            reelMinigameDetectedTime = 0
            reelDone = false
            lastHookClickTime = 0
            wasMinigameActive = false
            perfectZoneDetected = false
        end
        GUI.Notification(state and "Auto Fishing ON" or "Auto Fishing OFF",
            state and "Auto fishing active" or "Stopped", 2)
    end)
    
    GUI.Toggle("🎯 Auto Quest", "Auto complete quest", false, function(state)
        Settings.AutoQuest = state
        if state then
            -- Immediately force complete on enable
            forceCompleteQuest()
            -- Start auto loop
            task.spawn(autoQuestLoop)
            GUI.Notification("🎯 Auto Quest ON", "Quest force completed! Will auto-complete every 5s", 3)
        else
            GUI.Notification("🎯 Auto Quest OFF", "Quest auto-complete disabled", 2)
        end
    end)
    
    GUI.Button("🎣 Cast Now", "Manual cast", function()
        castRod()
    end)
    
    GUI.Button("🎯 Force Complete Quest", "Complete quest without catching fish", function()
        local count = forceCompleteQuest()
        GUI.Notification("Quest Complete", "Triggered " .. count .. " quest remotes!", 3)
    end)
    
    GUI.Button("🔍 Scan Quest System", "Find all quest remotes", function()
        local remotes = scanQuestSystem()
        GUI.Notification("Quest Scan", "Found " .. #remotes .. " quest remotes (check console)", 3)
    end)
    
    GUI.Button("🔍 Find Rod", "Search for fishing rod", function()
        local rod = findFishingRod()
        if rod then
            GUI.Notification("Rod Found", "Found: " .. rod.Name, 3)
        else
            GUI.Notification("No Rod", "No fishing rod found!", 3)
        end
    end)
    
    GUI.Button("💰 Sell All Fish", "Sell everything", function()
        print("💰 Selling all fish...")
        local packages = ReplicatedStorage:FindFirstChild("Packages", true)
        if packages then
            local soldCount = 0
            for _, obj in pairs(packages:GetDescendants()) do
                if obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent") then
                    if obj.Name:lower():find("sell") then
                        pcall(function()
                            if obj:IsA("RemoteFunction") then
                                obj:InvokeServer()
                            else
                                obj:FireServer()
                            end
                            soldCount = soldCount + 1
                        end)
                    end
                end
            end
            GUI.Notification("Sell All Fish", "Fired " .. soldCount .. " sell remotes!", 3)
        end
    end)
    
    GUI.Textbox("Perfect Threshold", "10", "Pixel distance for perfect", function(text)
        local value = tonumber(text)
        if value and value > 0 then
            Settings.PerfectThreshold = value
            GUI.Notification("Perfect Threshold", value .. " pixels", 2)
        end
    end)
    
    GUI.Textbox("Catch Delay", "0.3", "Delay before catch (seconds)", function(text)
        local value = tonumber(text)
        if value and value >= 0 then
            Settings.CatchDelay = value
            GUI.Notification("Catch Delay", value .. " seconds", 2)
        end
    end)
    
    GUI.Textbox("Cast Delay", "0.6", "Mouse hold duration (seconds)", function(text)
        local value = tonumber(text)
        if value and value > 0 then
            Settings.CastDelay = value
            GUI.Notification("Cast Delay", value .. " seconds", 2)
        end
    end)
    
    GUI.Textbox("Reel Timing", "0.6", "Delay before reel (seconds)", function(text)
        local value = tonumber(text)
        if value and value > 0 then
            Settings.ReelTiming = value
            GUI.Notification("Reel Timing", value .. " seconds", 2)
        end
    end)
    
    GUI.Textbox("Hook Timing", "0.1", "Hook click interval (seconds)", function(text)
        local value = tonumber(text)
        if value and value > 0 then
            Settings.HookTiming = value
            GUI.Notification("Hook Timing", value .. " seconds", 2)
        end
    end)
    
    GUI.Notification("Auto Fishing Loaded", "Mobile version ready!", 5)
    
else
    -- Mercury GUI Elements (PC version)
MainTab:Toggle{
    Name = "⚡ Instant Fishing (Metamethod)",
    StartingState = false,
    Description = "Hook metamethods for instant minigame completion (RECOMMENDED)",
    Callback = function(state)
        Settings.InstantFishing = state
        
        if state then
            enableInstantFishing()
            GUI:Notification{
                Title = "⚡ Instant Fishing ON",
                Text = "Metamethods hooked! Minigames will auto-complete instantly.",
                Duration = 3
            }
        else
            disableInstantFishing()
            GUI:Notification{
                Title = "⚡ Instant Fishing OFF",
                Text = "Metamethod hooks removed.",
                Duration = 2
            }
        end
    end
}

MainTab:Toggle{
    Name = "✨ Auto Perfect Catch",
    StartingState = true,
    Description = "Automatically click at perfect zone for perfect catch",
    Callback = function(state)
        Settings.AutoPerfect = state
        print("✨ Auto Perfect:", state and "ON" or "OFF")
        
        GUI:Notification{
            Title = state and "✨ Auto Perfect ON" or "Auto Perfect OFF",
            Text = state and "Will detect and click at perfect zone!" or "Using normal timing",
            Duration = 2
        }
    end
}

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
            perfectZoneDetected = false
        end
        
        print("🎣 Auto Cast:", state and "ON" or "OFF")
        
        GUI:Notification{
            Title = state and "Auto Fishing ON" or "Auto Fishing OFF",
            Text = state and "Auto fishing with realistic timing" or "Stopped fishing",
            Duration = 2
        }
    end
}

MainTab:Toggle{
    Name = "🎯 Auto Quest Complete",
    StartingState = false,
    Description = "Force complete all quests (no need to catch fish)",
    Callback = function(state)
        Settings.AutoQuest = state
        
        if state then
            -- Immediately force complete
            local count = forceCompleteQuest()
            -- Start auto loop
            task.spawn(autoQuestLoop)
            
            GUI:Notification{
                Title = "🎯 Auto Quest ON",
                Text = "Force completed! Triggered " .. count .. " remotes. Will auto-complete every 5s.",
                Duration = 4
            }
        else
            GUI:Notification{
                Title = "🎯 Auto Quest OFF",
                Text = "Quest auto-complete disabled",
                Duration = 2
            }
        end
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
    Name = "🎯 Force Complete Quest",
    Description = "Complete quest NOW without catching any fish",
    Callback = function()
        local count = forceCompleteQuest()
        GUI:Notification{
            Title = "Quest Force Completed",
            Text = "Triggered " .. count .. " quest remotes! Check if quest completed.",
            Duration = 3
        }
    end
}

MainTab:Button{
    Name = "🔍 Scan Quest System",
    Description = "Find all quest-related remotes (check console F9)",
    Callback = function()
        local remotes = scanQuestSystem()
        GUI:Notification{
            Title = "Quest System Scanned",
            Text = "Found " .. #remotes .. " quest remotes (check console F9 for details)",
            Duration = 3
        }
    end
}

MainTab:Button{
    Name = "📋 Check Active Quests",
    Description = "View current active quests (check console F9)",
    Callback = function()
        getActiveQuests()
        GUI:Notification{
            Title = "Quest Check",
            Text = "Check console (F9) for quest information",
            Duration = 3
        }
    end
}

MainTab:Button{
    Name = "🎯 Complete Quest Now",
    Description = "Manually trigger quest completion",
    Callback = function()
        local success = triggerQuestCompletion()
        if success then
            GUI:Notification{
                Title = "Quest Complete",
                Text = "Quest completion triggered successfully!",
                Duration = 3
            }
        else
            GUI:Notification{
                Title = "Quest Failed",
                Text = "No quest remotes found or triggered",
                Duration = 3
            }
        end
    end
}

MainTab:Button{
    Name = "🔍 Scan Quest Remotes",
    Description = "Find all quest-related remotes in game",
    Callback = function()
        local remotes = findQuestRemotes()
        GUI:Notification{
            Title = "Quest Remotes Found",
            Text = "Found " .. #remotes .. " quest remotes (check console F9)",
            Duration = 3
        }
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
    Name = "Perfect Threshold",
    Placeholder = "10",
    Description = "Pixel distance untuk perfect zone (semakin kecil = lebih perfect)",
    Callback = function(text)
        local value = tonumber(text)
        if value and value > 0 then
            Settings.PerfectThreshold = value
            print("✨ Perfect Threshold:", value, "px")
            GUI:Notification{
                Title = "Perfect Threshold Updated",
                Text = value .. " pixel threshold for perfect catch",
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
    Name = "Catch Delay",
    Placeholder = "0.3",
    Description = "Delay sebelum ikan tertangkap (anti-detect, lebih natural)",
    Callback = function(text)
        local value = tonumber(text)
        if value and value >= 0 then
            Settings.CatchDelay = value
            print("⏱️ Catch Delay:", value)
            GUI:Notification{
                Title = "Catch Delay Updated",
                Text = "Fish will be caught after " .. value .. " seconds",
                Duration = 2
            }
        else
            GUI:Notification{
                Title = "Invalid Input",
                Text = "Please enter a valid number (0 or greater)",
                Duration = 2
            }
        end
    end
}

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

end -- End of Mercury GUI version

print("✅ Auto Fishing Script loaded successfully!")
print("🎣 Features: Auto Cast, Auto Reel, Auto Hook, Auto Perfect, Instant Fishing, and Force Complete Quest")
print("✨ Auto Perfect Catch - Detects perfect zone automatically!")
print("⚡ Instant Fishing (Hookmetamethod) - Enable in Main tab!")
print("🎯 FORCE COMPLETE QUEST - Complete quest tanpa perlu nangkap ikan!")
print("⚙️ Configure settings in the Settings tab")
print("")
print("📋 QUEST COMMANDS:")
print("   - Click 'Force Complete Quest' to complete quest without catching fish!")
print("   - Enable 'Auto Quest' to auto-complete every 5 seconds")
print("   - Use 'Scan Quest System' to find all quest remotes")
print("   - Check console (F9) for detailed quest information")
