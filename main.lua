local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local WinningLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/wxnvxa/winning-lib/main/dist/main.lua"))()

local Config = {
    SpeedBoostEnabled = false,
    SpeedBoost = 150,
    PreserveY = true,
    SmoothStart = true,
    Acceleration = 5,
    EasySteer = true,
    EasySteerRate = 120,

    FlyEnabled = false,
    FlySpeed = 150,
    FlyNoclip = false,

    RotationEnabled = true,
    RotationSpeed = 120,
    PitchEnabled = true,
    YawEnabled = true,
    RollEnabled = true,

    JumpEnabled = false,
    JumpPower = 100,

    VelocityMultiplierEnabled = false,
    VelocityMultiplier = 2,

    BounceEnabled = false,
    Bounciness = 1.2,
    
    CustomGravityEnabled = false,
    GravityFactor = 1,
    
    BrakeDashEnabled = false,
    BrakeDashDistance = 30,
}

local UIElements = {}

local Keybinds = {
    ToggleSpeed = nil,
    ToggleFly = nil,
    ToggleAir = nil,
    Jump = nil,
    ToggleVelocity = nil,
    ToggleFlyNoclip = nil,
    ToggleBounce = nil,
    ToggleGravity = nil,
    ToggleBrakeDash = nil,
    BrakeDashLeft = nil,
    BrakeDashRight = nil,
    BrakeDashBack = nil,
    
    PitchUp = nil,
    PitchDown = nil,
    YawLeft = nil,
    YawRight = nil,
    RollLeft = nil,
    RollRight = nil,
}

local KeybindDefaults = {
    ToggleSpeed = "None",
    ToggleFly = "None",
    ToggleAir = "None",
    Jump = "V",
    ToggleVelocity = "None",
    ToggleFlyNoclip = "None",
    ToggleBounce = "None",
    ToggleGravity = "None",
    ToggleBrakeDash = "None",
    BrakeDashLeft = "None",
    BrakeDashRight = "None",
    BrakeDashBack = "None",
    PitchDown = "LeftShift",
    PitchUp = "LeftControl",
    YawLeft = "Left",
    YawRight = "Right",
    RollLeft = "Q",
    RollRight = "E"
}

local function getVehicleBase(seat)
    local model = seat:FindFirstAncestorOfClass("Model")
    if model and model.PrimaryPart then
        return model.PrimaryPart
    end
    return seat
end

local function isKeyPressed(keybindObj)
    if not keybindObj or not keybindObj.Value or keybindObj.Value == "None" then
        return false
    end
    local keyName = keybindObj.Value
    local success, keyCode = pcall(function()
        return Enum.KeyCode[keyName]
    end)
    if success and keyCode then
        return UserInputService:IsKeyDown(keyCode)
    end
    if keyName == "MouseLeftButton" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif keyName == "MouseRightButton" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end
    return false
end

local function listConfigsCustom()
    local files = {}
    if isfolder and isfolder("SorrelHubVehicles") then
        local list = listfiles("SorrelHubVehicles") or {}
        for _, file in ipairs(list) do
            local name = file:match("([^\\/]+)%.json$")
            if name then
                table.insert(files, name)
            end
        end
    end
    return files
end

local function saveConfigCustom(name)
    if not writefile then return false, "writefile not supported" end
    
    local data = {
        Settings = {},
        Keybinds = {}
    }
    for key, val in pairs(Config) do
        data.Settings[key] = val
    end
    for key, obj in pairs(Keybinds) do
        if obj then
            data.Keybinds[key] = obj.Value
        end
    end
    
    local success, err = pcall(function()
        if isfolder and not isfolder("SorrelHubVehicles") then
            makefolder("SorrelHubVehicles")
        end
        writefile("SorrelHubVehicles/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    return success, err
end

local function loadConfigCustom(name)
    if not readfile or not isfile then return false, "File functions not supported" end
    local filepath = "SorrelHubVehicles/" .. name .. ".json"
    if not isfile(filepath) then return false, "File not found" end
    
    local success, content = pcall(function()
        return readfile(filepath)
    end)
    if not success then return false, "Read failed" end
    
    local success2, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if not success2 or type(data) ~= "table" then return false, "Decode failed" end
    
    if data.Settings then
        for key, val in pairs(data.Settings) do
            Config[key] = val
            local el = UIElements[key]
            if el then
                pcall(function()
                    el:Set(val)
                end)
            end
        end
    end
    
    if data.Keybinds then
        for key, val in pairs(data.Keybinds) do
            local el = Keybinds[key]
            if el then
                pcall(function()
                    el:Set(val)
                end)
            end
        end
    end
    
    return true
end

local function deleteConfigCustom(name)
    if not delfile or not isfile then return false end
    local filepath = "SorrelHubVehicles/" .. name .. ".json"
    if isfile(filepath) then
        pcall(function()
            delfile(filepath)
        end)
        return true
    end
    return false
end

local originalCollisions = {}
local wasNoclipActive = false
local lastVehicleModel = nil
local lastCharacter = nil
local lockPosition = nil

local function cleanupNoclip()
    lockPosition = nil
    if wasNoclipActive then
        pcall(function()
            if lastVehicleModel then
                for _, part in ipairs(lastVehicleModel:GetDescendants()) do
                    if part:IsA("BasePart") and originalCollisions[part] ~= nil then
                        part.CanCollide = originalCollisions[part]
                    end
                end
            end
            if lastCharacter then
                for _, part in ipairs(lastCharacter:GetDescendants()) do
                    if part:IsA("BasePart") and originalCollisions[part] ~= nil then
                        part.CanCollide = originalCollisions[part]
                    end
                end
            end
        end)
        table.clear(originalCollisions)
        wasNoclipActive = false
        lastVehicleModel = nil
        lastCharacter = nil
    end
end

RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if seat and seat:IsA("VehicleSeat") then
        local model = seat:FindFirstAncestorOfClass("Model")
        local shouldNoclip = Config.FlyEnabled and Config.FlyNoclip
        
        if shouldNoclip then
            wasNoclipActive = true
            lastVehicleModel = model
            lastCharacter = char
            
            -- Disable collisions on the vehicle
            if model then
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if originalCollisions[part] == nil then
                            originalCollisions[part] = part.CanCollide
                        end
                        part.CanCollide = false
                    end
                end
            end
            
            -- Disable collisions on the character to prevent physics glitches
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if originalCollisions[part] == nil then
                        originalCollisions[part] = part.CanCollide
                    end
                    part.CanCollide = false
                end
            end
        else
            cleanupNoclip()
        end
    else
        cleanupNoclip()
    end
end)

RunService.Heartbeat:Connect(function(deltaTime)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local seat = hum.SeatPart
            if seat and seat:IsA("VehicleSeat") then
                local base = getVehicleBase(seat)
                
                local pitch = 0
                local yaw = 0
                local roll = 0

                if Config.RotationEnabled then
                    if Config.PitchEnabled then
                        if isKeyPressed(Keybinds.PitchDown) then
                            pitch = -1
                        elseif isKeyPressed(Keybinds.PitchUp) then
                            pitch = 1
                        end
                    end
                    
                    if Config.YawEnabled then
                        if isKeyPressed(Keybinds.YawLeft) then
                            yaw = 1
                        elseif isKeyPressed(Keybinds.YawRight) then
                            yaw = -1
                        end
                    end
                    
                    if Config.RollEnabled then
                        if isKeyPressed(Keybinds.RollLeft) then
                            roll = -1
                        elseif isKeyPressed(Keybinds.RollRight) then
                            roll = 1
                        end
                    end
                    
                    if pitch ~= 0 or yaw ~= 0 or roll ~= 0 then
                        local rotSpeed = math.rad(Config.RotationSpeed) * deltaTime
                        base.CFrame = base.CFrame * CFrame.Angles(pitch * rotSpeed, yaw * rotSpeed, roll * rotSpeed)
                        base.AssemblyAngularVelocity = Vector3.zero
                    end
                end
                
                -- Velocity Multiplier (Inertia Boost)
                if Config.VelocityMultiplierEnabled and math.abs(seat.ThrottleFloat) > 0.05 then
                    local look = seat.CFrame.LookVector
                    base.AssemblyLinearVelocity = base.AssemblyLinearVelocity + look * (seat.ThrottleFloat * Config.VelocityMultiplier * 0.2)
                end

                -- Gravity Control (Apply counter-force dynamically based on workspace gravity)
                if Config.CustomGravityEnabled then
                    local mass = 0
                    for _, p in ipairs(model:GetDescendants()) do
                        if p:IsA("BasePart") then
                            mass = mass + p:GetMass()
                        end
                    end
                    local workspaceGravity = workspace.Gravity
                    local targetGravity = workspaceGravity * Config.GravityFactor
                    local counterForce = mass * (workspaceGravity - targetGravity)
                    
                    -- Apply force to cancel out native gravity and apply target gravity
                    base.AssemblyLinearVelocity = base.AssemblyLinearVelocity + Vector3.new(0, (counterForce / mass) * deltaTime, 0)
                end

                -- Bounce Mode (Check ground contact & bounce back based on fall velocity)
                if Config.BounceEnabled then
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                    raycastParams.FilterDescendantsInstances = {char, model}
                    
                    -- Raycast down from vehicle base slightly below the lowest wheel
                    local rayOrigin = base.Position
                    local rayDirection = -Vector3.yAxis * 8
                    local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                    
                    if result then
                        local currentYVel = base.AssemblyLinearVelocity.Y
                        if currentYVel < -10 then -- Fast falling
                            local bounceImpulse = math.abs(currentYVel) * Config.Bounciness
                            base.AssemblyLinearVelocity = Vector3.new(base.AssemblyLinearVelocity.X, bounceImpulse, base.AssemblyLinearVelocity.Z)
                        end
                    end
                end

                if Config.FlyEnabled then
                    local throttle = seat.ThrottleFloat
                    local steer = seat.SteerFloat
                    
                    local isMoving = (math.abs(throttle) > 0.05) or (steer ~= 0) or (yaw ~= 0) or (pitch ~= 0) or (roll ~= 0)
                    
                    if isMoving then
                        lockPosition = nil
                        
                        if yaw == 0 and steer ~= 0 then
                            local flyTurn = math.rad(Config.RotationSpeed) * deltaTime
                            base.CFrame = base.CFrame * CFrame.Angles(0, -steer * flyTurn, 0)
                        end
                        
                        local velocity = seat.CFrame.LookVector * (throttle * Config.FlySpeed)
                        base.AssemblyLinearVelocity = velocity
                        base.AssemblyAngularVelocity = Vector3.zero
                    else
                        if not lockPosition then
                            lockPosition = base.CFrame
                        end
                        base.CFrame = lockPosition
                        base.AssemblyLinearVelocity = Vector3.zero
                        base.AssemblyAngularVelocity = Vector3.zero
                    end
                    
                elseif Config.SpeedBoostEnabled then
                    local throttle = seat.ThrottleFloat
                    local steer = seat.SteerFloat
                    
                    if Config.EasySteer and math.abs(steer) > 0.05 then
                        local steerSpeed = math.rad(Config.EasySteerRate) * deltaTime
                        base.CFrame = base.CFrame * CFrame.Angles(0, -steer * steerSpeed, 0)
                        base.AssemblyAngularVelocity = Vector3.zero
                    end
                    
                    if math.abs(throttle) > 0.05 then
                        local lookVector = seat.CFrame.LookVector
                        local currentVel = base.AssemblyLinearVelocity
                        local targetVel = lookVector * (throttle * Config.SpeedBoost)
                        
                        local finalVel
                        if Config.SmoothStart then
                            local alpha = math.clamp(Config.Acceleration * deltaTime, 0, 1)
                            finalVel = currentVel:Lerp(targetVel, alpha)
                        else
                            finalVel = targetVel
                        end
                        
                        if Config.PreserveY then
                            base.AssemblyLinearVelocity = Vector3.new(finalVel.X, currentVel.Y, finalVel.Z)
                        else
                            base.AssemblyLinearVelocity = finalVel
                        end
                    end
                end
            end
        end
    end
end)

local Window = WinningLib:CreateWindow({
    Title = "Car Exploit",
    SubTitle = "Sorrel Hub",
    Icon = "car",
    Theme = "Dark",
    Acrylic = false
})

local MainTab = Window:Tab({
    Title = "Main",
    Icon = "home"
})

local KeybindTab = Window:Tab({
    Title = "Keybinds",
    Icon = "keyboard"
})

local ConfigTab = Window:Tab({
    Title = "Configs",
    Icon = "file-text"
})

local SpeedSection = MainTab:Section({
    Title = "Speed Boost & Multipliers"
})

UIElements.SpeedBoostEnabled = SpeedSection:Toggle({
    Title = "Enable Speed Boost",
    Default = false,
    Callback = function(state)
        Config.SpeedBoostEnabled = state
    end
})

UIElements.SpeedBoost = SpeedSection:Slider({
    Title = "Boost Amount",
    Value = {
        Min = 0,
        Max = 1000,
        Default = 150,
    },
    Callback = function(val)
        Config.SpeedBoost = val
    end
})

UIElements.SmoothStart = SpeedSection:Toggle({
    Title = "Smooth Start",
    Description = "Smoothly accelerates the vehicle",
    Default = true,
    Callback = function(state)
        Config.SmoothStart = state
    end
})

UIElements.Acceleration = SpeedSection:Slider({
    Title = "Acceleration Rate",
    Description = "Acceleration rate (higher values mean faster ramp-up)",
    Value = {
        Min = 1,
        Max = 30,
        Default = 5,
    },
    Callback = function(val)
        Config.Acceleration = val
    end
})

UIElements.PreserveY = SpeedSection:Toggle({
    Title = "Preserve Gravity",
    Description = "Prevents the vehicle from flying off bumps",
    Default = true,
    Callback = function(state)
        Config.PreserveY = state
    end
})

UIElements.EasySteer = SpeedSection:Toggle({
    Title = "Easy Steer",
    Description = "Improves steering handling at high speeds",
    Default = true,
    Callback = function(state)
        Config.EasySteer = state
    end
})

UIElements.EasySteerRate = SpeedSection:Slider({
    Title = "Steer Assist Rate",
    Description = "Strength of the steering assistance",
    Value = {
        Min = 10,
        Max = 360,
        Default = 120,
    },
    Callback = function(val)
        Config.EasySteerRate = val
    end
})

UIElements.VelocityMultiplierEnabled = SpeedSection:Toggle({
    Title = "Enable Inertia Multiplier",
    Description = "Multiplies natural acceleration and speed using physics",
    Default = false,
    Callback = function(state)
        Config.VelocityMultiplierEnabled = state
    end
})

UIElements.VelocityMultiplier = SpeedSection:Slider({
    Title = "Inertia Multiplier Factor",
    Value = {
        Min = 1,
        Max = 10,
        Default = 2,
    },
    Callback = function(val)
        Config.VelocityMultiplier = val
    end
})

local FlySection = MainTab:Section({
    Title = "Car Fly"
})

UIElements.FlyEnabled = FlySection:Toggle({
    Title = "Enable Car Fly",
    Default = false,
    Callback = function(state)
        Config.FlyEnabled = state
    end
})

UIElements.FlyNoclip = FlySection:Toggle({
    Title = "Noclip on Fly",
    Description = "Allows the vehicle to fly through solid walls",
    Default = false,
    Callback = function(state)
        Config.FlyNoclip = state
    end
})

UIElements.FlySpeed = FlySection:Slider({
    Title = "Fly Speed",
    Value = {
        Min = 0,
        Max = 1000,
        Default = 150,
    },
    Callback = function(val)
        Config.FlySpeed = val
    end
})

local JumpSection = MainTab:Section({
    Title = "Vehicle Jump"
})

UIElements.JumpEnabled = JumpSection:Toggle({
    Title = "Enable Vehicle Jump",
    Default = false,
    Callback = function(state)
        Config.JumpEnabled = state
    end
})

UIElements.JumpPower = JumpSection:Slider({
    Title = "Jump Power",
    Value = {
        Min = 10,
        Max = 500,
        Default = 100,
    },
    Callback = function(val)
        Config.JumpPower = val
    end
})

UIElements.BounceEnabled = JumpSection:Toggle({
    Title = "Enable Bounce Mode (Rubber Car)",
    Description = "Bounces the vehicle off the ground when landing",
    Default = false,
    Callback = function(state)
        Config.BounceEnabled = state
    end
})

UIElements.Bounciness = JumpSection:Slider({
    Title = "Bounciness Factor",
    Value = {
        Min = 0.5,
        Max = 3.0,
        Decimal = 1,
        Default = 1.2,
    },
    Callback = function(val)
        Config.Bounciness = val
    end
})

local GravitySection = MainTab:Section({
    Title = "Gravity Control"
})

UIElements.CustomGravityEnabled = GravitySection:Toggle({
    Title = "Enable Gravity Control",
    Description = "Modify gravitational pull on your vehicle",
    Default = false,
    Callback = function(state)
        Config.CustomGravityEnabled = state
    end
})

UIElements.GravityFactor = GravitySection:Slider({
    Title = "Gravity Multiplier",
    Description = "0 = No Gravity, 1 = Normal, -1 = Reversed",
    Value = {
        Min = -2.0,
        Max = 2.0,
        Decimal = 1,
        Default = 1.0,
    },
    Callback = function(val)
        Config.GravityFactor = val
    end
})

local BrakeSection = MainTab:Section({
    Title = "Sudden Brake Dash"
})

UIElements.BrakeDashEnabled = BrakeSection:Toggle({
    Title = "Enable Sudden Brake Dash",
    Description = "Perform instant dash when braking or pressing bind",
    Default = false,
    Callback = function(state)
        Config.BrakeDashEnabled = state
    end
})

UIElements.BrakeDashDistance = BrakeSection:Slider({
    Title = "Dash Distance",
    Value = {
        Min = 10,
        Max = 100,
        Default = 30,
    },
    Callback = function(val)
        Config.BrakeDashDistance = val
    end
})

local RotSection = MainTab:Section({
    Title = "Keyboard Rotation (Air Control)"
})

UIElements.RotationEnabled = RotSection:Toggle({
    Title = "Enable Rotation",
    Description = "Allows tilting and spinning the vehicle with keys",
    Default = true,
    Callback = function(state)
        Config.RotationEnabled = state
    end
})

UIElements.RotationSpeed = RotSection:Slider({
    Title = "Rotation Speed",
    Value = {
        Min = 10,
        Max = 360,
        Default = 120,
    },
    Callback = function(val)
        Config.RotationSpeed = val
    end
})

UIElements.PitchEnabled = RotSection:Toggle({
    Title = "Pitch Control",
    Description = "Nose tilt controls (Up/Down)",
    Default = true,
    Callback = function(state)
        Config.PitchEnabled = state
    end
})

UIElements.YawEnabled = RotSection:Toggle({
    Title = "Yaw Control",
    Description = "Left/Right spinning controls",
    Default = true,
    Callback = function(state)
        Config.YawEnabled = state
    end
})

UIElements.RollEnabled = RotSection:Toggle({
    Title = "Roll Control",
    Description = "Left/Right rolling (barrel roll) controls",
    Default = true,
    Callback = function(state)
        Config.RollEnabled = state
    end
})

local ToggleBindsSection = KeybindTab:Section({
    Title = "Toggle Functions"
})

Keybinds.ToggleSpeed = ToggleBindsSection:Keybind({
    Title = "Toggle Speed Boost",
    Value = KeybindDefaults.ToggleSpeed,
    Callback = function()
        Config.SpeedBoostEnabled = not Config.SpeedBoostEnabled
        UIElements.SpeedBoostEnabled:Set(Config.SpeedBoostEnabled)
    end
})

Keybinds.ToggleFly = ToggleBindsSection:Keybind({
    Title = "Toggle Car Fly",
    Value = KeybindDefaults.ToggleFly,
    Callback = function()
        Config.FlyEnabled = not Config.FlyEnabled
        UIElements.FlyEnabled:Set(Config.FlyEnabled)
    end
})

Keybinds.ToggleAir = ToggleBindsSection:Keybind({
    Title = "Toggle Air Control",
    Value = KeybindDefaults.ToggleAir,
    Callback = function()
        Config.RotationEnabled = not Config.RotationEnabled
        UIElements.RotationEnabled:Set(Config.RotationEnabled)
    end
})

Keybinds.Jump = ToggleBindsSection:Keybind({
    Title = "Vehicle Jump",
    Value = KeybindDefaults.Jump,
    Callback = function()
        if Config.JumpEnabled then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local seat = hum and hum.SeatPart
            if seat and seat:IsA("VehicleSeat") then
                local base = getVehicleBase(seat)
                if base then
                    base.AssemblyLinearVelocity = base.AssemblyLinearVelocity + Vector3.new(0, Config.JumpPower, 0)
                end
            end
        end
    end
})

Keybinds.ToggleVelocity = ToggleBindsSection:Keybind({
    Title = "Toggle Inertia Multiplier",
    Value = KeybindDefaults.ToggleVelocity,
    Callback = function()
        Config.VelocityMultiplierEnabled = not Config.VelocityMultiplierEnabled
        UIElements.VelocityMultiplierEnabled:Set(Config.VelocityMultiplierEnabled)
    end
})

Keybinds.ToggleFlyNoclip = ToggleBindsSection:Keybind({
    Title = "Toggle Fly Noclip",
    Value = KeybindDefaults.ToggleFlyNoclip,
    Callback = function()
        Config.FlyNoclip = not Config.FlyNoclip
        UIElements.FlyNoclip:Set(Config.FlyNoclip)
    end
})

Keybinds.ToggleBounce = ToggleBindsSection:Keybind({
    Title = "Toggle Bounce Mode",
    Value = KeybindDefaults.ToggleBounce,
    Callback = function()
        Config.BounceEnabled = not Config.BounceEnabled
        UIElements.BounceEnabled:Set(Config.BounceEnabled)
    end
})

Keybinds.ToggleGravity = ToggleBindsSection:Keybind({
    Title = "Toggle Gravity Control",
    Value = KeybindDefaults.ToggleGravity,
    Callback = function()
        Config.CustomGravityEnabled = not Config.CustomGravityEnabled
        UIElements.CustomGravityEnabled:Set(Config.CustomGravityEnabled)
    end
})

Keybinds.ToggleBrakeDash = ToggleBindsSection:Keybind({
    Title = "Toggle Brake Dash Mode",
    Value = KeybindDefaults.ToggleBrakeDash,
    Callback = function()
        Config.BrakeDashEnabled = not Config.BrakeDashEnabled
        UIElements.BrakeDashEnabled:Set(Config.BrakeDashEnabled)
    end
})

local DashBindsSection = KeybindTab:Section({
    Title = "Brake Dash Directions"
})

local function triggerDash(directionVector)
    if not Config.BrakeDashEnabled then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if seat and seat:IsA("VehicleSeat") then
        local base = getVehicleBase(seat)
        if base then
            -- Muted CFrame offset
            base.CFrame = base.CFrame + (directionVector * Config.BrakeDashDistance)
            -- Give dynamic boost direction
            base.AssemblyLinearVelocity = directionVector * 100
        end
    end
end

Keybinds.BrakeDashLeft = DashBindsSection:Keybind({
    Title = "Dash Left",
    Value = KeybindDefaults.BrakeDashLeft,
    Callback = function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local seat = hum and hum.SeatPart
        if seat then
            triggerDash(-seat.CFrame.RightVector)
        end
    end
})

Keybinds.BrakeDashRight = DashBindsSection:Keybind({
    Title = "Dash Right",
    Value = KeybindDefaults.BrakeDashRight,
    Callback = function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local seat = hum and hum.SeatPart
        if seat then
            triggerDash(seat.CFrame.RightVector)
        end
    end
})

Keybinds.BrakeDashBack = DashBindsSection:Keybind({
    Title = "Dash Backwards",
    Value = KeybindDefaults.BrakeDashBack,
    Callback = function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local seat = hum and hum.SeatPart
        if seat then
            triggerDash(-seat.CFrame.LookVector)
        end
    end
})

-- Listen for manual brake pedal (S key / Down Arrow) for sudden brake dash trigger
local brakeKeys = {
    [Enum.KeyCode.S] = true,
    [Enum.KeyCode.Down] = true
}

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if Config.BrakeDashEnabled and brakeKeys[input.KeyCode] then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local seat = hum and hum.SeatPart
        if seat and seat:IsA("VehicleSeat") and seat.AssemblyLinearVelocity.Magnitude > 30 then
            -- Dash backwards if braking at high speed
            triggerDash(-seat.CFrame.LookVector)
        end
    end
end)

local ControlBindsSection = KeybindTab:Section({
    Title = "Rotation Keys Configuration"
})

Keybinds.PitchDown = ControlBindsSection:Keybind({
    Title = "Pitch Down (Nose Down)",
    Value = KeybindDefaults.PitchDown,
})

Keybinds.PitchUp = ControlBindsSection:Keybind({
    Title = "Pitch Up (Nose Up)",
    Value = KeybindDefaults.PitchUp,
})

Keybinds.YawLeft = ControlBindsSection:Keybind({
    Title = "Yaw Left (Spin Left)",
    Value = KeybindDefaults.YawLeft,
})

Keybinds.YawRight = ControlBindsSection:Keybind({
    Title = "Yaw Right (Spin Right)",
    Value = KeybindDefaults.YawRight,
})

Keybinds.RollLeft = ControlBindsSection:Keybind({
    Title = "Roll Left (Barrel Roll Left)",
    Value = KeybindDefaults.RollLeft,
})

Keybinds.RollRight = ControlBindsSection:Keybind({
    Title = "Roll Right (Barrel Roll Right)",
    Value = KeybindDefaults.RollRight,
})

local ConfigSection = ConfigTab:Section({
    Title = "Config Management"
})

local ConfigNameInput = ConfigSection:Input({
    Title = "Config Name",
    Placeholder = "Enter config name...",
    Value = "Default"
})

local ConfigDropdown

local function refreshConfigList()
    local configs = listConfigsCustom()
    if ConfigDropdown then
        ConfigDropdown:Refresh(configs)
    end
end

ConfigSection:Button({
    Title = "Save Config",
    Callback = function()
        local name = ConfigNameInput.Value
        if name and name ~= "" then
            local success, err = saveConfigCustom(name)
            if success then
                refreshConfigList()
            else
                warn("Save error:", err)
            end
        end
    end
})

ConfigSection:Button({
    Title = "Load Config",
    Callback = function()
        local name = ConfigNameInput.Value
        if name and name ~= "" then
            local success, err = loadConfigCustom(name)
            if not success then
                warn("Load error:", err)
            end
        end
    end
})

ConfigSection:Button({
    Title = "Delete Config",
    Callback = function()
        local name = ConfigNameInput.Value
        if name and name ~= "" then
            deleteConfigCustom(name)
            refreshConfigList()
        end
    end
})

ConfigDropdown = ConfigSection:Dropdown({
    Title = "Saved Configs",
    Values = listConfigsCustom(),
    Callback = function(selected)
        ConfigNameInput:Set(selected)
    end
})

pcall(function()
    loadConfigCustom("Default")
end)
