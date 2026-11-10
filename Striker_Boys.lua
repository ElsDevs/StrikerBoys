-- Striker Boys | Cloude UI | Player ESP + Car ESP + Teleports

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local V2, V3, CFnew = Vector2.new, Vector3.new, CFrame.new
local mclamp, mfloor, mmax, mmin = math.clamp, math.floor, math.max, math.min

-- Re-executing: tear down the previous run before building a new one.
if getgenv().StrikerBoys_Unload then
    pcall(getgenv().StrikerBoys_Unload)
end

local Connections = {}
local Running = true

table.insert(Connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    CurrentCamera = workspace.CurrentCamera
end))

----------------------------------------------------------------
-- Library (Cloude)
----------------------------------------------------------------
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/gut7899/Other/refs/heads/main/Cloude/Library.lua"))()

-- Assigned at the bottom of the script. Hooked here (not at the end) so the
-- settings tab "Unload" button, the End key, and re-executing all clean up,
-- even if something later in the script fails to load.
local OnUnload
do
    local OrigExit = Library.Exit
    Library.Exit = function(self)
        if OnUnload then pcall(OnUnload) end
        if OrigExit then pcall(OrigExit, self) end
    end
end

local Window
local function Flag(name) return Library.Flags[name] end
local function FlagColor(name, fallback)
    local f = Library.Flags[name]
    if f and f.Color then return f.Color, f.Alpha or 1 end
    return fallback or Color3.new(1, 1, 1), 1
end

----------------------------------------------------------------
-- Safe call
----------------------------------------------------------------
local ErrTimes = {}
local function Safe(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and os.clock() - (ErrTimes[name] or 0) > 5 then
        ErrTimes[name] = os.clock()
        warn("[Striker Boys] " .. name .. ": " .. tostring(err))
    end
end

local function RemoveDrawing(d) pcall(function() d:Remove() end) end

----------------------------------------------------------------
-- Health read
----------------------------------------------------------------
local function GetHealth(character, hum)
    local HealthObj = character:FindFirstChild("Health")
    if HealthObj and HealthObj:IsA("ValueBase") then return tonumber(HealthObj.Value) end
    local Attr = character:GetAttribute("Health")
    if Attr ~= nil then return tonumber(Attr) end
    if hum then return hum.Health end
    return nil
end

----------------------------------------------------------------
-- Distance (meters, same unit the ESP text shows)
----------------------------------------------------------------
local STUDS_PER_METER = 3.33
local MAX_DIST_UNLIMITED = 2000

local function GetOrigin()
    local char = LocalPlayer.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
    return root and root.Position or CurrentCamera.CFrame.Position
end

local function MetersTo(pos)
    return (pos - GetOrigin()).Magnitude / STUDS_PER_METER
end

local function WithinRange(pos, flagName)
    local maxM = Flag(flagName)
    if type(maxM) ~= "number" or maxM >= MAX_DIST_UNLIMITED then return true end
    return MetersTo(pos) <= maxM
end

----------------------------------------------------------------
-- Player ESP (Drawing API)
----------------------------------------------------------------
local ESP = { Players = {} }
do
    local BOX3_HALF = V3(1.25, 2.75, 1.25)
    local BOX3_OFFSETS = {
        V3(-BOX3_HALF.X, -BOX3_HALF.Y, -BOX3_HALF.Z), V3( BOX3_HALF.X, -BOX3_HALF.Y, -BOX3_HALF.Z),
        V3( BOX3_HALF.X, -BOX3_HALF.Y,  BOX3_HALF.Z), V3(-BOX3_HALF.X, -BOX3_HALF.Y,  BOX3_HALF.Z),
        V3(-BOX3_HALF.X,  BOX3_HALF.Y, -BOX3_HALF.Z), V3( BOX3_HALF.X,  BOX3_HALF.Y, -BOX3_HALF.Z),
        V3( BOX3_HALF.X,  BOX3_HALF.Y,  BOX3_HALF.Z), V3(-BOX3_HALF.X,  BOX3_HALF.Y,  BOX3_HALF.Z),
    }
    local BOX3_EDGES = {
        {1,2},{2,3},{3,4},{4,1}, {5,6},{6,7},{7,8},{8,5}, {1,5},{2,6},{3,7},{4,8},
    }

    local function MakeLine()
        local l = Drawing.new("Line")
        l.Thickness = 1; l.Transparency = 1; l.Visible = false; l.Color = Color3.new(1, 1, 1)
        return l
    end

    function ESP.Players:Make(player)
        if player == LocalPlayer then return end
        local Entry = { Drawings = {}, Corners = {}, D3 = {} }

        local Name = Drawing.new("Text")
        Name.Center = true; Name.Outline = true; Name.Size = 13
        Name.Color = Color3.new(1, 1, 1); Name.Text = player.Name

        local OL = { Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line") }
        for i = 1, 4 do
            OL[i].Thickness = 1; OL[i].Transparency = 1; OL[i].Visible = false
            OL[i].Color = Color3.new(0, 0, 0)
        end

        local Box = Drawing.new("Square")
        Box.Thickness = 1; Box.Filled = false; Box.Visible = false; Box.ZIndex = 2
        Box.Color = Color3.new(1, 1, 1)

        for i = 1, 8 do Entry.Corners[i] = MakeLine() end
        for i = 1, 12 do Entry.D3[i] = MakeLine() end

        local Weapon = Drawing.new("Text")
        Weapon.Center = true; Weapon.Outline = true; Weapon.Size = 13
        Weapon.Color = Color3.new(1, 1, 1); Weapon.Text = "Hands"

        local Distance = Drawing.new("Text")
        Distance.Center = true; Distance.Outline = true; Distance.Size = 13
        Distance.Color = Color3.new(1, 1, 1)

        local HealthBG = Drawing.new("Square")
        HealthBG.Filled = true; HealthBG.Color = Color3.new(0, 0, 0); HealthBG.Transparency = 0.6

        local HealthFill = Drawing.new("Square")
        HealthFill.Filled = true; HealthFill.ZIndex = HealthBG.ZIndex + 1

        local HealthText = Drawing.new("Text")
        HealthText.Center = true; HealthText.Outline = true; HealthText.Size = 13
        HealthText.ZIndex = HealthBG.ZIndex + 2

        local ActiveCar = Drawing.new("Text")
        ActiveCar.Center = true; ActiveCar.Outline = true; ActiveCar.Size = 13
        ActiveCar.Color = Color3.new(1, 1, 1); ActiveCar.Visible = false

        local Status = Drawing.new("Text")
        Status.Center = true; Status.Outline = true; Status.Size = 13
        Status.Color = Color3.new(1, 1, 1); Status.Visible = false

        local function hideAll()
            for _, drawing in pairs(Entry.Drawings) do drawing.Visible = false end
            for _, l in ipairs(Entry.Corners) do l.Visible = false end
            for _, l in ipairs(Entry.D3) do l.Visible = false end
        end

        function Entry.Update(self)
            local Character = player.Character
            local Head = Character and Character:FindFirstChild("Head")
            local LeftFoot = Character and (Character:FindFirstChild("LeftFoot") or Character:FindFirstChild("Left Leg"))

            if not Flag("player_visuals") or not Head or not LeftFoot then
                hideAll(); return
            end

            local Tool = Character:FindFirstChildOfClass("Tool")

            if not WithinRange(Head.Position, "player_maxdist") then
                hideAll(); return
            end

            local hSize, fSize = Head.Size.Y * 0.5, LeftFoot.Size.Y * 0.5
            local Top3, OnScreen = CurrentCamera:WorldToViewportPoint(Head.Position + V3(0, hSize, 0))
            local Bot3 = CurrentCamera:WorldToViewportPoint(LeftFoot.Position - V3(0, fSize, 0))

            local Height = Bot3.Y - Top3.Y + 8
            local Width = Height * 0.65
            local BoxPos = V2(Top3.X - (Width * 0.5), Top3.Y - 8)
            local BoxSize = V2(Width, Height)

            local boxMode = Flag("player_box_mode") or "Full"
            local boxOn = OnScreen and Flag("player_box")
            local boxCol, boxA = FlagColor("player_box_col", Color3.new(1, 1, 1))
            local boxOutCol, boxOutA = FlagColor("player_box_outline_col", Color3.new(0, 0, 0))
            local outlineOn = Flag("player_box_outline")
            local boxThick = Flag("player_box_thickness") or 1

            local wantFull = boxOn and boxMode == "Full"
            local wantFilled = boxOn and boxMode == "Filled"
            local wantCorner = boxOn and boxMode == "Corner"
            local want3D = boxOn and boxMode == "3D"

            Box.Visible = wantFull or wantFilled
            if Box.Visible then
                Box.Color = boxCol; Box.Transparency = boxA
                Box.Filled = wantFilled; Box.Thickness = boxThick
                Box.Size = BoxSize; Box.Position = BoxPos
            end

            local showOL = (wantFull or wantFilled) and outlineOn
            if showOL then
                local x1, y1 = BoxPos.X - 1, BoxPos.Y - 1
                local x2, y2 = BoxPos.X + BoxSize.X + 1, BoxPos.Y + BoxSize.Y + 1
                local ol = OL[1]; ol.From = V2(x1, y1); ol.To = V2(x2, y1); ol.Color = boxOutCol; ol.Transparency = boxOutA; ol.Visible = true
                ol = OL[2]; ol.From = V2(x2, y1); ol.To = V2(x2, y2); ol.Color = boxOutCol; ol.Transparency = boxOutA; ol.Visible = true
                ol = OL[3]; ol.From = V2(x2, y2); ol.To = V2(x1, y2); ol.Color = boxOutCol; ol.Transparency = boxOutA; ol.Visible = true
                ol = OL[4]; ol.From = V2(x1, y2); ol.To = V2(x1, y1); ol.Color = boxOutCol; ol.Transparency = boxOutA; ol.Visible = true
            else
                OL[1].Visible = false; OL[2].Visible = false; OL[3].Visible = false; OL[4].Visible = false
            end

            local corners = Entry.Corners
            if wantCorner then
                local L = mmax(4, mmin(BoxSize.X, BoxSize.Y) * 0.25)
                local x1, y1 = BoxPos.X, BoxPos.Y
                local x2, y2 = x1 + BoxSize.X, y1 + BoxSize.Y
                local th = boxThick + 1
                local c = corners[1]; c.From = V2(x1, y1); c.To = V2(x1 + L, y1); c.Color = boxCol; c.Transparency = boxA; c.Thickness = th; c.Visible = true
                c = corners[2]; c.From = V2(x1, y1); c.To = V2(x1, y1 + L); c.Color = boxCol; c.Transparency = boxA; c.Thickness = th; c.Visible = true
                c = corners[3]; c.From = V2(x2, y1); c.To = V2(x2 - L, y1); c.Color = boxCol; c.Transparency = boxA; c.Thickness = th; c.Visible = true
                c = corners[4]; c.From = V2(x2, y1); c.To = V2(x2, y1 + L); c.Color = boxCol; c.Transparency = boxA; c.Thickness = th; c.Visible = true
                c = corners[5]; c.From = V2(x1, y2); c.To = V2(x1 + L, y2); c.Color = boxCol; c.Transparency = boxA; c.Thickness = th; c.Visible = true
                c = corners[6]; c.From = V2(x1, y2); c.To = V2(x1, y2 - L); c.Color = boxCol; c.Transparency = boxA; c.Thickness = th; c.Visible = true
                c = corners[7]; c.From = V2(x2, y2); c.To = V2(x2 - L, y2); c.Color = boxCol; c.Transparency = boxA; c.Thickness = th; c.Visible = true
                c = corners[8]; c.From = V2(x2, y2); c.To = V2(x2, y2 - L); c.Color = boxCol; c.Transparency = boxA; c.Thickness = th; c.Visible = true
            else
                for i = 1, 8 do corners[i].Visible = false end
            end

            if want3D and Character:FindFirstChild("HumanoidRootPart") then
                local cf = Character.HumanoidRootPart.CFrame
                local corners3 = Entry._corners3 or {}
                Entry._corners3 = corners3
                local allOnScreen = true
                for i = 1, 8 do
                    local p, os_ = CurrentCamera:WorldToViewportPoint(cf * BOX3_OFFSETS[i])
                    corners3[i] = V2(p.X, p.Y)
                    if not os_ then allOnScreen = false end
                end
                for i, e in ipairs(BOX3_EDGES) do
                    local L2 = Entry.D3[i]
                    L2.From = corners3[e[1]]; L2.To = corners3[e[2]]
                    L2.Color = boxCol; L2.Transparency = boxA; L2.Thickness = boxThick
                    L2.Visible = allOnScreen
                end
            else
                for _, l in ipairs(Entry.D3) do l.Visible = false end
            end

            local halfW = BoxSize.X * 0.5
            Name.Visible = OnScreen and Flag("player_name")
            if Name.Visible then
                Name.Color, Name.Transparency = FlagColor("player_name_col")
                Name.Position = BoxPos + V2(halfW, -Name.TextBounds.Y)
                Name.Text = player.Name
            end

            Weapon.Visible = OnScreen and Flag("player_weapon")
            if Weapon.Visible then
                Weapon.Color, Weapon.Transparency = FlagColor("player_weapon_col")
                Weapon.Position = BoxPos + V2(halfW, BoxSize.Y)
                Weapon.Text = Tool and Tool.Name or "Hands"
            end

            if OnScreen and Flag("player_distance") then
                Distance.Visible = true
                Distance.Color, Distance.Transparency = FlagColor("player_distance_col")
                Distance.Text = mfloor(MetersTo(Head.Position)) .. "m"
                Distance.Position = BoxPos + V2(halfW, BoxSize.Y + Weapon.TextBounds.Y + 2)
            else
                Distance.Visible = false
            end

            local hum = Character:FindFirstChildOfClass("Humanoid")
            local Health = GetHealth(Character, hum)
            local ShowBar = OnScreen and Flag("player_health") and Health ~= nil
            if ShowBar then
                local Pct = mclamp(Health / (Flag("player_maxhealth") or 100), 0, 1)
                local BarX = BoxPos.X - 6
                local FillH = Height * Pct
                HealthBG.Visible = true
                HealthBG.Position = V2(BarX - 1, BoxPos.Y - 1)
                HealthBG.Size = V2(5, Height + 2)
                HealthFill.Visible = true
                HealthFill.Color = Flag("player_health_low_col").Color:Lerp(Flag("player_health_col").Color, Pct)
                HealthFill.Position = V2(BarX, BoxPos.Y + Height - FillH)
                HealthFill.Size = V2(3, FillH)
                HealthText.Visible = Flag("player_health_text")
                if HealthText.Visible then
                    HealthText.Text = tostring(mfloor(Health))
                    HealthText.Color, HealthText.Transparency = FlagColor("player_health_text_col")
                    HealthText.Position = V2(
                        BarX - 3 - (HealthText.TextBounds.X * 0.5),
                        BoxPos.Y + (Height * 0.5) - (HealthText.TextBounds.Y * 0.5)
                    )
                end
            else
                HealthBG.Visible = false; HealthFill.Visible = false; HealthText.Visible = false
            end

            -- Below the box: active car name, then status (wanted / jailed)
            local stackY = BoxSize.Y + 2
            if Weapon.Visible then stackY = stackY + Weapon.TextBounds.Y end
            if Distance.Visible then stackY = stackY + Distance.TextBounds.Y end

            local activeCar = player:GetAttribute("CarGame_ActiveCar")
            ActiveCar.Visible = OnScreen and Flag("player_activecar") and activeCar ~= nil and activeCar ~= ""
            if ActiveCar.Visible then
                ActiveCar.Color, ActiveCar.Transparency = FlagColor("player_activecar_col")
                ActiveCar.Text = tostring(activeCar)
                ActiveCar.Position = BoxPos + V2(halfW, stackY)
                stackY = stackY + ActiveCar.TextBounds.Y
            end

            if OnScreen and Flag("player_status") then
                local jailed = player:GetAttribute("CarGame_Jailed")
                local heat = tonumber(player:GetAttribute("Heat")) or 0
                local charges = player:GetAttribute("CarGame_Charges")
                local parts, col = {}, nil
                if jailed then
                    local ends = tonumber(player:GetAttribute("CarGame_JailEndsAt"))
                    if ends then
                        local secs = mmax(0, mfloor(ends - os.time()))
                        parts[#parts + 1] = "JAILED " .. mfloor(secs / 60) .. ":" .. string.format("%02d", secs % 60)
                    else
                        parts[#parts + 1] = "JAILED"
                    end
                    col = Color3.fromRGB(120, 120, 255)
                elseif heat > 0 or (charges and charges ~= "") then
                    parts[#parts + 1] = "WANTED (" .. heat .. ")"
                    col = Color3.fromRGB(255, 80, 80)
                end
                if #parts > 0 then
                    Status.Visible = true
                    local _, trans = FlagColor("player_status_col")
                    Status.Color = Flag("player_status_use_custom") and FlagColor("player_status_col") or col
                    Status.Transparency = trans
                    Status.Text = table.concat(parts, " ")
                    Status.Position = BoxPos + V2(halfW, stackY)
                else
                    Status.Visible = false
                end
            else
                Status.Visible = false
            end
        end

        table.insert(Entry.Drawings, Name)
        table.insert(Entry.Drawings, Box)
        for i = 1, 4 do table.insert(Entry.Drawings, OL[i]) end
        table.insert(Entry.Drawings, Weapon)
        table.insert(Entry.Drawings, Distance)
        table.insert(Entry.Drawings, HealthBG)
        table.insert(Entry.Drawings, HealthFill)
        table.insert(Entry.Drawings, HealthText)
        table.insert(Entry.Drawings, ActiveCar)
        table.insert(Entry.Drawings, Status)
        for _, l in ipairs(Entry.Corners) do table.insert(Entry.Drawings, l) end
        for _, l in ipairs(Entry.D3) do table.insert(Entry.Drawings, l) end
        ESP.Players[player] = Entry
    end

    function ESP.Players:Remove(player)
        local Entry = ESP.Players[player]
        if not Entry then return end
        for _, drawing in pairs(Entry.Drawings) do RemoveDrawing(drawing) end
        ESP.Players[player] = nil
    end
end

----------------------------------------------------------------
-- Car ESP (Drawing API, distance + name)
----------------------------------------------------------------
local CarGameWorld = Workspace:WaitForChild("CarGame_World")
local TargetsFolder = CarGameWorld:WaitForChild("Targets")
local PlugModel = CarGameWorld:FindFirstChild("The Plug")

-- Where the object physically is right now. The game's car models have no
-- PrimaryPart, so GetPivot() returns their spawn spot even after they've been
-- driven across the map - read a real part instead and only use the pivot last.
local function GetModelPivot(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model.Position end
    local part = model:FindFirstChild("DriveSeat")
        or model:FindFirstChild("HumanoidRootPart")
        or (model:IsA("Model") and model.PrimaryPart)
        or model:FindFirstChildWhichIsA("BasePart", true)
    if part and part:IsA("BasePart") then return part.Position end
    local ok, cf = pcall(function() return model:GetPivot() end)
    return ok and cf and cf.Position or nil
end

local CarESP = { Entries = {} }

function CarESP:Make(model)
    if self.Entries[model] then return end
    local NameText = Drawing.new("Text")
    NameText.Center = true; NameText.Outline = true; NameText.Size = 13
    NameText.Color = Color3.new(1, 1, 1); NameText.Visible = false; NameText.Text = model.Name

    local DistText = Drawing.new("Text")
    DistText.Center = true; DistText.Outline = true; DistText.Size = 13
    DistText.Color = Color3.new(1, 1, 1); DistText.Visible = false

    self.Entries[model] = { Name = NameText, Dist = DistText }
end

function CarESP:Remove(model)
    local e = self.Entries[model]
    if not e then return end
    RemoveDrawing(e.Name); RemoveDrawing(e.Dist)
    self.Entries[model] = nil
end

function CarESP:Update()
    local enabled = Flag("car_esp")
    local showName = Flag("car_esp_name")
    local showDist = Flag("car_esp_distance")
    local nameCol, nameA = FlagColor("car_esp_name_col", Color3.new(1, 1, 1))
    local distCol, distA = FlagColor("car_esp_distance_col", Color3.new(1, 1, 1))

    for model, e in pairs(self.Entries) do
        if not model.Parent or not enabled then
            e.Name.Visible = false; e.Dist.Visible = false
        else
            local pos = GetModelPivot(model)
            if not pos or not WithinRange(pos, "car_maxdist") then
                e.Name.Visible = false; e.Dist.Visible = false
            else
                local vp, onScreen = CurrentCamera:WorldToViewportPoint(pos)
                if not onScreen then
                    e.Name.Visible = false; e.Dist.Visible = false
                else
                    e.Name.Visible = showName
                    if showName then
                        e.Name.Color, e.Name.Transparency = nameCol, nameA
                        e.Name.Text = model.Name
                        e.Name.Position = V2(vp.X, vp.Y)
                    end
                    e.Dist.Visible = showDist
                    if e.Dist.Visible then
                        local d = mfloor(MetersTo(pos))
                        e.Dist.Color, e.Dist.Transparency = distCol, distA
                        e.Dist.Text = d .. "m"
                        e.Dist.Position = V2(vp.X, vp.Y + (showName and e.Name.TextBounds.Y or 0))
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Teleport helpers
----------------------------------------------------------------
local CHOPSHOP_TP = V3(64.47, 10.59, -2760.69)
local MOUNTAIN_TP = V3(1334.81, 253.62, -2942.09) -- safe spot away from the cops

-- On-foot teleport. If you're sitting in any seat, you're welded to it and
-- moving only your character gets dragged back/sideways by the seat, so we
-- stand up first and wait for the weld to let go. Yields - call from a thread.
local function TeleportTo(pos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false, "no character" end
    if hum.SeatPart then
        hum.Sit = false
        local t0 = os.clock()
        while hum.SeatPart and os.clock() - t0 < 1 do task.wait() end
        if hum.SeatPart then return false, "couldn't leave seat" end
    end
    hrp.CFrame = typeof(pos) == "CFrame" and pos or CFnew(pos)
    hrp.AssemblyLinearVelocity = Vector3.zero
    return true
end

-- Lands you beside the driver door (not on the roof), on the ground, facing the car.
local function TeleportToCar(model)
    local seat = model:FindFirstChild("DriveSeat")
    if not (seat and seat:IsA("BasePart")) then
        local pos = GetModelPivot(model)
        if not pos then return false, "no position" end
        return TeleportTo(pos + V3(0, 6, 0))
    end
    local side = model:GetAttribute("CarGame_DriverSide") == "R" and 1 or -1
    local look = V3(seat.CFrame.LookVector.X, 0, seat.CFrame.LookVector.Z)
    local yaw = look.Magnitude > 0.05 and CFrame.lookAt(seat.Position, seat.Position + look) or CFnew(seat.Position)
    local beside = (yaw * CFnew(side * 5, 0, 0)).Position

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { model, LocalPlayer.Character }
    local hit = workspace:Raycast(beside + V3(0, 10, 0), V3(0, -40, 0), params)
    local y = (hit and hit.Position.Y or seat.Position.Y) + 3
    local pos = V3(beside.X, y, beside.Z)
    return TeleportTo(CFrame.lookAt(pos, V3(seat.Position.X, y, seat.Position.Z)))
end

----------------------------------------------------------------
-- Car list (dropdown + car ESP sync)
-- Picks are pinned to the car's CarGame_CarId, not its label, so the same
-- car stays selected even when labels shift. The library keys options by
-- text, so duplicate names get "#2" etc. to avoid ghost entries.
----------------------------------------------------------------
local CarList = {
    Map = {},            -- label -> car model, for the labels currently shown
    Signature = nil,     -- labels currently shown in the dropdown
    SelectedId = nil,    -- CarGame_CarId of the picked car
    Dropdown = nil,
    Pending = false,
    FallbackIds = setmetatable({}, { __mode = "k" }),
    FallbackCounter = 0,
}

local function GetTargets()
    local f = CarGameWorld:FindFirstChild("Targets")
    if f then TargetsFolder = f end
    return TargetsFolder
end

function CarList:IdOf(m)
    local id = m:GetAttribute("CarGame_CarId")
    if id then return tostring(id) end
    if not self.FallbackIds[m] then
        self.FallbackCounter = self.FallbackCounter + 1
        self.FallbackIds[m] = "local-" .. self.FallbackCounter
    end
    return self.FallbackIds[m]
end

local function CarLabelName(m)
    local dn = m:GetAttribute("DisplayName")
    return (type(dn) == "string" and dn ~= "") and dn or m.Name
end

local function CarIsDriven(m)
    local seat = m:FindFirstChild("DriveSeat")
    return seat ~= nil and seat:IsA("VehicleSeat") and seat.Occupant ~= nil
end

function CarList:Build()
    local folder = GetTargets()
    local hideDriven = Flag("car_tp_hide_driven")
    local models = {}
    for _, m in ipairs(folder and folder:GetChildren() or {}) do
        if m:IsA("Model") and not (hideDriven and CarIsDriven(m)) then
            models[#models + 1] = m
        end
    end
    -- Name, then car id: stable order so "#2" doesn't jump between refreshes.
    table.sort(models, function(a, b)
        local na, nb = CarLabelName(a), CarLabelName(b)
        if na ~= nb then return na < nb end
        return self:IdOf(a) < self:IdOf(b)
    end)
    local labels, map, counts = {}, {}, {}
    for _, m in ipairs(models) do
        local name = CarLabelName(m)
        counts[name] = (counts[name] or 0) + 1
        local label = counts[name] == 1 and name or (name .. " #" .. counts[name])
        labels[#labels + 1] = label
        map[label] = m
    end
    if #labels == 0 then labels[1] = "<none>" end
    return labels, map
end

-- Dropdown callback: remember which car was picked by id.
function CarList:OnPick(label)
    local m = label and self.Map[label]
    self.SelectedId = m and self:IdOf(m) or nil
end

function CarList:SyncESP()
    local folder = GetTargets()
    if folder then
        for _, m in ipairs(folder:GetChildren()) do CarESP:Make(m) end
    end
    for m in pairs(CarESP.Entries) do
        if not folder or m.Parent ~= folder then CarESP:Remove(m) end
    end
end

-- Clears the pick in both our state and the library's (option IsSelected
-- included - otherwise the next click on it toggles it off instead of on).
function CarList:ClearPick()
    local dd = self.Dropdown
    self.SelectedId = nil
    if not dd then return end
    dd.Value = nil
    Library.Flags["car_tp_pick"] = nil
    for _, opt in pairs(dd.Options) do
        opt.IsSelected = false
        pcall(function() opt:ToggleState("Inactive") end)
    end
    pcall(function() dd.Items["Value"].Instance.Text = "..." end)
end

function CarList:LabelForId(map, id)
    if not id then return nil end
    for label, m in pairs(map) do
        if self:IdOf(m) == id then return label end
    end
    return nil
end

function CarList:Refresh(force)
    self:SyncESP()
    local dd = self.Dropdown
    if not dd then return end
    local labels, map = self:Build()
    local sig = table.concat(labels, "\0")
    if not force then
        if sig == self.Signature then
            -- Same labels, but a car may have despawned and an identical one
            -- respawned under the same label: drop a pick that no longer exists.
            self.Map = map
            if self.SelectedId and not self:LabelForId(map, self.SelectedId) then
                self:ClearPick()
            end
            return
        end
        -- Never rebuild under the cursor; the 2s poll retries after it closes.
        if dd.IsOpen then return end
    end
    self.Signature = sig
    self.Map = map

    local keepLabel = self:LabelForId(map, self.SelectedId)
    dd:Refresh(labels)
    if keepLabel then
        dd:Set(keepLabel) -- re-highlight; also re-fires OnPick with the same id
    else
        self:ClearPick()
    end
end

-- Batches bursts of ChildAdded/ChildRemoved into one refresh.
function CarList:Schedule()
    if self.Pending then return end
    self.Pending = true
    task.delay(0.25, function()
        self.Pending = false
        if Running then Safe("CarListRefresh", function() self:Refresh(false) end) end
    end)
end

-- Looks the picked car up live in the folder, never from a cached reference.
function CarList:Selected()
    local id = self.SelectedId
    local folder = GetTargets()
    if not id or not folder then return nil end
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and self:IdOf(m) == id then return m end
    end
    return nil
end

----------------------------------------------------------------
-- Movement (walk speed / jump power / noclip / inf jump)
----------------------------------------------------------------
local Movement = {
    Hum = nil,
    Char = nil,
    Orig = nil,          -- humanoid values before we touched them
    WSApplied = false,
    JPApplied = false,
    NoclipParts = {},    -- parts we turned CanCollide off on
}

local function BindCharacter(char)
    Movement.Char = char
    Movement.Hum = nil
    Movement.Orig = nil
    Movement.WSApplied, Movement.JPApplied = false, false
    table.clear(Movement.NoclipParts)
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        if hum and Movement.Char == char then Movement.Hum = hum end
    end)
end

if LocalPlayer.Character then BindCharacter(LocalPlayer.Character) end
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(BindCharacter))

function Movement:Step()
    local hum = self.Hum
    if not hum or not hum.Parent then return end
    if not self.Orig then
        self.Orig = {
            WalkSpeed = hum.WalkSpeed,
            JumpPower = hum.JumpPower,
            JumpHeight = hum.JumpHeight,
            UseJumpPower = hum.UseJumpPower,
        }
    end

    if Flag("mv_ws_enabled") then
        hum.WalkSpeed = Flag("mv_ws") or 16
        self.WSApplied = true
    elseif self.WSApplied then
        hum.WalkSpeed = self.Orig.WalkSpeed
        self.WSApplied = false
    end

    if Flag("mv_jp_enabled") then
        local jp = Flag("mv_jp") or 50
        hum.UseJumpPower = true
        hum.JumpPower = jp
        self.JPApplied = true
    elseif self.JPApplied then
        hum.UseJumpPower = self.Orig.UseJumpPower
        hum.JumpPower = self.Orig.JumpPower
        hum.JumpHeight = self.Orig.JumpHeight
        self.JPApplied = false
    end
end

function Movement:RestoreNoclip()
    for p in pairs(self.NoclipParts) do
        if p.Parent then p.CanCollide = true end
    end
    table.clear(self.NoclipParts)
end

function Movement:Restore()
    self:RestoreNoclip()
    local hum, orig = self.Hum, self.Orig
    if hum and hum.Parent and orig then
        if self.WSApplied then hum.WalkSpeed = orig.WalkSpeed end
        if self.JPApplied then
            hum.UseJumpPower = orig.UseJumpPower
            hum.JumpPower = orig.JumpPower
            hum.JumpHeight = orig.JumpHeight
        end
    end
    self.WSApplied, self.JPApplied = false, false
end

local function NoclipStep()
    if not Flag("mv_noclip") then
        if next(Movement.NoclipParts) then Movement:RestoreNoclip() end
        return
    end
    local char = Movement.Char
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then
            p.CanCollide = false
            Movement.NoclipParts[p] = true
        end
    end
end

table.insert(Connections, UserInputService.JumpRequest:Connect(function()
    if Flag("mv_infjump") and Movement.Hum then
        Movement.Hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

----------------------------------------------------------------
-- Status HUD (self attributes)
----------------------------------------------------------------
local StatusHUD = {}
do
    local lines = {}
    local function makeLine()
        local t = Drawing.new("Text")
        t.Outline = true; t.Size = 15; t.Color = Color3.new(1, 1, 1)
        t.Visible = false
        return t
    end
    for i = 1, 6 do lines[i] = makeLine() end

    function StatusHUD:Destroy()
        for _, l in ipairs(lines) do RemoveDrawing(l) end
        table.clear(lines)
    end

    local LABELS = {
        { key = "Heat",            fmt = function(v) return "Heat: " .. mfloor(tonumber(v) or 0) end,
          col = function(v) local n = tonumber(v) or 0 return n >= 80 and Color3.fromRGB(255, 70, 70) or n >= 40 and Color3.fromRGB(255, 180, 70) or Color3.new(1, 1, 1) end },
        { key = "Hunger",          fmt = function(v) return "Hunger: " .. mfloor(tonumber(v) or 0) .. "%" end,
          col = function(v) local n = tonumber(v) or 100 return n <= 20 and Color3.fromRGB(255, 120, 70) or Color3.new(1, 1, 1) end },
        { key = "CarGame_Stamina", fmt = function(v) return "Stamina: " .. mfloor(tonumber(v) or 0) end,
          col = function() return Color3.fromRGB(180, 220, 255) end },
        { key = "BustProgress",    fmt = function(v) return "Bust: " .. mfloor((tonumber(v) or 0) * 100) .. "%" end,
          col = function(v) local n = tonumber(v) or 0 return n > 0 and Color3.fromRGB(255, 80, 80) or Color3.new(1, 1, 1) end,
          hideIfZero = true },
    }

    function StatusHUD:Update()
        if #lines == 0 then return end
        local on = Flag("status_hud")
        if not on then
            for _, l in ipairs(lines) do l.Visible = false end
            return
        end
        local x = Flag("status_hud_x") or 20
        local y = Flag("status_hud_y") or 120
        local idx = 1

        -- Attribute rows
        for _, row in ipairs(LABELS) do
            local v = LocalPlayer:GetAttribute(row.key)
            local show = v ~= nil
            if show and row.hideIfZero and (tonumber(v) or 0) <= 0 then show = false end
            local line = lines[idx]
            line.Visible = show
            if show then
                line.Text = row.fmt(v)
                line.Color = row.col(v)
                line.Position = V2(x, y + (idx - 1) * 18)
                idx = idx + 1
            end
        end

        -- Jail time left
        local jailed = LocalPlayer:GetAttribute("CarGame_Jailed")
        if jailed then
            local ends = tonumber(LocalPlayer:GetAttribute("CarGame_JailEndsAt"))
            local secs = ends and mmax(0, mfloor(ends - os.time())) or 0
            local line = lines[idx]
            line.Visible = true
            line.Text = string.format("JAIL: %d:%02d", mfloor(secs / 60), secs % 60)
            line.Color = Color3.fromRGB(120, 120, 255)
            line.Position = V2(x, y + (idx - 1) * 18)
            idx = idx + 1
        end

        -- Impound timer
        local imp = tonumber(LocalPlayer:GetAttribute("CarGame_ImpoundUntil"))
        if imp and imp > os.time() then
            local secs = mfloor(imp - os.time())
            local line = lines[idx]
            line.Visible = true
            line.Text = string.format("IMPOUND: %d:%02d", mfloor(secs / 60), secs % 60)
            line.Color = Color3.fromRGB(255, 180, 70)
            line.Position = V2(x, y + (idx - 1) * 18)
            idx = idx + 1
        end

        -- Hide unused rows
        for i = idx, #lines do lines[i].Visible = false end
    end
end

----------------------------------------------------------------
-- Car Boost (torque + top speed, written to the car's attributes
-- while seated in its DriveSeat; chassis reads these per-frame)
----------------------------------------------------------------
local CarBoost = { CurrentCar = nil, OrigTorque = nil }

local function CurrentDrivenCar()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if seat and seat.Name == "DriveSeat" and seat.Parent and seat.Parent:GetAttribute("CarGame_Car") then
        return seat.Parent
    end
    return nil
end

function CarBoost:Restore()
    local car = self.CurrentCar
    if not car or not car.Parent then self.CurrentCar = nil; self.OrigTorque = nil; return end
    pcall(function() car:SetAttribute("CarGame_TorqueMult", self.OrigTorque) end)
    self.CurrentCar = nil; self.OrigTorque = nil
end

-- ChassisDrive (ReplicatedStorage.CarGame.ChassisDrive) reads
-- car:GetAttribute("CarGame_TorqueMult") live every physics step and uses it
-- straight as the torque multiplier (CarGame cars). Stock varies per car (e.g.
-- the police Explorer is 15), so we multiply the STOCK value rather than write
-- an absolute - writing a flat number below stock was why boost slowed the car.
-- TopSpeedSPS is a no-op on these cars (the chassis disables that cap when the
-- tune has a CarGame section), so more torque is what raises accel AND top end.
function CarBoost:Update()
    local car = CurrentDrivenCar()
    if car ~= self.CurrentCar then
        self:Restore()
        if car and Flag("boost_enabled") then
            self.CurrentCar = car
            self.OrigTorque = car:GetAttribute("CarGame_TorqueMult")
        end
    end
    if not Flag("boost_enabled") then
        if self.CurrentCar then self:Restore() end
        return
    end
    if not car then return end
    if self.CurrentCar ~= car then
        self.CurrentCar = car
        self.OrigTorque = car:GetAttribute("CarGame_TorqueMult")
    end
    local base = self.OrigTorque or 1
    local mult = Flag("boost_torque") or 2
    pcall(function()
        car:SetAttribute("CarGame_TorqueMult", base * mult)
    end)
end

----------------------------------------------------------------
-- Car moving helpers (shared by anti-bust + fix car)
----------------------------------------------------------------
local function GroundBelow(pos, ignore, startUp, length)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(pos + V3(0, startUp, 0), V3(0, -length, 0), params)
    return hit and hit.Position or nil
end

-- Moves the whole car so its DriveSeat lands on seatTargetCF, and kills its momentum.
-- Only replicates while we're the driver (driver owns the car's physics).
local function MoveCarTo(car, seat, seatTargetCF)
    local delta = seatTargetCF * seat.CFrame:Inverse()
    car:PivotTo(delta * car:GetPivot())
    seat.AssemblyLinearVelocity = Vector3.zero
    seat.AssemblyAngularVelocity = Vector3.zero
end

local function FlatDir(v, fallback)
    local flat = V3(v.X, 0, v.Z)
    if flat.Magnitude < 0.05 then return fallback end
    return flat.Unit
end

----------------------------------------------------------------
-- Fix car: put the car you're driving back on its wheels
----------------------------------------------------------------
-- Skips keys the game already uses (R refuel, V camera, H hang out, Q shift lock, E prompts, C free cam).
local FIXCAR_KEYS = { "None", "G", "J", "K", "L", "X", "Z", "B", "N" }

local function FixCar()
    local car = CurrentDrivenCar()
    local seat = car and car:FindFirstChild("DriveSeat")
    if not seat then
        warn("[Striker Boys] Fix car: you need to be in the driver seat.")
        return
    end
    -- Keep the heading; if the nose points straight up/down, use the roof direction instead.
    local look = FlatDir(seat.CFrame.LookVector, FlatDir(seat.CFrame.UpVector, V3(0, 0, -1)))
    local ground = GroundBelow(seat.Position, { LocalPlayer.Character, car }, 8, 60)
    local y = (ground and ground.Y or seat.Position.Y) + 5
    local pos = V3(seat.Position.X, y, seat.Position.Z)
    MoveCarTo(car, seat, CFrame.lookAt(pos, pos + look))
end

----------------------------------------------------------------
-- Location teleports (Chop Shop / Plug)
-- Driving: the car comes with you. Passenger: you get out, then teleport.
-- Height comes from a ground raycast at the spot (cast from just above it,
-- so a roof overhead isn't mistaken for the ground) + a small drop.
----------------------------------------------------------------
local function TeleportToSpot(pos, faceDir)
    local char = LocalPlayer.Character
    if not char then return false, "no character" end
    local car = CurrentDrivenCar()
    local seat = car and car:FindFirstChild("DriveSeat")
    local ignore = { char }
    if car then ignore[2] = car end
    local ground = GroundBelow(pos, ignore, 3, 40)
    local target = ground and V3(pos.X, ground.Y + 5, pos.Z) or pos

    if seat then
        local look = faceDir or FlatDir(seat.CFrame.LookVector, V3(0, 0, -1))
        MoveCarTo(car, seat, CFrame.lookAt(target, target + look))
        return true
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local look = faceDir or (hrp and FlatDir(hrp.CFrame.LookVector, V3(0, 0, -1))) or V3(0, 0, -1)
    return TeleportTo(CFrame.lookAt(target, target + look))
end

local function TeleportToChopShop()
    return TeleportToSpot(CHOPSHOP_TP)
end

local function TeleportToPlug()
    local m = CarGameWorld:FindFirstChild("The Plug") or PlugModel
    if not m then return false, "no plug" end
    local root = m:FindFirstChild("HumanoidRootPart")
    local pos = GetModelPivot(m)
    if not pos then return false, "no position" end
    -- Land in front of him, facing him; further out if a car is coming along.
    local front = root and FlatDir(root.CFrame.LookVector, V3(0, 0, -1)) or V3(0, 0, -1)
    local gap = CurrentDrivenCar() and 14 or 5
    local spot = pos + front * gap
    return TeleportToSpot(spot, -front)
end

-- workspace.CarGame_Shops.ArmsDealer: the NPC is the "Arms Dealer" model inside.
-- Lands in front of him (inside his 12-stud "Browse guns" prompt), facing him.
local function TeleportToArmsDealer()
    local shops = workspace:FindFirstChild("CarGame_Shops")
    local shop = shops and shops:FindFirstChild("ArmsDealer")
    if not shop then return false, "no arms dealer" end
    local npc = shop:FindFirstChild("Arms Dealer")
    local root = npc and npc:FindFirstChild("HumanoidRootPart")
    local pos = root and root.Position or GetModelPivot(shop)
    if not pos then return false, "no position" end
    local front = root and FlatDir(root.CFrame.LookVector, V3(0, 0, 1)) or V3(0, 0, 1)
    local gap = CurrentDrivenCar() and 14 or 5
    return TeleportToSpot(pos + front * gap, -front)
end

----------------------------------------------------------------
-- Player teleport: drop next to another player, facing them. On foot we land
-- a couple studs off; driving, further out so the car doesn't clip them.
----------------------------------------------------------------
local function PlayerRoot(p)
    local char = p and p.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
end

local function TeleportToPlayer(p)
    if not p or p == LocalPlayer then return false, "no player" end
    local root = PlayerRoot(p)
    if not root then return false, (p.DisplayName .. " isn't spawned") end
    -- Stand just behind them (away from their facing) so we don't land on them.
    local behind = FlatDir(-root.CFrame.LookVector, V3(0, 0, 1))
    local gap = CurrentDrivenCar() and 14 or 4
    return TeleportToSpot(root.Position + behind * gap, -behind)
end

-- Player list for the teleport dropdown. Pinned to UserId so a pick survives
-- refreshes; excludes you. Duplicate display names get a #N suffix.
local PlayerList = { Map = {}, Picked = nil, Dropdown = nil }

function PlayerList:Build()
    local labels, map, seen = {}, {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local label = p.DisplayName
            if p.Name ~= p.DisplayName then label = label .. " (@" .. p.Name .. ")" end
            if p.Team then label = label .. " - " .. p.Team.Name end
            if seen[label] then
                seen[label] += 1
                label = label .. " #" .. seen[label]
            else
                seen[label] = 1
            end
            labels[#labels + 1] = label
            map[label] = p.UserId
        end
    end
    table.sort(labels, function(a, b) return a:lower() < b:lower() end)
    self.Map = map
    return labels, map
end

function PlayerList:Selected()
    if not self.Picked then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.UserId == self.Picked and p ~= LocalPlayer then return p end
    end
    return nil
end

function PlayerList:Refresh()
    local labels, map = self:Build()
    -- Keep the current pick highlighted if that player is still here.
    local keepLabel
    if self.Picked then
        for lbl, uid in pairs(map) do
            if uid == self.Picked then keepLabel = lbl; break end
        end
    end
    local dd = self.Dropdown
    if not dd then return end
    pcall(function() dd:Refresh(labels) end)
    if keepLabel then
        pcall(function() dd:Set(keepLabel) end)
    else
        self.Picked = nil
    end
end

----------------------------------------------------------------
-- House teleports: CarGame_World.Houses.HouseN -> its CG_HouseLock door
-- (never the CG_ForSale sign). A house can have several CG_HouseLock
-- doors; the front one is the one nearest the for-sale sign.
----------------------------------------------------------------
local HouseList = { Map = {}, Picked = nil, Dropdown = nil }

local function HousesFolder()
    return CarGameWorld:FindFirstChild("Houses")
end

function HouseList:Build()
    local folder = HousesFolder()
    local entries = {}
    if folder then
        for _, h in ipairs(folder:GetChildren()) do
            local name = h:GetAttribute("CG_HouseName") or h.Name
            local area = h:GetAttribute("CG_Area")
            local label = area and (tostring(name) .. " (" .. tostring(area) .. ")") or tostring(name)
            entries[#entries + 1] = { label = label, house = h, num = tonumber(h.Name:match("%d+")) or math.huge }
        end
    end
    table.sort(entries, function(a, b)
        if a.num ~= b.num then return a.num < b.num end
        return a.label < b.label
    end)
    local labels, map, seen = {}, {}, {}
    for _, e in ipairs(entries) do
        local label = e.label
        seen[label] = (seen[label] or 0) + 1
        if seen[label] > 1 then label = label .. " #" .. seen[label] end
        labels[#labels + 1] = label
        map[label] = e.house.Name
    end
    if #labels == 0 then labels[1] = "<none>" end
    return labels, map
end

function HouseList:Refresh()
    local labels, map = self:Build()
    self.Map = map
    if self.Dropdown then
        self.Dropdown:Refresh(labels)
        local label
        for l, n in pairs(map) do if n == self.Picked then label = l break end end
        if label then self.Dropdown:Set(label) else self.Picked = nil end
    end
end

function HouseList:Selected()
    local folder = HousesFolder()
    return folder and self.Picked and folder:FindFirstChild(self.Picked) or nil
end

local function HouseFrontDoor(house)
    local sign = house:FindFirstChild("CG_ForSale")
    local signPos = sign and GetModelPivot(sign)
    local best, bestD
    for _, c in ipairs(house:GetChildren()) do
        if c.Name == "CG_HouseLock" and c:IsA("BasePart") then
            local d = signPos and (c.Position - signPos).Magnitude or 0
            if not best or d < bestD then best, bestD = c, d end
        end
    end
    return best, signPos
end

local function HasCeiling(pos, ignore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    return workspace:Raycast(pos + V3(0, 1, 0), V3(0, 40, 0), params) ~= nil
end

local function TeleportToHouse(house)
    local door, signPos = HouseFrontDoor(house)
    if not door then
        warn("[Striker Boys] " .. house.Name .. " has no CG_HouseLock door.")
        return false
    end
    -- Door is a thin slab; its LookVector points through it. Stand on the
    -- outside: the side with open sky (no roof), else the side facing the sign.
    local n = FlatDir(door.CFrame.LookVector, V3(0, 0, -1))
    local gap = CurrentDrivenCar() and 12 or 4
    local char = LocalPlayer.Character
    local ignore = { char }
    local car = CurrentDrivenCar()
    if car then ignore[2] = car end
    local a, b = door.Position + n * gap, door.Position - n * gap
    local aRoof, bRoof = HasCeiling(a, ignore), HasCeiling(b, ignore)
    local outside
    if aRoof ~= bRoof then
        outside = aRoof and -n or n
    elseif signPos then
        outside = ((a - signPos).Magnitude <= (b - signPos).Magnitude) and n or -n
    else
        outside = n
    end
    return TeleportToSpot(door.Position + outside * gap, -outside)
end

----------------------------------------------------------------
-- Anti-bust: cops bust you by staying within 22 studs while you're under
-- 12 MPH for 3s (Config.Bust). BustProgress goes 0..1 on the player;
-- once it starts rising we teleport out of range.
-- Cops are BOTH Police-team players AND the game's AI police
-- (workspace.CarGame_AI.Police car + foot officers that deploy within
-- 110 studs and tackle at 4.5 studs). The old version only looked at
-- players, so vs AI cops it teleported "forward" - often into them.
----------------------------------------------------------------
local AntiBust = { LastEscape = 0, Escapes = 0 }
local AutoFarm -- forward decl (defined below); anti-bust tells it when we fled

local function IsCopName(n)
    n = n:lower()
    return n:find("police", 1, true) or n:find("officer", 1, true) or n:find("cop", 1, true)
end

-- Positions of every cop we can see: police players, AI police cars, AI foot officers.
local CopCache = { T = 0, List = {} }
local function CopPositions()
    if os.clock() - CopCache.T < 0.15 then return CopCache.List end
    local list = {}
    local playerChars = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then playerChars[p.Character] = true end
        if p ~= LocalPlayer and p.Team and p.Team.Name == "Police" then
            local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if r then list[#list + 1] = r.Position end
        end
    end
    local function addModel(m)
        if playerChars[m] then return end
        local part = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChild("Root")
        if part and part:IsA("BasePart") then list[#list + 1] = part.Position end
    end
    local ai = workspace:FindFirstChild("CarGame_AI")
    if ai then
        for _, m in ipairs(ai:GetChildren()) do
            if m:IsA("Model") and IsCopName(m.Name) then
                addModel(m)
                -- foot officers may be parented under the unit
                for _, c in ipairs(m:GetChildren()) do
                    if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then addModel(c) end
                end
            end
        end
    end
    -- foot officers parented straight to workspace (or a folder of them)
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and not playerChars[m] and IsCopName(m.Name)
            and m:FindFirstChildOfClass("Humanoid") and m.Name ~= "PoseTestOfficer" then
            addModel(m)
        elseif m:IsA("Folder") and IsCopName(m.Name) then
            for _, c in ipairs(m:GetChildren()) do
                if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then addModel(c) end
            end
        end
    end
    CopCache.T, CopCache.List = os.clock(), list
    return list
end

local function NearestCop(origin)
    local best, bestD
    for _, pos in ipairs(CopPositions()) do
        local d = (pos - origin).Magnitude
        if not bestD or d < bestD then best, bestD = pos, d end
    end
    return best, bestD
end

-- Any cop within `range` of pos?
local function CopNear(pos, range)
    local _, d = NearestCop(pos)
    return d ~= nil and d <= range
end

-- Direction away from every cop within `range`, closer ones weighted more.
local function AwayFromCops(origin, range, fallback)
    local sum = Vector3.zero
    for _, pos in ipairs(CopPositions()) do
        local off = V3(origin.X - pos.X, 0, origin.Z - pos.Z)
        local d = off.Magnitude
        if d < range and d > 0.05 then sum += off.Unit * (range - d) end
    end
    return FlatDir(sum, fallback)
end

function AntiBust:Escape()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    local car = CurrentDrivenCar()
    local seat = car and car:FindFirstChild("DriveSeat")
    local mover = seat or hrp
    local origin = mover.Position

    -- Away from all nearby cops (players + AI). If none seen, keep going forward.
    local forward = FlatDir(mover.CFrame.LookVector, V3(0, 0, -1))
    local dir = AwayFromCops(origin, 200, forward)

    -- Repeated escapes in a row = they're keeping up; jump further each time.
    local dist = (Flag("antibust_dist") or 150) * math.min(1 + self.Escapes * 0.5, 3)
    local target = origin + dir * dist
    local ignore = { char }
    if car then ignore[2] = car end
    local ground = GroundBelow(target, ignore, 80, 250)
    local y = ground and (ground.Y + (seat and 4 or 3)) or (origin.Y + 3)
    local pos = V3(target.X, y, target.Z)

    if seat then
        MoveCarTo(car, seat, CFrame.lookAt(pos, pos + forward))
    else
        TeleportTo(CFrame.lookAt(pos, pos + dir)) -- handles leaving a passenger seat
    end
end

function AntiBust:Update()
    if not Flag("antibust_enabled") then return end
    if LocalPlayer.Team and LocalPlayer.Team.Name == "Police" then return end
    local now = os.clock()
    if now - self.LastEscape < 0.5 then return end

    local progress = tonumber(LocalPlayer:GetAttribute("BustProgress")) or 0
    local trigger = progress * 100 >= (Flag("antibust_threshold") or 1)

    -- Pre-emptive: a cop is close and we're slow -> leave BEFORE the meter
    -- (AI foot cops tackle at 4.5 studs, which can skip the meter entirely).
    if not trigger and Flag("antibust_preempt") ~= false then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local car = CurrentDrivenCar()
            local seat = car and car:FindFirstChild("DriveSeat")
            local mover = seat or hrp
            local speed = mover.AssemblyLinearVelocity.Magnitude
            if speed < 35 and CopNear(mover.Position, Flag("antibust_preempt_range") or 35) then
                trigger = true
            end
        end
    end
    if not trigger then
        if now - self.LastEscape > 6 then self.Escapes = 0 end
        return
    end
    self.LastEscape = now
    self.Escapes += 1
    -- On foot mid-steal: tell the farm to drop this car instead of walking
    -- straight back to the cops. (In a car we take it with us, so carry on.)
    if AutoFarm and AutoFarm.Active and not CurrentDrivenCar() then
        AutoFarm.Fled = true
    end
    task.spawn(Safe, "AntiBustEscape", function() self:Escape() end)
end

----------------------------------------------------------------
-- Auto Farm: steal target cars and deliver them to the chop shop.
-- Per car, using the game's own prompts with their real hold times:
--   CarGame_Window.BreakIn "Tap ... glass" (E 0.4s) -> same prompt turns
--   "Climb in" (E 0.5s) -> seated -> CarGame_OBD "Plug in Autel" (F 0.6s)
--   -> ProPad opens -> wait about as long as a person takes on the pad ->
--   ProPad.Finish(true) (the game itself sends Steal with the PIN) ->
--   take the car into the chop shop zone.
-- Skips: Kia/Hyundai/Honda (need screwdriver + charger, Autel can't do them),
-- cars with someone inside, and cars whose glass won't tap within 5s
-- (contracts that aren't yours, or bugged cars). Dying pauses it 2m30s.
----------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

AutoFarm = {
    Active = false,
    Fled = false,      -- anti-bust teleported us off a car mid-steal
    Status = "Idle",
    StatusLabel = nil,
    BadCars = {},      -- CarGame_CarId -> os.clock() it was skipped
    PausedUntil = 0,   -- death pause
    Delivered = 0,
    LastPad = nil,     -- last "ProPad" payload the server sent us
    Objective = nil,   -- last "Objective" event
    WarnedKey = false,
}
local FARM_BLACKLIST = { "kia", "hyundai", "honda" }
local FARM_BAD_COOLDOWN = 180 -- seconds before a skipped car is tried again
local FARM_DEATH_PAUSE = 150  -- 2m30s
local FARM_CLIMB_WAIT = 5     -- glass must turn into "Climb in" within this

function AutoFarm:SetStatus(s, quiet)
    if self.Status == s then return end
    self.Status = s
    if not quiet then print("[Striker Boys] Auto farm: " .. s) end
    if self.StatusLabel then
        pcall(function() self.StatusLabel:SetText("Status: " .. s) end)
    end
end

local function FarmHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Stop/death aware waits: return false/nil the moment the farm should bail.
local function FarmAlive()
    return Running and AutoFarm.Active and os.clock() >= AutoFarm.PausedUntil and not AutoFarm.Fled
end
local FARM_COP_CLEAR = 130 -- AI foot cops deploy within 110 studs; stay out of that
local function FarmWait(t)
    local t0 = os.clock()
    while os.clock() - t0 < t do
        if not FarmAlive() then return false end
        task.wait(0.1)
    end
    return FarmAlive()
end
local function FarmWaitFor(fn, timeout)
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        if not FarmAlive() then return nil end
        local ok, v = pcall(fn)
        if ok and v then return v end
        task.wait(0.1)
    end
    return nil
end

-- Same as the game's plug shop: the item exists under CarGame_Items, and
-- stackable gear (universal keys) keeps its amount in a "Count" attribute.
local function ItemCount(id)
    local folder = LocalPlayer:FindFirstChild("CarGame_Items")
    local v = folder and folder:FindFirstChild(id)
    if not v then return 0 end
    return tonumber(v:GetAttribute("Count")) or 1
end
local function HasItem(id)
    return ItemCount(id) > 0
end

local function CarIsBlacklisted(car)
    if not Flag("farm_skip_charger") then return false end
    local s = (car.Name .. " " .. tostring(car:GetAttribute("CarGame_Key") or "") .. " "
        .. tostring(car:GetAttribute("DisplayName") or "")):lower()
    for _, word in ipairs(FARM_BLACKLIST) do
        if s:find(word, 1, true) then return true end
    end
    return false
end

local function CarHasPeople(car)
    local myChar = LocalPlayer.Character
    for _, d in ipairs(car:GetDescendants()) do
        if (d:IsA("Seat") or d:IsA("VehicleSeat")) and d.Occupant and d.Occupant.Parent ~= myChar then
            return true
        end
    end
    return false
end

local function CarWindows(car)
    local list = {}
    for _, part in ipairs(car:GetChildren()) do
        if part.Name == "CarGame_Window" and part:IsA("BasePart") then
            local prompt = part:FindFirstChild("BreakIn")
            if prompt and prompt:IsA("ProximityPrompt") then
                list[#list + 1] = { part = part, prompt = prompt }
            end
        end
    end
    return list
end

local function IsClimbPrompt(p)
    return p.Enabled and tostring(p.ActionText):lower():find("climb", 1, true) ~= nil
end

-- Stand just outside the window (away from the car's middle), on the ground, facing it.
local function WindowStandCF(car, part)
    local seat = car:FindFirstChild("DriveSeat")
    local center = seat and seat.Position or car:GetPivot().Position
    local out = FlatDir(part.Position - center, V3(1, 0, 0))
    local spot = part.Position + out * 2.5
    local ground = GroundBelow(spot, { LocalPlayer.Character, car }, 3, 30)
    local y = ground and (ground.Y + 3) or spot.Y
    local pos = V3(spot.X, y, spot.Z)
    return CFrame.lookAt(pos, V3(part.Position.X, y, part.Position.Z))
end

-- Holds the prompt's key (E / F) with VirtualInputManager for its real
-- HoldDuration, like a player pressing it. The prompt we stand next to is the
-- closest one for that key, so it's the one that takes the press.
-- Fallbacks only if VIM didn't trigger it: InputHoldBegin, then fireproximityprompt.
local VirtualInputManager = game:GetService("VirtualInputManager")

local function VIMHoldKey(keyCode, seconds, isDone)
    local ok = pcall(function() VirtualInputManager:SendKeyEvent(true, keyCode, false, game) end)
    if not ok then return false end
    local t0 = os.clock()
    while os.clock() - t0 < seconds and not (isDone and isDone()) do task.wait() end
    pcall(function() VirtualInputManager:SendKeyEvent(false, keyCode, false, game) end)
    return true
end

local function HoldPrompt(prompt)
    if not (prompt and prompt.Parent and prompt.Enabled) then return false end
    local fired = false
    local conn = prompt.Triggered:Connect(function(plr)
        if plr == LocalPlayer then fired = true end
    end)
    local key = prompt.KeyboardKeyCode
    VIMHoldKey(key, prompt.HoldDuration + 0.25 + math.random() * 0.15, function() return fired end)
    local t0 = os.clock()
    while not fired and os.clock() - t0 < 0.3 do task.wait() end
    if not fired then
        pcall(function() prompt:InputHoldBegin() end)
        local t1 = os.clock()
        while not fired and os.clock() - t1 < prompt.HoldDuration + 0.35 do task.wait() end
        pcall(function() prompt:InputHoldEnd() end)
    end
    if not fired and fireproximityprompt then
        pcall(fireproximityprompt, prompt)
        local t1 = os.clock()
        while not fired and os.clock() - t1 < 0.5 do task.wait() end
    end
    conn:Disconnect()
    return fired
end

-- The game's ProPad module (same table the game uses when require is shared).
local ProPadModule = nil
local function GetProPad()
    if ProPadModule == nil then
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("CarGame", 5):WaitForChild("Client", 5):WaitForChild("ProPad", 5))
        end)
        ProPadModule = (ok and type(m) == "table") and m or false
    end
    return ProPadModule or nil
end

-- The GameRequest RemoteFunction - the game's Plug shop buys go through it:
--   GameRequest:InvokeServer({Action="BuyGear", Item="UniversalKey"}) -> success, msg
local GameRequestRemote = nil
local function GetGameRequest()
    if GameRequestRemote == nil then
        local ok, r = pcall(function()
            return ReplicatedStorage:WaitForChild("CarGame", 5):WaitForChild("Remotes", 5):WaitForChild("GameRequest", 5)
        end)
        GameRequestRemote = (ok and typeof(r) == "Instance" and r:IsA("RemoteFunction")) and r or false
    end
    return GameRequestRemote or nil
end

local function FarmCash()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local c = ls and ls:FindFirstChild("Cash")
    return c and tonumber(c.Value)
end

local function PadGuiOpen()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local gui = pg and pg:FindFirstChild("CarGame_ProPad")
    return gui ~= nil and gui.Enabled
end

function AutoFarm:Ready()
    local hum = FarmHumanoid()
    if not (hum and hum.Health > 0 and hum.RootPart) then return false, "no character" end
    if LocalPlayer:GetAttribute("CarGame_Jailed") then return false, "jailed" end
    local team = LocalPlayer.Team
    if not team or team.Name ~= "Striker Boys" then return false, "join the Striker Boys team" end
    if not HasItem("ProPad") then return false, "you need an Autel ProPad (the Plug)" end
    if not HasItem("WindowBreaker") then return false, "you need a window breaker (the Plug)" end
    return true
end

-- Universal smart keys: $900 each, cap 5 (Game.PlugGear in the game's Config).
local FARM_KEY_ID = "UniversalKey"
local FARM_KEY_PRICE = 900
local FARM_KEY_MAX = 5

-- Top up keys at the Plug the same way the game's shop does: go to him (the
-- server checks you're near), then InvokeServer BuyGear once per key until full
-- or we run out of cash / the server refuses. Returns true if we end with >0.
function AutoFarm:RebuyKeys()
    local remote = GetGameRequest()
    if not remote then return false end
    self:SetStatus("Out of keys - heading to the Plug")
    pcall(TeleportToPlug)
    if not FarmWait(0.6) then return HasItem(FARM_KEY_ID) end
    local bought = 0
    while FarmAlive() and ItemCount(FARM_KEY_ID) < FARM_KEY_MAX do
        local cash = FarmCash()
        if cash ~= nil and cash < FARM_KEY_PRICE then
            self:SetStatus(string.format("Stopped: need $%d per key, have $%d", FARM_KEY_PRICE, cash))
            break
        end
        local before = ItemCount(FARM_KEY_ID)
        local ok, success, msg = pcall(function()
            return remote:InvokeServer({ Action = "BuyGear", Item = FARM_KEY_ID })
        end)
        if not ok then break end
        if success == false then
            self:SetStatus("Plug: " .. tostring(msg or "couldn't buy a key"))
            break
        end
        -- Wait for the Count attribute to climb, then go again.
        FarmWaitFor(function() return ItemCount(FARM_KEY_ID) > before end, 3)
        if ItemCount(FARM_KEY_ID) <= before then break end -- no change -> stop
        bought += 1
        self:SetStatus(string.format("Bought a key (%d/%d)", ItemCount(FARM_KEY_ID), FARM_KEY_MAX))
        FarmWait(0.3)
    end
    return HasItem(FARM_KEY_ID)
end

-- Out of universal smart keys: rebuy at the Plug if enabled, else stop the farm.
function AutoFarm:CheckKeys()
    if HasItem("UniversalKey") then return true end
    if Flag("farm_auto_rebuy") ~= false then
        pcall(function() self:RebuyKeys() end)
        if HasItem("UniversalKey") then return true end
        if self.Fled then
            -- Anti-bust pulled us away from the Plug; try again shortly.
            self.Fled = false
            self:SetStatus("Cops at the Plug - retrying keys soon")
            return nil
        end
    end
    self.Active = false
    self:SetStatus("Stopped: no universal smart keys - buy more from the Plug")
    if self.Toggle then pcall(function() self.Toggle:Set(false) end) end
    return false
end

function AutoFarm:PickCar()
    local folder = GetTargets()
    if not folder then return nil end
    local origin = GetOrigin()
    local now = os.clock()
    local best, bestD
    for _, car in ipairs(folder:GetChildren()) do
        local id = car:GetAttribute("CarGame_CarId") or car
        local skipped = self.BadCars[id]
        local seat = car:FindFirstChild("DriveSeat")
        if seat and not (skipped and now - skipped < FARM_BAD_COOLDOWN)
            and not CarIsBlacklisted(car) and #CarWindows(car) > 0 and not CarHasPeople(car)
            and not (Flag("farm_avoid_cops") ~= false and CopNear(seat.Position, FARM_COP_CLEAR)) then
            local d = (seat.Position - origin).Magnitude
            if not best or d < bestD then best, bestD = car, d end
        end
    end
    return best
end

function AutoFarm:StealCar(car)
    local id = car:GetAttribute("CarGame_CarId") or car
    local label = tostring(car:GetAttribute("DisplayName") or car.Name)
    local function skip(why)
        self.BadCars[id] = os.clock()
        if FarmAlive() then self:SetStatus("Skipped " .. label .. ": " .. why) end
        return false
    end

    -- Window: one that's already smashed ("Climb in"), else any enabled one.
    local wins = CarWindows(car)
    local win
    for _, w in ipairs(wins) do
        if IsClimbPrompt(w.prompt) then win = w break end
    end
    if not win then
        for _, w in ipairs(wins) do
            if w.prompt.Enabled then win = w break end
        end
    end
    if not win then return skip("no usable window") end
    if Flag("farm_avoid_cops") ~= false and CopNear(win.part.Position, FARM_COP_CLEAR) then
        return skip("cops nearby")
    end

    self:SetStatus("Going to " .. label)
    TeleportTo(WindowStandCF(car, win.part))
    if not FarmWait(0.4) then return false end
    if not car.Parent then return skip("despawned") end
    if CarHasPeople(car) then return skip("someone is inside") end

    -- Smash the glass (unless it's already smashed).
    if not IsClimbPrompt(win.prompt) then
        self:SetStatus("Tapping glass: " .. label)
        HoldPrompt(win.prompt)
        if not FarmWaitFor(function() return IsClimbPrompt(win.prompt) end, FARM_CLIMB_WAIT) then
            if not FarmAlive() then return false end
            return skip("glass won't tap (contract or bugged)")
        end
    end
    if CarHasPeople(car) then return skip("someone got in") end

    -- Climb in.
    self:SetStatus("Climbing in: " .. label)
    HoldPrompt(win.prompt)
    local seat = FarmWaitFor(function()
        local hum = FarmHumanoid()
        local s = hum and hum.SeatPart
        return s and s:IsDescendantOf(car) and s
    end, 8)
    if not seat then
        if not FarmAlive() then return false end
        return skip("couldn't climb in")
    end

    -- Plug in the Autel.
    local obd = car:FindFirstChild("CarGame_OBD")
    local obdPrompt = obd and obd:FindFirstChildOfClass("ProximityPrompt")
    if not obdPrompt then return skip("no OBD port") end
    if not FarmWaitFor(function() return obdPrompt.Enabled end, 5) then
        if not FarmAlive() then return false end
        return skip("OBD port never turned on")
    end
    if not FarmWait(0.3) then return false end
    self.LastPad = nil
    self:SetStatus("Plugging in Autel: " .. label)
    HoldPrompt(obdPrompt)
    if not FarmWaitFor(PadGuiOpen, 6) then
        if not FarmAlive() then return false end
        return skip("ProPad didn't open")
    end

    -- Pad is up: take the car to the mountain while the pad runs, away from cops.
    local padStart = os.clock()
    if CurrentDrivenCar() == car then
        self:SetStatus("Pad open - moving to the mountain: " .. label)
        TeleportToSpot(MOUNTAIN_TP)
    else
        self:SetStatus("Pad open (not in driver seat, staying put): " .. label)
    end

    -- Pad: wait about as long as a person takes, then finish through the game's module.
    local need = Flag("farm_pad_time") or 18
    local pad = self.LastPad
    if pad then
        need = mmax(need, (tonumber(pad.ReadSecs) or 3) + (tonumber(pad.ProgSecs) or 5) + 6)
    end
    need += math.random() * 2
    self:SetStatus(string.format("Programming key (%.0fs): %s", need, label))
    if not FarmWait(mmax(0, need - (os.clock() - padStart))) then return false end
    if not PadGuiOpen() then return skip("ProPad closed early") end
    local mod = GetProPad()
    if not (mod and mod.IsOpen and mod.IsOpen()) then
        self.Active = false
        self:SetStatus("Stopped: couldn't reach the game's ProPad module")
        warn("[Striker Boys] Auto farm: require() gave a separate ProPad copy, so the pad can't be finished from here. Tell Claude.")
        return false
    end
    self.Objective = nil
    mod.Finish(true)
    if not FarmWait(1.5) then return false end

    -- Deliver.
    if CurrentDrivenCar() ~= car then
        return skip("not in the driver seat after the steal")
    end
    self:SetStatus("Delivering " .. label)
    TeleportToSpot(CHOPSHOP_TP)
    local delivered = FarmWaitFor(function()
        if not car:IsDescendantOf(workspace) then return true end
        local hum = FarmHumanoid()
        if not (hum and hum.SeatPart and hum.SeatPart:IsDescendantOf(car)) then return true end
        local o = self.Objective
        return o and o.Text == nil
    end, 15)
    if not FarmAlive() then return false end
    if delivered then
        self.Delivered += 1
        self:SetStatus(string.format("Delivered %s (%d total)", label, self.Delivered))
    else
        self:SetStatus("Delivery not confirmed: " .. label)
    end
    self.BadCars[id] = os.clock() -- never retry the same car
    local hum = FarmHumanoid()
    if hum and hum.SeatPart then hum.Sit = false end
    FarmWait(1)
    return delivered
end

function AutoFarm:Loop()
    while Running and self.Active do
        if os.clock() < self.PausedUntil then
            self:SetStatus(string.format("Died - resuming in %ds", math.ceil(self.PausedUntil - os.clock())), true)
            task.wait(1)
        else
            local ok, why = self:Ready()
            local keys = ok and self:CheckKeys()
            if ok and keys == nil then
                task.wait(5)
            elseif ok and not keys then
                break
            elseif not ok then
                self:SetStatus("Waiting: " .. why)
                task.wait(2)
            else
                local car = self:PickCar()
                if not car then
                    self:SetStatus("No cars available - waiting")
                    task.wait(3)
                else
                    self.Fled = false
                    local fine, err = pcall(self.StealCar, self, car)
                    if not fine then
                        warn("[Striker Boys] Auto farm error: " .. tostring(err))
                        self.BadCars[car:GetAttribute("CarGame_CarId") or car] = os.clock()
                        task.wait(1)
                    end
                    if self.Fled then
                        -- Anti-bust pulled us off this car: drop it, let the cops lose us.
                        self.BadCars[car:GetAttribute("CarGame_CarId") or car] = os.clock()
                        self:SetStatus("Cops on that car - fled, picking another")
                        self.Fled = false
                        task.wait(2)
                    end
                    task.wait(0.5)
                end
            end
        end
    end
    if Running and not self.Status:find("^Stopped") then self:SetStatus("Idle") end
end

function AutoFarm:Start()
    if self.Active then return end
    self.Active = true
    task.spawn(function() self:Loop() end)
end

function AutoFarm:Stop()
    self.Active = false
end

local function FarmBindCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not (hum and Running) then return end
    table.insert(Connections, hum.Died:Connect(function()
        if AutoFarm.Active then
            AutoFarm.PausedUntil = os.clock() + FARM_DEATH_PAUSE
            AutoFarm:SetStatus("Died - pausing 2m30s")
        end
    end))
end

----------------------------------------------------------------
-- World (lighting / fog / fullbright)
----------------------------------------------------------------
local World = {
    Saved = nil,
    Applied = false,
    PostFX = {}, -- Lighting post-effects we disabled, to re-enable on restore
}

local function SaveLighting()
    if World.Saved then return end
    World.Saved = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor,
        GlobalShadows = Lighting.GlobalShadows,
        ExposureCompensation = Lighting.ExposureCompensation,
    }
end

function World:Restore()
    if not self.Saved then return end
    pcall(function()
        for k, v in pairs(self.Saved) do Lighting[k] = v end
    end)
    for fx, _ in pairs(self.PostFX) do
        pcall(function() fx.Enabled = true end)
    end
    table.clear(self.PostFX)
    self.Applied = false
end

function World:DisablePostFX()
    for _, fx in ipairs(Lighting:GetChildren()) do
        if (fx:IsA("BlurEffect") or fx:IsA("ColorCorrectionEffect") or fx:IsA("SunRaysEffect") or fx:IsA("BloomEffect") or fx:IsA("DepthOfFieldEffect")) and fx.Enabled then
            self.PostFX[fx] = true
            pcall(function() fx.Enabled = false end)
        end
    end
end

function World:Update()
    local anyOn = Flag("world_fullbright") or Flag("world_time_enabled")
        or Flag("world_fog_enabled") or Flag("world_no_shadows")
        or Flag("world_no_postfx") or Flag("world_ambient_enabled")
        or Flag("world_brightness_enabled")

    if not anyOn then
        if self.Applied then self:Restore() end
        return
    end

    SaveLighting()
    self.Applied = true

    if Flag("world_fullbright") then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = mmax(Lighting.Brightness, 2)
        Lighting.FogEnd = 1e6
        Lighting.GlobalShadows = false
    else
        if Flag("world_ambient_enabled") then
            local c = FlagColor("world_ambient_col", Color3.new(1, 1, 1))
            Lighting.Ambient = c
            Lighting.OutdoorAmbient = c
        end
        if Flag("world_brightness_enabled") then
            Lighting.Brightness = Flag("world_brightness") or 2
        end
        if Flag("world_no_shadows") then
            Lighting.GlobalShadows = false
        end
    end

    if Flag("world_time_enabled") then
        Lighting.ClockTime = Flag("world_time") or 14
    end

    if Flag("world_fog_enabled") then
        Lighting.FogEnd = Flag("world_fog_end") or 1e6
        Lighting.FogStart = mmin(Flag("world_fog_start") or 0, Lighting.FogEnd - 1)
        local fc = FlagColor("world_fog_col", Color3.new(1, 1, 1))
        Lighting.FogColor = fc
    end

    if Flag("world_no_postfx") then
        self:DisablePostFX()
    end
end

----------------------------------------------------------------
-- UI
----------------------------------------------------------------
Window = Library:Window({ Name = "Striker Boys" })

local function BuildUI()
    ----------------------------------------------------------------
    -- Visuals page
    ----------------------------------------------------------------
    local VisualsPage = Window:Page({ Name = "Visuals" })
    local ESPSP = VisualsPage:SubPage({ Name = "ESP" })

    local PlayerSec = ESPSP:Section({ Name = "Player ESP", Side = 1 })
    PlayerSec:Toggle({ Name = "Enabled", Flag = "player_visuals", Default = false })
    local nameToggle = PlayerSec:Toggle({ Name = "Name", Flag = "player_name", Default = true })
    nameToggle:Colorpicker({ Flag = "player_name_col", Default = Color3.new(1, 1, 1), Alpha = 1 })
    local boxToggle = PlayerSec:Toggle({ Name = "Box", Flag = "player_box", Default = true })
    boxToggle:Colorpicker({ Flag = "player_box_col", Default = Color3.new(1, 1, 1), Alpha = 1 })
    PlayerSec:Dropdown({ Name = "Box mode", Flag = "player_box_mode", Items = { "Full", "Corner", "Filled", "3D" }, Default = "Full" })
    PlayerSec:Slider({ Name = "Box thickness", Flag = "player_box_thickness", Default = 1, Min = 1, Max = 6, Decimals = 1 })
    local olToggle = PlayerSec:Toggle({ Name = "Box outline", Flag = "player_box_outline", Default = true })
    olToggle:Colorpicker({ Flag = "player_box_outline_col", Default = Color3.new(0, 0, 0), Alpha = 1 })
    local weapToggle = PlayerSec:Toggle({ Name = "Weapon", Flag = "player_weapon", Default = false })
    weapToggle:Colorpicker({ Flag = "player_weapon_col", Default = Color3.new(1, 1, 1), Alpha = 1 })
    local distToggle = PlayerSec:Toggle({ Name = "Distance", Flag = "player_distance", Default = true })
    distToggle:Colorpicker({ Flag = "player_distance_col", Default = Color3.new(1, 1, 1), Alpha = 1 })
    local healthToggle = PlayerSec:Toggle({ Name = "Health bar", Flag = "player_health", Default = true })
    healthToggle:Colorpicker({ Flag = "player_health_col", Default = Color3.fromRGB(80, 255, 80) })
    PlayerSec:Label({ Name = "Low health color" }):Colorpicker({ Flag = "player_health_low_col", Default = Color3.fromRGB(255, 50, 50) })
    local htextToggle = PlayerSec:Toggle({ Name = "Health number", Flag = "player_health_text", Default = true })
    htextToggle:Colorpicker({ Flag = "player_health_text_col", Default = Color3.new(1, 1, 1) })
    PlayerSec:Slider({ Name = "Max health", Flag = "player_maxhealth", Default = 100, Min = 1, Max = 500, Decimals = 1 })

    PlayerSec:Slider({ Name = "Max distance (max = no limit)", Flag = "player_maxdist", Default = MAX_DIST_UNLIMITED, Min = 25, Max = MAX_DIST_UNLIMITED, Decimals = 1, Suffix = "m" })

    local acToggle = PlayerSec:Toggle({ Name = "Active car", Flag = "player_activecar", Default = true })
    acToggle:Colorpicker({ Flag = "player_activecar_col", Default = Color3.fromRGB(180, 220, 255), Alpha = 1 })
    PlayerSec:Toggle({ Name = "Status (wanted / jailed)", Flag = "player_status", Default = true })
    local statusCustom = PlayerSec:Toggle({ Name = "Override status color", Flag = "player_status_use_custom", Default = false })
    statusCustom:Colorpicker({ Flag = "player_status_col", Default = Color3.fromRGB(255, 80, 80), Alpha = 1 })

    ----------------------------------------------------------------
    -- Cars page
    ----------------------------------------------------------------
    local CarsPage = Window:Page({ Name = "Cars" })
    local CarESPSP = CarsPage:SubPage({ Name = "Car ESP" })

    local CarSec = CarESPSP:Section({ Name = "Car ESP", Side = 1 })
    CarSec:Toggle({ Name = "Enabled", Flag = "car_esp", Default = false })
    local carDistToggle = CarSec:Toggle({ Name = "Distance", Flag = "car_esp_distance", Default = true })
    carDistToggle:Colorpicker({ Flag = "car_esp_distance_col", Default = Color3.new(1, 1, 1), Alpha = 1 })
    local carNameToggle = CarSec:Toggle({ Name = "Name", Flag = "car_esp_name", Default = true })
    carNameToggle:Colorpicker({ Flag = "car_esp_name_col", Default = Color3.new(1, 1, 1), Alpha = 1 })
    CarSec:Slider({ Name = "Max distance (max = no limit)", Flag = "car_maxdist", Default = MAX_DIST_UNLIMITED, Min = 25, Max = MAX_DIST_UNLIMITED, Decimals = 1, Suffix = "m" })

    local TPSP = CarsPage:SubPage({ Name = "Teleport" })
    local LocSec = TPSP:Section({ Name = "Locations", Side = 1 })
    LocSec:Button():Add("Teleport to Plug", function()
        task.spawn(Safe, "TPPlug", TeleportToPlug)
    end)
    LocSec:Button():Add("Teleport to Chop Shop", function()
        task.spawn(Safe, "TPChop", TeleportToChopShop)
    end)
    LocSec:Button():Add("Teleport to Arms Dealer", function()
        task.spawn(Safe, "TPArms", TeleportToArmsDealer)
    end)

    local CarTPSec = TPSP:Section({ Name = "Cars", Side = 2 })
    -- Created before the dropdown so the first list already respects it.
    CarTPSec:Toggle({
        Name = "Hide cars someone is driving",
        Flag = "car_tp_hide_driven",
        Default = true,
        Callback = function()
            if CarList.Dropdown then Safe("CarListRefresh", function() CarList:Refresh(true) end) end
        end,
    })
    local initialLabels, initialMap = CarList:Build()
    CarList.Map = initialMap
    CarList.Signature = table.concat(initialLabels, "\0")
    CarList.Dropdown = CarTPSec:Dropdown({
        Name = "Select car",
        Flag = "car_tp_pick",
        Items = initialLabels,
        Callback = function(label) CarList:OnPick(label) end,
    })

    local tpBtn = CarTPSec:Button()
    tpBtn:Add("Teleport to car", function()
        task.spawn(Safe, "TPCar", function()
            local model = CarList:Selected()
            if not model then
                -- Picked car despawned: rebuild so the dropdown shows what exists now.
                CarList:Refresh(true)
                warn("[Striker Boys] Selected car is gone, list refreshed - pick again.")
                return
            end
            TeleportToCar(model)
        end)
    end)
    tpBtn:Add("Refresh car list", function()
        Safe("CarListRefresh", function() CarList:Refresh(true) end)
    end)

    local PlayerTPSec = TPSP:Section({ Name = "Players", Side = 1 })
    local plabels, pmap = PlayerList:Build()
    PlayerList.Map = pmap
    PlayerList.Dropdown = PlayerTPSec:Dropdown({
        Name = "Select player",
        Flag = "player_tp_pick",
        Items = plabels,
        Callback = function(label)
            PlayerList.Picked = label and PlayerList.Map[label] or nil
        end,
    })
    local ptpBtn = PlayerTPSec:Button()
    ptpBtn:Add("Teleport to player", function()
        task.spawn(Safe, "TPPlayer", function()
            local p = PlayerList:Selected()
            if not p then
                PlayerList:Refresh()
                warn("[Striker Boys] Pick a player first (list refreshed).")
                return
            end
            local ok, err = TeleportToPlayer(p)
            if not ok then warn("[Striker Boys] " .. tostring(err)) end
        end)
    end)
    ptpBtn:Add("Refresh player list", function()
        Safe("PlayerListRefresh", function() PlayerList:Refresh() end)
    end)
    -- Keep the list current as people join/leave.
    table.insert(Connections, Players.PlayerAdded:Connect(function()
        Safe("PlayerListAdd", function() PlayerList:Refresh() end)
    end))
    table.insert(Connections, Players.PlayerRemoving:Connect(function()
        task.defer(function() Safe("PlayerListRemove", function() PlayerList:Refresh() end) end)
    end))

    local BoostSP = CarsPage:SubPage({ Name = "Boost" })
    local BoostSec = BoostSP:Section({ Name = "Speed Boost", Side = 1 })
    BoostSec:Toggle({ Name = "Enabled (while driving)", Flag = "boost_enabled", Default = false })
    BoostSec:Slider({ Name = "Torque multiplier", Flag = "boost_torque", Default = 2, Min = 1, Max = 6, Decimals = 0.1, Suffix = "x" })
    BoostSec:Label({ Name = "Multiplies the car's stock torque." })
    BoostSec:Label({ Name = "Raises acceleration and top speed." })
    BoostSec:Label({ Name = "~2x is quick; high values spin/flip it." })

    local ToolsSec = BoostSP:Section({ Name = "Car Tools", Side = 2 })
    ToolsSec:Button():Add("Fix car (flip upright)", function()
        Safe("FixCar", FixCar)
    end)
    ToolsSec:Dropdown({ Name = "Fix car hotkey", Flag = "fixcar_key", Items = FIXCAR_KEYS, Default = "None" })
    ToolsSec:Label({ Name = "Works while you're in the driver seat." })

    ----------------------------------------------------------------
    -- Self page
    ----------------------------------------------------------------
    local SelfPage = Window:Page({ Name = "Self" })
    local MoveSP = SelfPage:SubPage({ Name = "Movement" })

    local MoveSec = MoveSP:Section({ Name = "Movement", Side = 1 })
    MoveSec:Toggle({ Name = "Walk speed", Flag = "mv_ws_enabled", Default = false })
    MoveSec:Slider({ Name = "Walk speed", Flag = "mv_ws", Default = 16, Min = 8, Max = 200, Decimals = 1 })
    MoveSec:Toggle({ Name = "Jump power", Flag = "mv_jp_enabled", Default = false })
    MoveSec:Slider({ Name = "Jump power", Flag = "mv_jp", Default = 50, Min = 20, Max = 500, Decimals = 1 })
    MoveSec:Toggle({ Name = "Noclip", Flag = "mv_noclip", Default = false })
    MoveSec:Toggle({ Name = "Infinite jump", Flag = "mv_infjump", Default = false })

    local AntiBustSec = MoveSP:Section({ Name = "Anti Bust", Side = 2 })
    AntiBustSec:Toggle({ Name = "Enabled", Flag = "antibust_enabled", Default = false })
    AntiBustSec:Slider({ Name = "Trigger at bust meter", Flag = "antibust_threshold", Default = 1, Min = 1, Max = 90, Decimals = 1, Suffix = "%" })
    AntiBustSec:Slider({ Name = "Teleport distance", Flag = "antibust_dist", Default = 150, Min = 30, Max = 400, Decimals = 1, Suffix = " studs" })
    AntiBustSec:Toggle({ Name = "Pre-emptive (leave when cops get close)", Flag = "antibust_preempt", Default = true })
    AntiBustSec:Slider({ Name = "Pre-emptive range", Flag = "antibust_preempt_range", Default = 35, Min = 10, Max = 120, Decimals = 1, Suffix = " studs" })
    AntiBustSec:Label({ Name = "Cops bust within 22 studs, so keep it above that." })
    AntiBustSec:Label({ Name = "Takes your car with you if you're driving." })

    local SafeSec = MoveSP:Section({ Name = "Safe Spot", Side = 2 })
    SafeSec:Button():Add("Teleport to mountain", function()
        task.spawn(Safe, "TPMountain", function() TeleportToSpot(MOUNTAIN_TP) end)
    end)
    SafeSec:Label({ Name = "Brings your car if you're driving." })

    local HouseSP = SelfPage:SubPage({ Name = "Houses" })
    local HouseSec = HouseSP:Section({ Name = "Houses", Side = 1 })
    local houseLabels, houseMap = HouseList:Build()
    HouseList.Map = houseMap
    HouseList.Dropdown = HouseSec:Dropdown({
        Name = "Select house",
        Flag = "house_tp_pick",
        Items = houseLabels,
        Callback = function(label)
            HouseList.Picked = label and HouseList.Map[label] or nil
        end,
    })
    local houseBtn = HouseSec:Button()
    houseBtn:Add("Teleport to house", function()
        task.spawn(Safe, "TPHouse", function()
            local house = HouseList:Selected()
            if not house then
                warn("[Striker Boys] Pick a house first.")
                return
            end
            TeleportToHouse(house)
        end)
    end)
    houseBtn:Add("Refresh house list", function()
        Safe("HouseListRefresh", function() HouseList:Refresh() end)
    end)
    HouseSec:Label({ Name = "Lands at the front door (house lock)." })
    HouseSec:Label({ Name = "Brings your car if you're driving." })

    ----------------------------------------------------------------
    -- Farm page
    ----------------------------------------------------------------
    local FarmPage = Window:Page({ Name = "Farm" })
    local FarmSP = FarmPage:SubPage({ Name = "Auto Farm" })
    local FarmSec = FarmSP:Section({ Name = "Car Auto Farm", Side = 1 })
    AutoFarm.Toggle = FarmSec:Toggle({
        Name = "Enabled",
        Flag = "farm_enabled",
        Default = false,
        Callback = function(on)
            if on then AutoFarm:Start() else AutoFarm:Stop() end
        end,
    })
    FarmSec:Toggle({ Name = "Skip Kia / Hyundai / Honda", Flag = "farm_skip_charger", Default = true })
    FarmSec:Toggle({ Name = "Skip cars with cops nearby", Flag = "farm_avoid_cops", Default = true })
    FarmSec:Toggle({ Name = "Auto-buy keys from the Plug", Flag = "farm_auto_rebuy", Default = true })
    FarmSec:Slider({ Name = "Time on the ProPad", Flag = "farm_pad_time", Default = 18, Min = 10, Max = 40, Decimals = 1, Suffix = "s" })
    AutoFarm.StatusLabel = FarmSec:Label({ Name = "Status: " .. AutoFarm.Status })
    FarmSec:Button():Add("Retry skipped cars", function()
        table.clear(AutoFarm.BadCars)
        AutoFarm:SetStatus("Skipped list cleared")
    end)

    local FarmInfo = FarmSP:Section({ Name = "How it works", Side = 2 })
    FarmInfo:Label({ Name = "Smash glass > climb in > Autel > chop shop." })
    FarmInfo:Label({ Name = "No 'Climb in' after 5s = next car." })
    FarmInfo:Label({ Name = "Someone in the car = next car." })
    FarmInfo:Label({ Name = "Skipped cars wait 3 min before a retry." })
    FarmInfo:Label({ Name = "Dying pauses the farm for 2m30s." })
    FarmInfo:Label({ Name = "Needs: ProPad, window breaker, smart keys." })
    FarmInfo:Label({ Name = "Out of keys: auto-buys 5 at the Plug ($900 ea)." })
    FarmInfo:Label({ Name = "Tip: turn on Anti Bust (Self tab)." })

    ----------------------------------------------------------------
    -- World page
    ----------------------------------------------------------------
    local WorldPage = Window:Page({ Name = "World" })
    local LightSP = WorldPage:SubPage({ Name = "Lighting" })

    local FBSec = LightSP:Section({ Name = "Fullbright", Side = 1 })
    FBSec:Toggle({ Name = "Fullbright (overrides below)", Flag = "world_fullbright", Default = false })
    FBSec:Toggle({ Name = "No shadows", Flag = "world_no_shadows", Default = false })
    FBSec:Toggle({ Name = "No post FX (blur/bloom/CC)", Flag = "world_no_postfx", Default = false })

    local AmbSec = LightSP:Section({ Name = "Ambient / Brightness", Side = 1 })
    local ambToggle = AmbSec:Toggle({ Name = "Ambient color", Flag = "world_ambient_enabled", Default = false })
    ambToggle:Colorpicker({ Flag = "world_ambient_col", Default = Color3.new(1, 1, 1), Alpha = 1 })
    AmbSec:Toggle({ Name = "Brightness", Flag = "world_brightness_enabled", Default = false })
    AmbSec:Slider({ Name = "Brightness", Flag = "world_brightness", Default = 2, Min = 0, Max = 10, Decimals = 0.1 })

    local TimeSec = LightSP:Section({ Name = "Time of day", Side = 2 })
    TimeSec:Toggle({ Name = "Override clock time", Flag = "world_time_enabled", Default = false })
    TimeSec:Slider({ Name = "Hour", Flag = "world_time", Default = 14, Min = 0, Max = 24, Decimals = 0.1 })

    local FogSec = LightSP:Section({ Name = "Fog", Side = 2 })
    FogSec:Toggle({ Name = "Override fog", Flag = "world_fog_enabled", Default = false })
    FogSec:Slider({ Name = "Fog start", Flag = "world_fog_start", Default = 0, Min = 0, Max = 10000, Decimals = 1 })
    FogSec:Slider({ Name = "Fog end", Flag = "world_fog_end", Default = 100000, Min = 100, Max = 1000000, Decimals = 1 })
    local fogColorToggle = FogSec:Label({ Name = "Fog color" })
    fogColorToggle:Colorpicker({ Flag = "world_fog_col", Default = Color3.new(1, 1, 1), Alpha = 1 })

    local StatusSP = SelfPage:SubPage({ Name = "Status HUD" })
    local SHSec = StatusSP:Section({ Name = "Status HUD", Side = 1 })
    SHSec:Toggle({ Name = "Enabled", Flag = "status_hud", Default = false })
    SHSec:Slider({ Name = "X position", Flag = "status_hud_x", Default = 20, Min = 0, Max = 3000, Decimals = 1 })
    SHSec:Slider({ Name = "Y position", Flag = "status_hud_y", Default = 120, Min = 0, Max = 2000, Decimals = 1 })
    SHSec:Label({ Name = "Shows: Heat, Hunger, Stamina, Bust, Jail, Impound" })
end

BuildUI()
Window:InitWindow()

----------------------------------------------------------------
-- Populate ESP entries + wire up workspace watchers
----------------------------------------------------------------
for _, player in ipairs(Players:GetPlayers()) do
    ESP.Players:Make(player)
end
table.insert(Connections, Players.PlayerAdded:Connect(function(p) ESP.Players:Make(p) end))
table.insert(Connections, Players.PlayerRemoving:Connect(function(p) ESP.Players:Remove(p) end))

-- Car list: initial sync, instant refresh on add/remove, plus a 2s poll that
-- catches cars renamed after spawning or the Targets folder being replaced.
CarList:Refresh(true)
local function WatchTargets(folder)
    table.insert(Connections, folder.ChildAdded:Connect(function() CarList:Schedule() end))
    table.insert(Connections, folder.ChildRemoved:Connect(function() CarList:Schedule() end))
end
local WatchedFolder = GetTargets()
if WatchedFolder then WatchTargets(WatchedFolder) end

task.spawn(function()
    while Running do
        task.wait(2)
        if not Running then break end
        Safe("CarListPoll", function()
            local folder = GetTargets()
            if folder and folder ~= WatchedFolder then
                WatchedFolder = folder
                WatchTargets(folder)
            end
            CarList:Refresh(false)
        end)
    end
end)

----------------------------------------------------------------
-- Auto farm hooks: death pause + server game events (ProPad / Objective)
----------------------------------------------------------------
if LocalPlayer.Character then task.spawn(FarmBindCharacter, LocalPlayer.Character) end
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function(c)
    task.spawn(FarmBindCharacter, c)
end))

task.spawn(function()
    local cg = ReplicatedStorage:WaitForChild("CarGame", 15)
    local remotes = cg and cg:WaitForChild("Remotes", 15)
    local gameEvent = remotes and remotes:WaitForChild("Game", 15)
    if not (gameEvent and Running) then return end
    table.insert(Connections, gameEvent.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        if data.Type == "ProPad" and data.Car then
            AutoFarm.LastPad = { Car = data.Car, ReadSecs = data.ReadSecs, ProgSecs = data.ProgSecs, T = os.clock() }
        elseif data.Type == "Objective" then
            AutoFarm.Objective = { Text = data.Text, T = os.clock() }
        end
    end))
end)

----------------------------------------------------------------
-- Render loop
----------------------------------------------------------------
table.insert(Connections, RunService.RenderStepped:Connect(function()
    for _, entry in pairs(ESP.Players) do
        if typeof(entry) == "table" then Safe("PlayerESP", entry.Update, entry) end
    end
    Safe("CarESP", function() CarESP:Update() end)
    Safe("StatusHUD", function() StatusHUD:Update() end)
    Safe("CarBoost", function() CarBoost:Update() end)
    Safe("World", function() World:Update() end)
    Safe("Movement", function() Movement:Step() end)
    Safe("AntiBust", function() AntiBust:Update() end)
end))

-- Noclip runs on Stepped so CanCollide is cleared before physics tick.
table.insert(Connections, RunService.Stepped:Connect(function()
    Safe("Noclip", NoclipStep)
end))

----------------------------------------------------------------
-- Unload
----------------------------------------------------------------
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.End then
        Library:Exit()
        return
    end
    local fixKey = Flag("fixcar_key")
    if fixKey and fixKey ~= "None" and input.KeyCode == Enum.KeyCode[fixKey] then
        Safe("FixCar", FixCar)
    end
end))

-- Each step runs on its own so one failure can't leave drawings on screen.
OnUnload = function()
    if not Running then return end
    Running = false

    AutoFarm.Active = false
    AutoFarm.StatusLabel = nil
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)

    Safe("Unload.PlayerESP", function()
        local list = {}
        for player in pairs(ESP.Players) do
            if typeof(player) == "Instance" then list[#list + 1] = player end
        end
        for _, player in ipairs(list) do ESP.Players:Remove(player) end
    end)
    Safe("Unload.CarESP", function()
        local list = {}
        for model in pairs(CarESP.Entries) do list[#list + 1] = model end
        for _, model in ipairs(list) do CarESP:Remove(model) end
    end)
    Safe("Unload.StatusHUD", function() StatusHUD:Destroy() end)
    Safe("Unload.CarBoost", function() CarBoost:Restore() end)
    Safe("Unload.World", function() World:Restore() end)
    Safe("Unload.Movement", function() Movement:Restore() end)

    if getgenv().StrikerBoys_Unload == OnUnload then
        getgenv().StrikerBoys_Unload = nil
    end
end
getgenv().StrikerBoys_Unload = OnUnload
