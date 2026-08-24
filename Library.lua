local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService');
local TweenService = game:GetService('TweenService');
local Lighting = game:GetService('Lighting');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);
ScreenGui.Name = "MikuModularGui";
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
ScreenGui.DisplayOrder = 2147483646;
ScreenGui.ResetOnSpawn = false;
ScreenGui.Parent = (gethui and gethui()) or CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

-- // Design tokens
local RADIUS = {
    Dock = 14;
    Window = 12;
    Groupbox = 8;
    Control = 6;
    Small = 5;
};

local TI_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
local TI_SMOOTH = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
local TI_SOFT = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out);
local TI_POP = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out);

local Library = {
    Registry = {};
    RegistryMap = {};
    HudRegistry = {};

    FontColor = Color3.fromRGB(240, 243, 250);
    MainColor = Color3.fromRGB(29, 33, 41);
    BackgroundColor = Color3.fromRGB(18, 20, 26);
    AccentColor = Color3.fromRGB(140, 82, 255);
    OutlineColor = Color3.fromRGB(56, 62, 76);
    RiskColor = Color3.fromRGB(255, 73, 94);
    DimColor = Color3.fromRGB(158, 165, 180);

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.GothamMedium;

    OpenedFrames = {};
    DependencyBoxes = {};
    Signals = {};
    ScreenGui = ScreenGui;
    Toggled = true;
    Windows = {};
    Tabs = {};
    UseBlur = true;
    BlurSize = 18;
    Toggles = Toggles;
    Options = Options;
    Radius = RADIUS;
};

-- Background Blur
local BlurEffect;
pcall(function()
    BlurEffect = Lighting:FindFirstChild("MikuUiBlur");
    if not BlurEffect then
        BlurEffect = Instance.new("BlurEffect");
        BlurEffect.Name = "MikuUiBlur";
        BlurEffect.Size = 0;
        BlurEffect.Enabled = false;
        BlurEffect.Parent = Lighting;
    end
end);
Library.BlurEffect = BlurEffect;

function Library:SetBlur(enabled)
    if not BlurEffect then return end
    if enabled and Library.UseBlur then
        BlurEffect.Enabled = true;
        TweenService:Create(BlurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Library.BlurSize or 18
        }):Play();
    else
        local tween = TweenService:Create(BlurEffect, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = 0
        });
        tween:Play();
        task.delay(0.25, function()
            if not Library.Toggled or not Library.UseBlur then
                BlurEffect.Enabled = false;
            end
        end);
    end
end

function Library:UpdateBlur()
    if not BlurEffect then return end
    if Library.Toggled and Library.UseBlur then
        BlurEffect.Enabled = true;
        BlurEffect.Size = Library.BlurSize or 18;
    else
        BlurEffect.Enabled = false;
        BlurEffect.Size = 0;
    end
end

local RainbowStep = 0;
local Hue = 0;

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta;
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0;
        Hue = Hue + (1 / 400);
        if Hue > 1 then Hue = 0; end
        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end));

local function Tween(instance, info, properties)
    local tween = TweenService:Create(instance, info, properties);
    tween:Play();
    return tween;
end

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();
    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end
    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);
    return PlayerList;
end

local function GetTeamsString()
    local TeamList = Teams:GetTeams();
    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end
    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    return TeamList;
end

function Library:SafeCallback(f, ...)
    if not f then return end
    local success, event = pcall(f, ...);
    if not success and Library.NotifyOnError then
        local _, i = tostring(event):find(":%d+: ");
        if not i then return Library:Notify(tostring(event)); end
        return Library:Notify(tostring(event):sub(i + 1), 3);
    end
end

function Library:AttemptSave()
    if Library.SaveManager then
        pcall(function() Library.SaveManager:Save(); end);
    end
end

function Library:Create(Class, Properties)
    local _Instance = Class;
    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end
    for Property, Value in next, Properties or {} do
        _Instance[Property] = Value;
    end
    return _Instance;
end

function Library:IsPointerInput(Input)
    return Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch;
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        Transparency = 0.6;
        LineJoinMode = Enum.LineJoinMode.Round;
        Parent = Inst;
    });
end

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 13;
        TextStrokeTransparency = 1;
    });

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end

local ShadowAsset = 'rbxassetid://6014261993';

function Library:AddShadow(Target, Expand, Transparency, ZIndex)
    return Library:Create('ImageLabel', {
        Name = 'Shadow';
        BackgroundTransparency = 1;
        Image = ShadowAsset;
        ImageColor3 = Color3.new(0, 0, 0);
        ImageTransparency = Transparency or 0.42;
        ScaleType = Enum.ScaleType.Slice;
        SliceCenter = Rect.new(49, 49, 450, 450);
        AnchorPoint = Vector2.new(0.5, 0.5);
        Position = UDim2.fromScale(0.5, 0.5);
        Size = UDim2.new(1, Expand or 70, 1, Expand or 70);
        ZIndex = ZIndex or math.max(Target.ZIndex - 1, 0);
        Parent = Target;
    });
end

function Library:MakeDraggable(Instance, DragHandle)
    Instance.Active = true;
    local handle = DragHandle or Instance;
    local dragging = false;
    local dragInput, dragStart, startPos;

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true;
            dragStart = input.Position;
            startPos = Instance.Position;

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false;
                end
            end);
        end
    end);

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input;
        end
    end);

    InputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart;
            Instance.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            );
        end
    end);
end

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 12);
    local Tooltip = Library:Create('CanvasGroup', {
        GroupTransparency = 1;
        BackgroundColor3 = Library.BackgroundColor,
        Size = UDim2.fromOffset(X + 16, Y + 10),
        ZIndex = 5000,
        Visible = false,
        Parent = ScreenGui,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = Tooltip });
    Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = Tooltip });

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(8, 5),
        Size = UDim2.fromOffset(X, Y),
        TextSize = 12,
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5001,
        Parent = Tooltip,
    });

    local IsHovering = false;
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true;
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 16, Mouse.Y + 12);
        Tooltip.Visible = true;
        Tween(Tooltip, TI_FAST, { GroupTransparency = 0 });
        while IsHovering do
            RunService.Heartbeat:Wait();
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 16, Mouse.Y + 12);
        end
    end);

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false;
        Tooltip.Visible = false;
    end);
end

function Library:OnHighlight(HighlightInstance, TargetInstance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[TargetInstance];
        for Property, ColorIdx in next, Properties do
            local col = Library[ColorIdx] or ColorIdx;
            Tween(TargetInstance, TI_SMOOTH, { [Property] = col });
            if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx; end
        end
    end);

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[TargetInstance];
        for Property, ColorIdx in next, PropertiesDefault do
            local col = Library[ColorIdx] or ColorIdx;
            Tween(TargetInstance, TI_SMOOTH, { [Property] = col });
            if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx; end
        end
    end);
end

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        if Frame and Frame.Parent and Frame.Visible then
            local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
            if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
                and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
                return true;
            end
        end
    end
    return false;
end

function Library:IsMouseOverFrame(Frame)
    if not Frame or not Frame.Parent then return false end
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
        return true;
    end
    return false;
end

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        if Depbox and Depbox.Update then Depbox:Update(); end
    end
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    if MaxA == MinA then return MinB end
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(tostring(Text), Size, Font or Library.Font, Resolution or Vector2.new(1920, 1080));
    return Bounds.X, Bounds.Y;
end

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = { Instance = Instance, Properties = Properties, Idx = Idx };
    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;
    if IsHud then table.insert(Library.HudRegistry, Data); end
end

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then table.remove(Library.Registry, Idx); end
        end
        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then table.remove(Library.HudRegistry, Idx); end
        end
        Library.RegistryMap[Instance] = nil;
    end
end

function Library:UpdateColorsUsingRegistry()
    for _, Object in next, Library.Registry do
        if Object.Instance and Object.Instance.Parent then
            for Property, ColorIdx in next, Object.Properties do
                if type(ColorIdx) == 'string' then
                    Object.Instance[Property] = Library[ColorIdx];
                elseif type(ColorIdx) == 'function' then
                    Object.Instance[Property] = ColorIdx();
                end
            end
        end
    end
end

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal);
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx);
        pcall(function() Connection:Disconnect(); end);
    end
    if Library.OnUnload then pcall(Library.OnUnload); end
    if BlurEffect then pcall(function() BlurEffect:Destroy(); end); end
    ScreenGui:Destroy();
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback;
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then Library:RemoveFromRegistry(Instance); end
end));

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);
            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end
        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('TextButton', {
            BackgroundColor3 = ColorPicker.Value;
            Size = UDim2.new(0, 24, 0, 14);
            Text = '';
            AutoButtonColor = false;
            ZIndex = 20;
            Parent = ToggleLabel;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Small), Parent = DisplayFrame });
        local DisplayStroke = Library:Create('UIStroke', { Color = Library:GetDarkerColor(ColorPicker.Value), Thickness = 1, Parent = DisplayFrame });
        DisplayFrame.MouseEnter:Connect(function() Tween(DisplayStroke, TI_FAST, { Color = Library.FontColor }); end);
        DisplayFrame.MouseLeave:Connect(function() Tween(DisplayStroke, TI_FAST, { Color = Library:GetDarkerColor(ColorPicker.Value) }); end);

        local PickerFrameOuter = Library:Create('CanvasGroup', {
            Name = 'Color';
            GroupTransparency = 1;
            BackgroundColor3 = Library.BackgroundColor;
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 20),
            Size = UDim2.fromOffset(230, 255);
            Visible = false;
            ZIndex = 3000;
            Parent = ScreenGui,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 10), Parent = PickerFrameOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1.5, Parent = PickerFrameOuter });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 20);
        end);

        local SatVibMapOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            Position = UDim2.new(0, 8, 0, 25),
            Size = UDim2.new(0, 192, 0, 192),
            ZIndex = 3001;
            Parent = PickerFrameOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = SatVibMapOuter });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 3002;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = SatVibMap });

        local CursorOuter = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 10, 0, 10);
            BackgroundColor3 = Color3.new(1, 1, 1);
            ZIndex = 3003;
            Parent = SatVibMap;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = CursorOuter });
        Library:Create('UIStroke', { Color = Color3.new(0, 0, 0), Thickness = 1.5, Parent = CursorOuter });

        local HueSelectorOuter = Library:Create('Frame', {
            Position = UDim2.new(0, 206, 0, 25);
            Size = UDim2.new(0, 16, 0, 192);
            ZIndex = 3001;
            Parent = PickerFrameOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = HueSelectorOuter });

        local HueSelectorInner = Library:Create('Frame', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 3002;
            Parent = HueSelectorOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = HueSelectorInner });

        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 3003;
            Parent = HueSelectorInner;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = HueCursor });
        Library:Create('UIStroke', { Color = Color3.new(0, 0, 0), Thickness = 1, Parent = HueCursor });

        local HueBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            Position = UDim2.fromOffset(8, 224),
            Size = UDim2.new(1, -16, 0, 22),
            ZIndex = 3001,
            Parent = PickerFrameOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = HueBoxOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = HueBoxOuter });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -16, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(140, 140, 150);
            PlaceholderText = 'Hex color (#FFFFFF)',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 12;
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex = 3002,
            Parent = HueBoxOuter;
        });

        local SequenceTable = {};
        for H = 0, 1, 0.1 do table.insert(SequenceTable, ColorSequenceKeypoint.new(H, Color3.fromHSV(H, 1, 1))); end
        Library:Create('UIGradient', { Color = ColorSequence.new(SequenceTable), Rotation = 90, Parent = HueSelectorInner });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text);
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result);
                end
            end
            ColorPicker:Display();
        end);

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);
            DisplayFrame.BackgroundColor3 = ColorPicker.Value;
            DisplayStroke.Color = Library:GetDarkerColor(ColorPicker.Value);

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);
            HueBox.Text = '#' .. ColorPicker.Value:ToHex();

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end

        function ColorPicker:OnChanged(Func) ColorPicker.Changed = Func; Func(ColorPicker.Value); end
        function ColorPicker:Show()
            for Frame, _ in next, Library.OpenedFrames do
                if Frame and Frame.Name == 'Color' then Frame.Visible = false; Library.OpenedFrames[Frame] = nil; end
            end
            PickerFrameOuter.GroupTransparency = 1;
            PickerFrameOuter.Visible = true;
            Tween(PickerFrameOuter, TI_SOFT, { GroupTransparency = 0 });
            Library.OpenedFrames[PickerFrameOuter] = true;
        end
        function ColorPicker:Hide() PickerFrameOuter.Visible = false; Library.OpenedFrames[PickerFrameOuter] = nil; end

        function ColorPicker:SetValue(HSV, Transparency)
            if typeof(HSV) == 'Color3' then ColorPicker:SetValueRGB(HSV, Transparency); return; end
            if type(HSV) == 'string' then
                local s, c = pcall(Color3.fromHex, HSV);
                if s and typeof(c) == 'Color3' then ColorPicker:SetValueRGB(c, Transparency); return; end
            end
            local Color = Color3.fromHSV(HSV[1] or 0, HSV[2] or 1, HSV[3] or 1);
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX, MaxX = SatVibMap.AbsolutePosition.X, SatVibMap.AbsolutePosition.X + SatVibMap.AbsoluteSize.X;
                    local MinY, MaxY = SatVibMap.AbsolutePosition.Y, SatVibMap.AbsolutePosition.Y + SatVibMap.AbsoluteSize.Y;
                    ColorPicker.Sat = (math.clamp(Mouse.X, MinX, MaxX) - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((math.clamp(Mouse.Y, MinY, MaxY) - MinY) / (MaxY - MinY));
                    ColorPicker:Display();
                    RenderStepped:Wait();
                end
                Library:AttemptSave();
            end
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY, MaxY = HueSelectorInner.AbsolutePosition.Y, HueSelectorInner.AbsolutePosition.Y + HueSelectorInner.AbsoluteSize.Y;
                    ColorPicker.Hue = (math.clamp(Mouse.Y, MinY, MaxY) - MinY) / (MaxY - MinY);
                    ColorPicker:Display();
                    RenderStepped:Wait();
                end
                Library:AttemptSave();
            end
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then ColorPicker:Hide(); else ColorPicker:Show(); end
            end
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and PickerFrameOuter.Visible then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X or Mouse.Y < AbsPos.Y or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    if not Library:IsMouseOverFrame(DisplayFrame) then ColorPicker:Hide(); end
                end
            end
        end));

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame;
        Options[Idx] = ColorPicker;
        return self;
    end

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;
            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then Info.Modes = { 'Toggle' }; Info.Mode = 'Toggle'; end

        local PickOuter = Library:Create('TextButton', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(0, 36, 0, 16);
            Text = '';
            AutoButtonColor = false;
            ZIndex = 20;
            Parent = ToggleLabel;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Small), Parent = PickOuter });
        local PickStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = PickOuter });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 11;
            Text = Info.Default;
            ZIndex = 21;
            Parent = PickOuter;
        });

        local ModeSelectOuter = Library:Create('CanvasGroup', {
            GroupTransparency = 1;
            BackgroundColor3 = Library.BackgroundColor;
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 6, ToggleLabel.AbsolutePosition.Y);
            Size = UDim2.new(0, 76, 0, 58);
            Visible = false;
            ZIndex = 3000;
            Parent = ScreenGui;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = ModeSelectOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = ModeSelectOuter });

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 6, ToggleLabel.AbsolutePosition.Y);
        end);

        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = ModeSelectOuter });

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for _, Mode in next, Modes do
            local ModeButton = {};
            local Btn = Library:Create('TextButton', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 19);
                Font = Library.Font;
                TextSize = 12;
                Text = Mode;
                TextColor3 = Library.FontColor;
                ZIndex = 3001;
                Parent = ModeSelectOuter;
            });

            Btn.MouseEnter:Connect(function() Tween(Btn, TI_FAST, { TextColor3 = Library.AccentColor }); end);
            Btn.MouseLeave:Connect(function()
                if KeyPicker.Mode ~= Mode then Tween(Btn, TI_FAST, { TextColor3 = Library.FontColor }); end
            end);

            function ModeButton:Select()
                for _, Button in next, ModeButtons do Button:Deselect(); end
                KeyPicker.Mode = Mode;
                Btn.TextColor3 = Library.AccentColor;
                ModeSelectOuter.Visible = false;
            end
            function ModeButton:Deselect() Btn.TextColor3 = Library.FontColor; end

            Btn.MouseButton1Click:Connect(function() ModeButton:Select(); Library:AttemptSave(); end);
            if Mode == KeyPicker.Mode then ModeButton:Select(); end
            ModeButtons[Mode] = ModeButton;
        end

        -- Optional keybind list entry (shown when Library.KeybindFrame is visible)
        local BindRow;
        if (not Info.NoUI) and Library.KeybindContainer then
            BindRow = Library:CreateLabel({
                Size = UDim2.new(1, -12, 0, 18);
                Position = UDim2.new(0, 8, 0, 0);
                TextSize = 12;
                Text = string.format('[%s] %s', tostring(KeyPicker.Value), tostring(Info.Text or Idx));
                TextColor3 = Library.DimColor;
                TextXAlignment = Enum.TextXAlignment.Left;
                LayoutOrder = #Library.KeybindContainer:GetChildren();
                ZIndex = 102;
                Parent = Library.KeybindContainer;
            });

            function KeyPicker:UpdateBindRow()
                if not BindRow then return end
                BindRow.Text = string.format('[%s] %s', tostring(KeyPicker.Value), tostring(Info.Text or Idx));
                if KeyPicker.Mode == 'Toggle' and KeyPicker.Toggled then
                    Tween(BindRow, TI_FAST, { TextColor3 = Library.AccentColor });
                else
                    Tween(BindRow, TI_FAST, { TextColor3 = Library.DimColor });
                end
            end
            KeyPicker:UpdateBindRow();
            if Library.ResizeKeybindFrame then Library.ResizeKeybindFrame(); end
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then return false; end
                local key = KeyPicker.Value;
                if key == 'MB1' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1);
                elseif key == 'MB2' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    local code = Enum.KeyCode[key];
                    if code then return InputService:IsKeyDown(code); end
                end
            else
                return KeyPicker.Toggled;
            end
            return false;
        end

        function KeyPicker:SetValue(Key, Mode)
            if type(Key) == 'table' then
                Mode = Key[2] or Key.Mode or Key.mode or Mode;
                Key = Key[1] or Key.Key or Key.key or Key.Value or 'None';
            end
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            if Mode and ModeButtons[Mode] then ModeButtons[Mode]:Select(); end
            if KeyPicker.UpdateBindRow then KeyPicker:UpdateBindRow(); end
        end

        function KeyPicker:OnClick(Callback) KeyPicker.Clicked = Callback; end
        function KeyPicker:OnChanged(Callback) KeyPicker.Changed = Callback; Callback(KeyPicker.Value); end

        if ParentObj.Addons then table.insert(ParentObj.Addons, KeyPicker); end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value);
            end
            if KeyPicker.UpdateBindRow then KeyPicker:UpdateBindRow(); end
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled);
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled);
        end

        local Picking = false;
        local lastBind = 0;

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;
                lastBind = tick();
                DisplayLabel.Text = '...';
                Tween(PickStroke, TweenInfo.new(0.2), { Color = Library.AccentColor });

                local Event;
                Event = InputService.InputBegan:Connect(function(KeyInput)
                    local Key;
                    if KeyInput.UserInputType == Enum.UserInputType.Keyboard then Key = KeyInput.KeyCode.Name;
                    elseif KeyInput.UserInputType == Enum.UserInputType.MouseButton1 then Key = 'MB1';
                    elseif KeyInput.UserInputType == Enum.UserInputType.MouseButton2 then Key = 'MB2'; end

                    -- Escape cancels rebinding without changing anything
                    if KeyInput.UserInputType == Enum.UserInputType.Keyboard and KeyInput.KeyCode == Enum.KeyCode.Escape then
                        Picking = false;
                        lastBind = tick();
                        DisplayLabel.Text = tostring(KeyPicker.Value);
                        Tween(PickStroke, TweenInfo.new(0.2), { Color = Library.OutlineColor });
                        Event:Disconnect();
                        return;
                    end

                    Picking = false;
                    lastBind = tick();
                    Tween(PickStroke, TweenInfo.new(0.2), { Color = Library.OutlineColor });
                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;
                    if KeyPicker.UpdateBindRow then KeyPicker:UpdateBindRow(); end
                    Library:SafeCallback(KeyPicker.ChangedCallback, KeyInput.KeyCode or KeyInput.UserInputType);
                    Library:SafeCallback(KeyPicker.Changed, KeyInput.KeyCode or KeyInput.UserInputType);
                    Library:AttemptSave();
                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
                Tween(ModeSelectOuter, TI_FAST, { GroupTransparency = 0 });
            end
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            local justRebound = (tick() - lastBind) < 0.25;
            if not Picking and not justRebound and KeyPicker.Mode == 'Toggle' then
                local Key = KeyPicker.Value;
                if (Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1)
                    or (Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2)
                    or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key) then
                    -- clicks landing on the picker box itself must never toggle the feature
                    if not Library:IsMouseOverFrame(PickOuter) then
                        KeyPicker.Toggled = not KeyPicker.Toggled;
                        KeyPicker:DoClick();
                    end
                end
            end
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and ModeSelectOuter.Visible then
                if not Library:IsMouseOverFrame(ModeSelectOuter) and not Library:IsMouseOverFrame(PickOuter) then
                    ModeSelectOuter.Visible = false;
                end
            end
        end));

        Options[Idx] = KeyPicker;
        return self;
    end

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...) return Funcs[Key](...); end
end

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size or 6);
            ZIndex = 1;
            Parent = Groupbox.Container;
        });
    end

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};
        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -8, 0, 16);
            TextSize = 13;
            Text = Text or '';
            TextWrapped = DoesWrap or false;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 2;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text or '', Library.Font, 13, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)));
            TextLabel.Size = UDim2.new(1, -8, 0, Y);
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 6);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(NewText)
            TextLabel.Text = NewText;
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(NewText, Library.Font, 13, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)));
                TextLabel.Size = UDim2.new(1, -8, 0, Y);
            end
            Groupbox:Resize();
        end

        if not DoesWrap then setmetatable(Label, BaseAddons); end
        Groupbox:AddBlank(4);
        Groupbox:Resize();
        return Label;
    end

    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Obj, ...)
            local Props = select(1, ...);
            if type(Props) == 'table' then
                Obj.Text = Props.Text;
                Obj.Func = Props.Func;
                Obj.DoubleClick = Props.DoubleClick;
                Obj.Tooltip = Props.Tooltip;
            else
                Obj.Text = select(1, ...);
                Obj.Func = select(2, ...);
            end
            Obj.Func = Obj.Func or function() end;
        end
        ProcessButtonParams(Button, ...);

        local Groupbox = self;
        local Container = Groupbox.Container;

        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            Size = UDim2.new(1, -8, 0, 24);
            ZIndex = 2;
            Parent = Container;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = Outer });
        local Stroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.15, Thickness = 1, Parent = Outer });

        local BtnScale = Library:Create('UIScale', { Scale = 1, Parent = Outer });

        local Label = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 12;
            Text = Button.Text or 'Button';
            ZIndex = 3;
            Parent = Outer;
        });

        Outer.MouseEnter:Connect(function()
            Tween(Stroke, TI_SMOOTH, { Color = Library.AccentColor, Transparency = 0 });
            Tween(Outer, TI_SMOOTH, { BackgroundColor3 = Library.BackgroundColor });
        end);
        Outer.MouseLeave:Connect(function()
            Tween(Stroke, TI_SMOOTH, { Color = Library.OutlineColor, Transparency = 0.4 });
            Tween(Outer, TI_SMOOTH, { BackgroundColor3 = Library.MainColor });
        end);

        Outer.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Tween(BtnScale, TI_FAST, { Scale = 0.975 });
            end
        end);
        Outer.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tween(BtnScale, TI_POP, { Scale = 1 });
                if not Library:MouseIsOverOpenedFrame() then Library:SafeCallback(Button.Func); end
            end
        end);

        Button.Outer = Outer;
        Button.Label = Label;
        Button.TextLabel = Label;
        setmetatable(Button, BaseAddons);
        if type(Button.Tooltip) == 'string' then Library:AddToolTip(Button.Tooltip, Outer); end

        Groupbox:AddBlank(4);
        Groupbox:Resize();
        return Button;
    end

    function Funcs:AddDivider()
        local Groupbox = self;
        local Divider = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            BackgroundTransparency = 0.35;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -8, 0, 1);
            ZIndex = 2;
            Parent = Groupbox.Container;
        });
        Library:AddToRegistry(Divider, { BackgroundColor3 = 'OutlineColor' });
        Groupbox:AddBlank(6);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        Info = Info or {};
        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if Info.Text then
            Library:CreateLabel({
                Size = UDim2.new(1, -8, 0, 14);
                TextSize = 13;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 2;
                Parent = Container;
            });
            Groupbox:AddBlank(2);
        end

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, -8, 0, 24);
            ZIndex = 2;
            Parent = Container;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = TextBoxOuter });
        local BoxStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.15, Thickness = 1, Parent = TextBoxOuter });

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -16, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(130, 130, 145);
            PlaceholderText = Info.Placeholder or 'Type here...';
            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 12;
            TextXAlignment = Enum.TextXAlignment.Left;
            ClearTextOnFocus = false;
            ZIndex = 3;
            Parent = TextBoxOuter;
        });

        Box.Focused:Connect(function()
            Tween(BoxStroke, TI_SMOOTH, { Color = Library.AccentColor, Transparency = 0 });
        end);
        Box.FocusLost:Connect(function()
            Tween(BoxStroke, TI_SMOOTH, { Color = Library.OutlineColor, Transparency = 0.4 });
        end);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then Text = Text:sub(1, Info.MaxLength); end
            if Textbox.Numeric and (not tonumber(Text)) and Text:len() > 0 then Text = Textbox.Value; end
            Textbox.Value = Text;
            Box.Text = Text;
            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        function Textbox:OnChanged(Func) Textbox.Changed = Func; Func(Textbox.Value); end

        Groupbox:AddBlank(4);
        Groupbox:Resize();
        Options[Idx] = Textbox;
        return Textbox;
    end

    function Funcs:AddToggle(Idx, Info)
        Info = Info or {};
        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';
            Callback = Info.Callback or function(Value) end;
            Addons = {};
            Risky = Info.Risky;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleRow = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, -8, 0, 20);
            ZIndex = 2;
            Parent = Container;
        });

        local SwitchTrack = Library:Create('Frame', {
            BorderSizePixel = 0;
            BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.OutlineColor;
            Position = UDim2.new(0, 0, 0.5, -8);
            Size = UDim2.new(0, 34, 0, 16);
            ZIndex = 3;
            Parent = ToggleRow;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 5), Parent = SwitchTrack });

        local SwitchThumb = Library:Create('Frame', {
            BorderSizePixel = 0;
            BackgroundColor3 = Toggle.Value and Color3.new(1, 1, 1) or Library.DimColor;
            Position = Toggle.Value and UDim2.new(1, -13, 0.5, -5) or UDim2.new(0, 3, 0.5, -5);
            Size = UDim2.new(0, 10, 0, 10);
            ZIndex = 4;
            Parent = SwitchTrack;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 3), Parent = SwitchThumb });

        -- theme-aware: repaint existing toggles when accent changes (fixes stale color mismatch)
        Library:AddToRegistry(SwitchTrack, {
            BackgroundColor3 = function()
                return Toggle.Value and Library.AccentColor or Library.OutlineColor;
            end;
        });
        Library:AddToRegistry(SwitchThumb, {
            BackgroundColor3 = function()
                return Toggle.Value and Color3.new(1, 1, 1) or Library.DimColor;
            end;
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(1, -40, 1, 0);
            Position = UDim2.new(0, 40, 0, 0);
            TextSize = 13;
            Text = Info.Text or 'Toggle';
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 3;
            Parent = ToggleRow;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 6);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ClickRegion = Library:Create('TextButton', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, -80, 1, 0);
            Text = '';
            ZIndex = 5;
            Parent = ToggleRow;
        });

        function Toggle:Display()
            local trackCol = Toggle.Value and Library.AccentColor or Library.OutlineColor;
            local thumbCol = Toggle.Value and Color3.new(1, 1, 1) or Library.DimColor;
            local targetPos = Toggle.Value and UDim2.new(1, -13, 0.5, -5) or UDim2.new(0, 3, 0.5, -5);
            Tween(SwitchTrack, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = trackCol });
            Tween(SwitchThumb, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos, BackgroundColor3 = thumbCol });
        end

        function Toggle:OnChanged(Func) Toggle.Changed = Func; Func(Toggle.Value); end

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);
            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool;
                    if Addon.Update then Addon:Update(); end
                    if Addon.UpdateBindRow then Addon:UpdateBindRow(); end
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end

        ClickRegion.MouseButton1Click:Connect(function()
            if not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value);
                Library:AttemptSave();
            end
        end);

        if Toggle.Risky then ToggleLabel.TextColor3 = Library.RiskColor; end

        Toggle:Display();
        Groupbox:AddBlank(4);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;
        Library:UpdateDependencyBoxes();
        return Toggle;
    end

    function Funcs:AddSlider(Idx, Info)
        Info = Info or {};
        local Slider = {
            Value = Info.Default or Info.Min or 0;
            Min = Info.Min or 0;
            Max = Info.Max or 100;
            Rounding = Info.Rounding or 0;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local HeaderFrame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, -8, 0, 14);
            ZIndex = 2;
            Parent = Container;
        });

        Library:CreateLabel({
            Size = UDim2.new(0.65, 0, 1, 0);
            TextSize = 13;
            Text = Info.Text or 'Slider';
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 2;
            Parent = HeaderFrame;
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(0.35, 0, 1, 0);
            Position = UDim2.new(0.65, 0, 0, 0);
            TextSize = 13;
            Text = tostring(Slider.Value);
            TextColor3 = Library.AccentColor;
            TextXAlignment = Enum.TextXAlignment.Right;
            ZIndex = 2;
            Parent = HeaderFrame;
        });

        Groupbox:AddBlank(3);

        local Track = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -8, 0, 5);
            ZIndex = 2;
            Parent = Container;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Track });
        local TrackStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.35, Thickness = 1, Parent = Track });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 0, 1, 0),
            ZIndex = 3,
            Parent = Track,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Fill });

        -- slim caret knob instead of a chunky dot
        local Knob = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 3, 0, 11),
            ZIndex = 4,
            Parent = Fill,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 2), Parent = Knob });

        -- theme-aware colors
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' });
        Library:AddToRegistry(TrackStroke, { Color = 'OutlineColor' });
        Library:AddToRegistry(DisplayLabel, { TextColor3 = 'AccentColor' });

        local KnobBig = false;
        local function SetKnob(big)
            if KnobBig == big then return end
            KnobBig = big;
            Tween(Knob, TI_FAST, { Size = big and UDim2.new(0, 4, 0, 13) or UDim2.new(0, 3, 0, 11) });
        end
        Track.MouseEnter:Connect(function() SetKnob(true); end);
        Track.MouseLeave:Connect(function() SetKnob(false); end);
        Track.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then SetKnob(true); end
        end);
        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then SetKnob(false); end
        end));

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value + 0.5);
            end
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value)) or Value;
        end

        function Slider:Display()
            local Suffix = Info.Suffix or '';
            DisplayLabel.Text = string.format('%s%s', tostring(Slider.Value), Suffix);
            local fraction = math.clamp((Slider.Value - Slider.Min) / math.max(Slider.Max - Slider.Min, 0.0001), 0, 1);
            Tween(Fill, TweenInfo.new(0.06), { Size = UDim2.new(fraction, 0, 1, 0) });
        end

        function Slider:OnChanged(Func) Slider.Changed = Func; Func(Slider.Value); end

        function Slider:SetValue(Str)
            local Num = tonumber(Str);
            if not Num then return end
            Num = math.clamp(Num, Slider.Min, Slider.Max);
            Slider.Value = Round(Num);
            Slider:Display();
            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end

        Track.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local function UpdateFromMouse()
                    local trackPos = Track.AbsolutePosition.X;
                    local trackWidth = Track.AbsoluteSize.X;
                    local fraction = math.clamp((Mouse.X - trackPos) / trackWidth, 0, 1);
                    local nVal = Round(Slider.Min + (Slider.Max - Slider.Min) * fraction);
                    if nVal ~= Slider.Value then
                        Slider.Value = nVal;
                        Slider:Display();
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end
                end
                UpdateFromMouse();
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    UpdateFromMouse();
                    RenderStepped:Wait();
                end
                Library:AttemptSave();
            end
        end);

        Slider:Display();
        Groupbox:AddBlank(4);
        Groupbox:Resize();
        Options[Idx] = Slider;
        return Slider;
    end

    function Funcs:AddDropdown(Idx, Info)
        Info = Info or {};
        if Info.SpecialType == 'Player' then Info.Values = GetPlayersString(); Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then Info.Values = GetTeamsString(); Info.AllowNull = true; end

        Info.Values = Info.Values or {};
        local defaultVal;
        if Info.Multi then
            defaultVal = type(Info.Default) == 'table' and Info.Default or {};
        else
            if type(Info.Default) == 'number' and Info.Values[Info.Default] then
                defaultVal = Info.Values[Info.Default];
            else
                defaultVal = Info.Default or Info.Values[1];
            end
        end

        local Dropdown = {
            Values = Info.Values;
            Value = defaultVal;
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if Info.Text then
            Library:CreateLabel({
                Size = UDim2.new(1, -8, 0, 14);
                TextSize = 13;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 2;
                Parent = Container;
            });
            Groupbox:AddBlank(2);
        end

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, -8, 0, 24);
            ZIndex = 2;
            Parent = Container;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = DropdownOuter });
        local DropStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.15, Thickness = 1, Parent = DropdownOuter });
        Library:AddToRegistry(DropStroke, { Color = 'OutlineColor' });

        local ItemLabel = Library:CreateLabel({
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -30, 1, 0);
            TextSize = 12;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 3;
            Parent = DropdownOuter;
        });

        local Arrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -20, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ImageColor3 = Library.FontColor;
            ZIndex = 3;
            Parent = DropdownOuter;
        });

        local ListOuter = Library:Create('CanvasGroup', {
            GroupTransparency = 1;
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.fromOffset(200, 120);
            Visible = false;
            ZIndex = 4000;
            Parent = ScreenGui;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = ListOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = ListOuter });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ScrollBarThickness = 3;
            ScrollBarImageColor3 = Library.AccentColor;
            ZIndex = 4001;
            Parent = ListOuter;
        });

        local ListLayout = Library:Create('UIListLayout', {
            Padding = UDim.new(0, 2);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 4);
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, math.min(#Dropdown.Values * 24 + 6, 160));
            Scrolling.CanvasSize = UDim2.fromOffset(0, ListLayout.AbsoluteContentSize.Y);
        end

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        function Dropdown:Display()
            if Info.Multi then
                local str = '';
                for _, val in next, Dropdown.Values do
                    if Dropdown.Value[val] then str = str .. val .. ', '; end
                end
                str = str:sub(1, #str - 2);
                ItemLabel.Text = (str == '' and '--' or str);
            else
                ItemLabel.Text = (Dropdown.Value or '--');
            end
        end

        function Dropdown:BuildDropdownList()
            for _, child in next, Scrolling:GetChildren() do
                if not child:IsA('UIListLayout') then child:Destroy(); end
            end
            for _, val in next, Dropdown.Values do
                local Btn = Library:Create('TextButton', {
                    AutoButtonColor = false;
                    BackgroundColor3 = Library.MainColor;
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, -4, 0, 22);
                    Position = UDim2.new(0, 2, 0, 0);
                    Font = Library.Font;
                    Text = '  ' .. tostring(val);
                    TextColor3 = Library.FontColor;
                    TextSize = 12;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 4002;
                    Parent = Scrolling;
                });
                Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Small), Parent = Btn });

                Btn.MouseEnter:Connect(function()
                    local isSelected = Info.Multi and Dropdown.Value[val] or (Dropdown.Value == val);
                    Tween(Btn, TI_FAST, { BackgroundTransparency = isSelected and 0.4 or 0.75, TextColor3 = Library.AccentColor });
                end);
                Btn.MouseLeave:Connect(function()
                    local isSelected = Info.Multi and Dropdown.Value[val] or (Dropdown.Value == val);
                    Tween(Btn, TI_FAST, { BackgroundTransparency = isSelected and 0.55 or 1, TextColor3 = isSelected and Library.AccentColor or Library.FontColor });
                end);

                Btn.MouseButton1Click:Connect(function()
                    if Info.Multi then Dropdown.Value[val] = not Dropdown.Value[val];
                    else Dropdown.Value = val; Dropdown:Close(); end
                    Dropdown:Display();
                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                    Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
                    Library:AttemptSave();
                end);

                local isSelected = Info.Multi and Dropdown.Value[val] or (Dropdown.Value == val);
                if isSelected then
                    Btn.BackgroundTransparency = 0.55;
                    Btn.TextColor3 = Library.AccentColor;
                end
            end
            RecalculateListPosition();
        end

        function Dropdown:Open()
            Dropdown:BuildDropdownList();
            RecalculateListPosition();
            ListOuter.GroupTransparency = 1;
            ListOuter.Visible = true;
            Tween(ListOuter, TI_SOFT, { GroupTransparency = 0 });
            Tween(Arrow, TI_SMOOTH, { Rotation = 180 });
            Tween(DropStroke, TI_SMOOTH, { Color = Library.AccentColor, Transparency = 0 });
            Library.OpenedFrames[ListOuter] = true;
        end

        function Dropdown:Close()
            ListOuter.Visible = false;
            Tween(Arrow, TI_SMOOTH, { Rotation = 0 });
            Tween(DropStroke, TI_SMOOTH, { Color = Library.OutlineColor, Transparency = 0.4 });
            Library.OpenedFrames[ListOuter] = nil;
        end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then Dropdown:Close(); else Dropdown:Open(); end
            end
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and ListOuter.Visible then
                if not Library:IsMouseOverFrame(ListOuter) and not Library:IsMouseOverFrame(DropdownOuter) then Dropdown:Close(); end
            end
        end));

        function Dropdown:SetValue(Val) Dropdown.Value = Val; Dropdown:Display(); Library:SafeCallback(Dropdown.Callback, Dropdown.Value); Library:SafeCallback(Dropdown.Changed, Dropdown.Value); end
        function Dropdown:SetValues(NewValues) Dropdown.Values = NewValues; Dropdown:BuildDropdownList(); Dropdown:Display(); end
        function Dropdown:OnChanged(Func) Dropdown.Changed = Func; Func(Dropdown.Value); end

        Dropdown:Display();
        Groupbox:AddBlank(4);
        Groupbox:Resize();
        Options[Idx] = Dropdown;
        return Dropdown;
    end

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {} };
        local Groupbox = self;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            ZIndex = 1;
            Parent = Groupbox.Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            ZIndex = 1;
            Parent = Holder;
        });

        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = Frame });

        function Depbox:Resize()
            local Size = 0;
            for _, Element in next, Frame:GetChildren() do
                if not Element:IsA('UIListLayout') and Element.Visible then Size = Size + Element.Size.Y.Offset; end
            end
            Holder.Size = UDim2.new(1, 0, 0, Size);
            Groupbox:Resize();
        end

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Expected = Dependency[2];
                if (not Elem) or Elem.Value ~= Expected then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end
            end
            Holder.Visible = true;
            Depbox:Resize();
        end

        function Depbox:SetupDependencies(Dependencies)
            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end

        Depbox.Container = Frame;
        setmetatable(Depbox, BaseGroupbox);
        table.insert(Library.DependencyBoxes, Depbox);
        return Depbox;
    end

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...) return Funcs[Key](...); end
end

-- < Notifications & HUD >
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(1, -310, 1, -210);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 5000;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 6);
        FillDirection = Enum.FillDirection.Vertical;
        VerticalAlignment = Enum.VerticalAlignment.Bottom;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BackgroundTransparency = 0.08;
        Position = UDim2.new(0, 20, 0, 20);
        Size = UDim2.new(0, 180, 0, 28);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = WatermarkOuter });
    Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.25, Thickness = 1, Parent = WatermarkOuter });

    local WatermarkAccent = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 6, 0.5, -2);
        Size = UDim2.new(0, 3, 0, 4);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = WatermarkAccent });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 15, 0, 0);
        Size = UDim2.new(1, -21, 1, 0);
        TextSize = 13;
        Text = 'miku';
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 201;
        Parent = WatermarkOuter;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);

    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.BackgroundColor;
        BackgroundTransparency = 0.08;
        Position = UDim2.new(0, 20, 0.5, 0);
        Size = UDim2.new(0, 190, 0, 30);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = KeybindOuter });
    Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.25, Thickness = 1, Parent = KeybindOuter });

    Library:CreateLabel({
        Size = UDim2.new(1, -16, 0, 30);
        Position = UDim2.fromOffset(8, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = 'Keybinds',
        TextColor3 = Library.AccentColor;
        TextSize = 12,
        ZIndex = 104,
        Parent = KeybindOuter;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        ClipsDescendants = true;
        Size = UDim2.new(1, -16, 1, -30);
        Position = UDim2.new(0, 8, 0, 30);
        ZIndex = 101;
        Parent = KeybindOuter;
    });

    Library:Create('UIListLayout', { Padding = UDim.new(0, 3); FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = KeybindContainer });
    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;

    local function ResizeKeybindFrame()
        local Height = 0;
        for _, child in next, KeybindContainer:GetChildren() do
            if not child:IsA('UIListLayout') then Height = Height + child.Size.Y.Offset + 3; end
        end
        Tween(KeybindOuter, TI_SMOOTH, { Size = UDim2.new(0, 190, 0, math.max(30, 34 + Height)) });
    end
    Library.ResizeKeybindFrame = ResizeKeybindFrame;

    Library:MakeDraggable(KeybindOuter);
end

function Library:SetWatermarkVisibility(Bool) Library.Watermark.Visible = Bool; end
function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 13);
    Library.Watermark.Size = UDim2.new(0, X + 27, 0, 28);
    Library.WatermarkText.Text = Text;
    Library:SetWatermarkVisibility(true);
end

function Library:ConfigureNotifications(cfg)
    cfg = cfg or {};
    if cfg.PositionX then
        Library.NotificationArea.Position = UDim2.new(cfg.PositionX / 100, -150, Library.NotificationArea.Position.Y.Scale, Library.NotificationArea.Position.Y.Offset);
    end
end

function Library:Notify(Text, Time)
    Time = Time or 4;
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 13);
    local NotifyCard = Library:Create('CanvasGroup', {
        GroupTransparency = 1;
        BackgroundColor3 = Library.BackgroundColor,
        Size = UDim2.new(1, 0, 0, math.max(YSize + 16, 34)),
        ZIndex = 5001,
        Parent = Library.NotificationArea,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = NotifyCard });
    local Stroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = NotifyCard });

    local LeftBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 0, 0),
        AnchorPoint = Vector2.new(0, 0.5);
        Position = UDim2.new(0, 0, 0.5, 0);
        ZIndex = 5002,
        Parent = NotifyCard,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 2), Parent = LeftBar });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 11, 0, 0),
        Size = UDim2.new(1, -21, 1, 0),
        Text = Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5002,
        Parent = NotifyCard,
    });

    Tween(NotifyCard, TI_SOFT, { GroupTransparency = 0 });
    Tween(LeftBar, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 3, 1, 0) });

    task.delay(Time, function()
        Tween(NotifyCard, TI_SMOOTH, { GroupTransparency = 1 });
        task.wait(0.25);
        NotifyCard:Destroy();
    end);
end

function Library:Loader(Info)
    Info = Info or {};
    local Name = Info.Name or 'MIKU';
    local Duration = Info.Duration or 2;

    task.spawn(function()
        local LoaderGui = Library:Create('CanvasGroup', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(280, 116),
            GroupTransparency = 1;
            BackgroundColor3 = Library.BackgroundColor,
            ZIndex = 9000,
            Parent = ScreenGui,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Window), Parent = LoaderGui });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = LoaderGui });

        local AccentDot = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0);
            Position = UDim2.new(0.5, 0, 0, 16);
            Size = UDim2.fromOffset(6, 6);
            BackgroundColor3 = Library.AccentColor;
            ZIndex = 9001;
            Parent = LoaderGui;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = AccentDot });

        Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 30),
            Size = UDim2.new(1, 0, 0, 26),
            Text = Name,
            TextColor3 = Library.AccentColor,
            TextSize = 20,
            ZIndex = 9001,
            Parent = LoaderGui,
        });

        local ProgressTrack = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            Position = UDim2.new(0, 28, 0, 72),
            Size = UDim2.new(1, -56, 0, 5),
            ZIndex = 9001,
            Parent = LoaderGui,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = ProgressTrack });

        local ProgressBar = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 0, 1, 0),
            ZIndex = 9002,
            Parent = ProgressTrack,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = ProgressBar });

        Tween(LoaderGui, TI_SMOOTH, { GroupTransparency = 0 });
        Tween(AccentDot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = UDim2.fromOffset(10, 10) });
        Tween(ProgressBar, TweenInfo.new(Duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) });
        task.wait(Duration + 0.25);
        Tween(LoaderGui, TI_SMOOTH, { GroupTransparency = 1 });
        task.wait(0.3);
        LoaderGui:Destroy();
    end);
end

-- Tab icons: keyword matched, emoji based (always render, no asset loading)
local TabIconTable = {
    { 'aim', '🎯' }, { 'combat', '🎯' }, { 'rage', '🎯' }, { 'legit', '🎯' },
    { 'silent', '🎯' }, { 'main', '🎯' }, { 'trigger', '🎯' }, { 'hit', '🎯' },
    { 'char', '👤' }, { 'player', '👤' }, { 'move', '🏃' }, { 'self', '👤' },
    { 'vis', '👁️' }, { 'esp', '👁️' }, { 'render', '👁️' }, { 'cham', '👁️' },
    { 'world', '🌐' }, { 'env', '🌐' }, { 'light', '🌐' }, { 'weather', '🌦️' },
    { 'skin', '🎨' }, { 'cosmetic', '🎨' }, { 'invent', '🎨' },
    { 'setting', '⚙️' }, { 'config', '⚙️' }, { 'menu', '⚙️' }, { 'ui', '⚙️' },
    { 'misc', '🧩' }, { 'util', '🧩' }, { 'extra', '🧩' }, { 'other', '🧩' },
};

local function GetTabIcon(Name)
    local n = string.lower(tostring(Name));
    for _, Entry in ipairs(TabIconTable) do
        if n:find(Entry[1], 1, true) then
            return Entry[2];
        end
    end
    return '◆';
end

-- Top Dock / Modular Multi-Window Architecture
function Library:CreateWindow(...)
    local Arguments = { ... };
    local Config = { AnchorPoint = Vector2.zero };

    if type(...) == 'table' then Config = ...;
    else Config.Title = Arguments[1]; Config.AutoShow = Arguments[2] or false; end

    Config.Title = Config.Title or 'MIKU';
    Config.TabPadding = Config.TabPadding or 6;
    Config.MenuFadeTime = Config.MenuFadeTime or 0.2;

    local Window = { Tabs = {}, ModularWindows = {} };
    Window.AutoShow = (Config.AutoShow ~= false);

    -- Top Navigation Dock Bar
    local TopDock = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 14),
        Size = UDim2.fromOffset(560, 50),
        BackgroundColor3 = Library.BackgroundColor,
        ZIndex = 10,
        Parent = ScreenGui,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Dock), Parent = TopDock });
    local DockStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.1, Thickness = 1, Parent = TopDock });
    local DockGradient = Library:Create('UIGradient', {
        Rotation = 90;
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255));
            ColorSequenceKeypoint.new(1, Color3.fromRGB(225, 228, 235));
        });
        Parent = TopDock;
    });
    Library:AddToRegistry(TopDock, { BackgroundColor3 = 'BackgroundColor' });
    Library:AddToRegistry(DockStroke, { Color = 'OutlineColor' });
    Library:MakeDraggable(TopDock);

    local TitleW = Library:GetTextBounds(Config.Title, Library.Font, 14);
    local HeaderW = math.max(96, 38 + TitleW + 12);

    local DockHeader = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(0, HeaderW - 14, 1, 0),
        ZIndex = 11,
        Parent = TopDock,
    });

    local PulsingDot = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Library.AccentColor,
        ZIndex = 12,
        Parent = DockHeader,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = PulsingDot });
    Library:AddToRegistry(PulsingDot, { BackgroundColor3 = 'AccentColor' });

    -- Pulse animation on the status dot
    task.spawn(function()
        local grow = true;
        while PulsingDot.Parent do
            grow = not grow;
            Tween(PulsingDot, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = grow and UDim2.fromOffset(6, 6) or UDim2.fromOffset(8, 8);
                BackgroundTransparency = grow and 0.35 or 0;
            });
            task.wait(1.1);
        end
    end);

    local DockTitle = Library:CreateLabel({
        Position = UDim2.new(0, 15, 0, 0),
        Size = UDim2.new(1, -15, 1, 0),
        Text = Config.Title,
        TextColor3 = Library.AccentColor,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
        Parent = DockHeader,
    });
    Library:AddToRegistry(DockTitle, { TextColor3 = 'AccentColor' });

    -- Divider between title and tabs
    Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        BackgroundTransparency = 0.45;
        BorderSizePixel = 0;
        Position = UDim2.new(0, HeaderW + 2, 0, 10);
        Size = UDim2.new(0, 1, 1, -20);
        ZIndex = 12;
        Parent = TopDock;
    });

    -- Horizontal Tab Navigation Pills (icon-only, expand on hover)
    local TabScroll = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, HeaderW + 12, 0, 7),
        Size = UDim2.new(1, -(HeaderW + 82), 1, -14),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X;
        ScrollingDirection = Enum.ScrollingDirection.X;
        ScrollBarThickness = 0,
        ZIndex = 11,
        Parent = TopDock,
    });

    local TabLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center;
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabScroll,
    });

    TabLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        TabScroll.CanvasSize = UDim2.fromOffset(TabLayout.AbsoluteContentSize.X + 8, 0);
    end);

    -- Quick Actions on the Right
    local QuickActions = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -66, 0, 7),
        Size = UDim2.new(0, 58, 1, -14),
        ZIndex = 11,
        Parent = TopDock,
    });

    local CloseAllBtn = Library:Create('TextButton', {
        AutoButtonColor = false;
        BackgroundColor3 = Library.MainColor,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Library.Font,
        Text = 'hide all',
        TextColor3 = Library.DimColor,
        TextSize = 11,
        ZIndex = 12,
        Parent = QuickActions,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = CloseAllBtn });
    local CloseAllStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.15, Thickness = 1, Parent = CloseAllBtn });

    CloseAllBtn.MouseEnter:Connect(function()
        Tween(CloseAllBtn, TI_FAST, { TextColor3 = Library.FontColor, BackgroundColor3 = Library.BackgroundColor });
        Tween(CloseAllStroke, TI_FAST, { Transparency = 0 });
    end);
    CloseAllBtn.MouseLeave:Connect(function()
        Tween(CloseAllBtn, TI_FAST, { TextColor3 = Library.DimColor, BackgroundColor3 = Library.MainColor });
        Tween(CloseAllStroke, TI_FAST, { Transparency = 0.4 });
    end);

    CloseAllBtn.MouseButton1Click:Connect(function()
        local anyOpen = false;
        for _, tab in next, Window.Tabs do
            if tab.IsOpen then anyOpen = true; break; end
        end
        for _, tab in next, Window.Tabs do
            if anyOpen then tab:CloseWindow(); else tab:OpenWindow(); end
        end
        CloseAllBtn.Text = anyOpen and 'show all' or 'hide all';
    end);

    local windowIndex = 0;

    function Window:AddTab(Name)
        windowIndex = windowIndex + 1;
        Name = Name or ('Tab ' .. windowIndex);
        local Tab = { Groupboxes = {}; Tabboxes = {}; IsOpen = (Window.AutoShow and windowIndex == 1); Active = (Window.AutoShow and windowIndex == 1); };

        local Icon = GetTabIcon(Name);
        local IconPadLeft, IconW, Gap = 11, 17, 6;
        local CollapsedW = IconPadLeft * 2 + IconW;
        local NameW = Library:GetTextBounds(Name, Library.Font, 12);
        local ExpandedW = IconPadLeft + IconW + Gap + NameW + 13;

        local TabPill = Library:Create('TextButton', {
            AutoButtonColor = false;
            BackgroundColor3 = Library.MainColor,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, CollapsedW, 1, 0),
            Text = '',
            ZIndex = 13,
            Parent = TabScroll,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = TabPill });
        local PillStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 1, Thickness = 1, Parent = TabPill });
        local PillScale = Library:Create('UIScale', { Scale = 1, Parent = TabPill });

        -- active-tab underline indicator
        local Underline = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 1);
            Position = UDim2.new(0.5, 0, 1, -3);
            Size = UDim2.new(0, 0, 0, 2);
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            ZIndex = 15;
            Parent = TabPill;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Underline });
        Library:AddToRegistry(Underline, { BackgroundColor3 = 'AccentColor' });

        local PillIcon = Library:CreateLabel({
            AnchorPoint = Vector2.new(0, 0.5);
            Position = UDim2.new(0, IconPadLeft, 0.5, 0);
            Size = UDim2.new(0, IconW, 1, 0);
            Text = Icon;
            RichText = false;
            TextSize = 16;
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex = 14;
            Parent = TabPill;
        });
        PillIcon.TextColor3 = Library.DimColor;

        local PillName = Library:CreateLabel({
            Position = UDim2.new(0, IconPadLeft + IconW + Gap - 6, 0, 0),
            Size = UDim2.new(0, NameW + 8, 1, 0),
            Text = Name,
            TextSize = 12,
            TextTransparency = 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 14;
            Parent = TabPill,
        });

        local hoveringPill = false;

        local function RefreshPill(Hovered)
            if Tab.IsOpen then
                Tween(PillStroke, TI_SMOOTH, { Color = Library.AccentColor, Transparency = Hovered and 0.1 or 0.35 });
                Tween(PillIcon, TI_SMOOTH, { TextColor3 = Library.AccentColor });
                Tween(PillName, TI_SMOOTH, { TextColor3 = Library.FontColor });
                Tween(TabPill, TI_SMOOTH, { BackgroundColor3 = Library.BackgroundColor, BackgroundTransparency = 0 });
                Tween(Underline, TI_SOFT, { Size = UDim2.new(0.55, 0, 0, 2), BackgroundTransparency = 0.05 });
            elseif Hovered then
                Tween(PillStroke, TI_FAST, { Color = Library.OutlineColor, Transparency = 0.25 });
                Tween(PillIcon, TI_FAST, { TextColor3 = Library.FontColor });
                Tween(PillName, TI_FAST, { TextColor3 = Library.FontColor });
                Tween(TabPill, TI_FAST, { BackgroundColor3 = Library.MainColor, BackgroundTransparency = 0 });
                Tween(Underline, TI_FAST, { Size = UDim2.new(0.18, 0, 0, 2), BackgroundTransparency = 0.45 });
            else
                Tween(PillStroke, TI_SMOOTH, { Color = Library.OutlineColor, Transparency = 1 });
                Tween(PillIcon, TI_SMOOTH, { TextColor3 = Library.DimColor });
                Tween(PillName, TI_SMOOTH, { TextColor3 = Library.FontColor });
                Tween(TabPill, TI_SMOOTH, { BackgroundTransparency = 1 });
                Tween(Underline, TI_SMOOTH, { Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1 });
            end
        end

        TabPill.MouseEnter:Connect(function()
            hoveringPill = true;
            Tween(PillScale, TI_POP, { Scale = 1.06 });
            Tween(TabPill, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, ExpandedW, 1, 0) });
            PillName.Visible = true;
            RefreshPill(true);
            PillName.Position = UDim2.new(0, IconPadLeft + IconW + Gap - 6, 0, 0);
            Tween(PillName, TI_SMOOTH, {
                TextTransparency = 0;
                Position = UDim2.new(0, IconPadLeft + IconW + Gap, 0, 0);
            });
        end);

        TabPill.MouseLeave:Connect(function()
            hoveringPill = false;
            Tween(PillScale, TI_FAST, { Scale = 1 });
            Tween(TabPill, TI_SOFT, { Size = UDim2.new(0, CollapsedW, 1, 0) });
            RefreshPill(false);
            Tween(PillName, TI_FAST, { TextTransparency = 1 });
            task.delay(0.14, function()
                if not hoveringPill then PillName.Visible = false; end
            end);
        end);

        -- Web: live line connecting the tab pill to its floating window
        local WebHolder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.fromOffset(0, 0);
            ZIndex = 1;
            Parent = ScreenGui;
        });
        local WebStem = Library:Create('Frame', {
            BorderSizePixel = 0;
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 0.45;
            AnchorPoint = Vector2.new(0.5, 0);
            Size = UDim2.new(0, 1, 0, 14);
            Position = UDim2.fromOffset(0, 0);
            Visible = false;
            ZIndex = 1;
            Parent = WebHolder;
        });
        local WebStrand = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BorderSizePixel = 0;
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 0.55;
            Size = UDim2.new(0, 0, 0, 1);
            Visible = false;
            ZIndex = 1;
            Parent = WebHolder;
        });
        local WebDotPill = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BorderSizePixel = 0;
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 0.15;
            Size = UDim2.new(0, 4, 0, 4);
            Visible = false;
            ZIndex = 1;
            Parent = WebHolder;
        });
        local WebDotWin = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BorderSizePixel = 0;
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 0.3;
            Size = UDim2.new(0, 3, 0, 3);
            Visible = false;
            ZIndex = 1;
            Parent = WebHolder;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = WebDotPill });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = WebDotWin });
        Library:AddToRegistry(WebStem, { BackgroundColor3 = 'AccentColor' }, true);
        Library:AddToRegistry(WebStrand, { BackgroundColor3 = 'AccentColor' }, true);
        Library:AddToRegistry(WebDotPill, { BackgroundColor3 = 'AccentColor' }, true);
        Library:AddToRegistry(WebDotWin, { BackgroundColor3 = 'AccentColor' }, true);

        local function UpdateWeb()
            if not Tab.IsOpen or not ModWindow.Visible then return end
            local pillPos, pillSize = TabPill.AbsolutePosition, TabPill.AbsoluteSize;
            local winPos, winSize = ModWindow.AbsolutePosition, ModWindow.AbsoluteSize;
            local sx = pillPos.X + pillSize.X / 2;
            local sy = pillPos.Y + pillSize.Y - 2;
            local ex = winPos.X + winSize.X / 2;
            local ey = winPos.Y + 1;

            WebDotPill.Position = UDim2.fromOffset(sx, sy);
            WebDotWin.Position = UDim2.fromOffset(ex, ey);

            local gap = ey - sy;
            local stemLen = math.clamp(gap * 0.22, 5, 18);
            WebStem.Position = UDim2.fromOffset(sx, sy);
            WebStem.Size = UDim2.new(0, 1, 0, stemLen);
            WebStem.Visible = gap > 10;

            local ox, oy = sx, sy + stemLen;
            local dx, dy = ex - ox, ey - oy;
            local len = math.sqrt(dx * dx + dy * dy);
            if len < 2 then
                WebStrand.Visible = false;
            else
                WebStrand.Visible = true;
                WebStrand.Position = UDim2.fromOffset(ox + dx / 2, oy + dy / 2);
                WebStrand.Size = UDim2.new(0, len, 0, 1);
                WebStrand.Rotation = math.deg(math.atan2(dy, dx));
            end
        end

        local webConn = nil;
        local function StartWeb()
            UpdateWeb();
            WebStem.Visible = true;
            WebStrand.Visible = true;
            WebDotPill.Visible = true;
            WebDotWin.Visible = true;
            if not webConn then
                webConn = RenderStepped:Connect(UpdateWeb);
            end
        end
        local function StopWeb()
            if webConn then webConn:Disconnect(); webConn = nil; end
            WebStem.Visible = false;
            WebStrand.Visible = false;
            WebDotPill.Visible = false;
            WebDotWin.Visible = false;
        end

        -- Floating Modular Window for this Tab (single active window, shared spawn point)
        local ModWindow = Library:Create('Frame', {
            Position = UDim2.fromOffset(70, 90),
            Size = UDim2.fromOffset(460, 520),
            BackgroundColor3 = Library.BackgroundColor,
            Visible = Tab.IsOpen,
            ZIndex = 1,
            Parent = ScreenGui,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Window), Parent = ModWindow });
        local ModWindowStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.1, Thickness = 1.5, Parent = ModWindow });
        Library:AddToRegistry(ModWindowStroke, { Color = 'OutlineColor' });

        local WinScale = Library:Create('UIScale', { Scale = 1, Parent = ModWindow });

        -- Window Header (Draggable)
        local WinHeader = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            Size = UDim2.new(1, 0, 0, 34),
            ZIndex = 2,
            Parent = ModWindow,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Window), Parent = WinHeader });
        Library:MakeDraggable(ModWindow, WinHeader);

        -- Bottom flat cover for top header corner
        local HeaderCover = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 1, -8),
            Size = UDim2.new(1, 0, 0, 8),
            ZIndex = 2,
            Parent = WinHeader,
        });

        local HeaderAccent = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 12, 0.5, -5);
            Size = UDim2.new(0, 3, 0, 10);
            ZIndex = 3;
            Parent = WinHeader;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = HeaderAccent });
        Library:AddToRegistry(HeaderAccent, { BackgroundColor3 = 'AccentColor' });

        local WinTitle = Library:CreateLabel({
            Position = UDim2.new(0, 23, 0, 0),
            Size = UDim2.new(1, -78, 1, 0),
            Text = Name:lower(),
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
            Parent = WinHeader,
        });

        -- Close ('X') button on each window
        local CloseBtn = Library:Create('TextButton', {
            AutoButtonColor = false;
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -28, 0.5, -10),
            Size = UDim2.fromOffset(20, 20),
            Font = Library.Font,
            Text = "✕",
            TextColor3 = Color3.fromRGB(160, 160, 170),
            TextSize = 12,
            ZIndex = 4,
            Parent = WinHeader,
        });
        CloseBtn.MouseEnter:Connect(function() Tween(CloseBtn, TI_FAST, { TextColor3 = Library.RiskColor }); end);
        CloseBtn.MouseLeave:Connect(function() Tween(CloseBtn, TI_FAST, { TextColor3 = Color3.fromRGB(160, 160, 170) }); end);
        CloseBtn.MouseButton1Click:Connect(function() Tab:CloseWindow(); end);

        -- Window Content (Two Columns: Left & Right)
        local ContentBody = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 42),
            Size = UDim2.new(1, -16, 1, -52),
            ZIndex = 2,
            Parent = ModWindow,
        });

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0.5, -6, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.AccentColor,
            ZIndex = 2,
            Parent = ContentBody,
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0.5, 6, 0, 0),
            Size = UDim2.new(0.5, -6, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.AccentColor,
            ZIndex = 2,
            Parent = ContentBody,
        });

        for _, Side in next, { LeftSide, RightSide } do
            local layout = Library:Create('UIListLayout', {
                Padding = UDim.new(0, 8),
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Parent = Side,
            });
            layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12);
            end);
        end

        function Tab:OpenWindow()
            for _, Other in next, Window.Tabs do
                if Other ~= Tab and Other.IsOpen and Other.CloseWindow then
                    Other:CloseWindow();
                end
            end
            Tab.IsOpen = true;
            Tab.Active = true;
            ModWindow.Visible = true;
            WinScale.Scale = 0.95;
            Tween(WinScale, TI_POP, { Scale = 1 });
            Tween(ModWindowStroke, TI_SMOOTH, { Color = Library.AccentColor, Transparency = 0 });
            task.delay(0.5, function()
                if Tab.Active then Tween(ModWindowStroke, TI_SMOOTH, { Color = Library.OutlineColor, Transparency = 0.25 }); end
            end);
            RefreshPill(hoveringPill);
            StartWeb();
        end

        function Tab:CloseWindow()
            Tab.IsOpen = false;
            Tab.Active = false;
            StopWeb();
            Tween(WinScale, TI_FAST, { Scale = 0.97 });
            task.delay(0.1, function()
                if not Tab.IsOpen then ModWindow.Visible = false; WinScale.Scale = 1; end
            end);
            RefreshPill(hoveringPill);
        end

        function Tab:ToggleWindow()
            if Tab.IsOpen then Tab:CloseWindow(); else Tab:OpenWindow(); end
        end

        TabPill.MouseButton1Click:Connect(function()
            -- press dip + spring back
            Tween(PillScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.92 });
            Tween(Underline, TI_FAST, { Size = UDim2.new(0.85, 0, 0, 2) });
            task.delay(0.06, function()
                if not TabPill.Parent then return end
                Tween(PillScale, TI_POP, { Scale = hoveringPill and 1.06 or 1 });
            end);
            Tab:ToggleWindow();
        end);

        function Tab:ShowTab() Tab:OpenWindow(); end
        function Tab:HideTab() Tab:CloseWindow(); end
        if Tab.IsOpen then task.defer(StartWeb); end

        function Tab:AddGroupbox(Info)
            if type(Info) == 'string' then
                Info = { Name = Info, Side = 1 };
            elseif type(Info) ~= 'table' then
                Info = { Name = '', Side = 1 };
            end
            Info.Side = Info.Side or 1;
            Info.Name = Info.Name or '';

            local Groupbox = {};
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                Size = UDim2.new(1, 0, 0, 100),
                ZIndex = 1,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Groupbox), Parent = BoxOuter });
            local GroupStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0, Thickness = 1, Parent = BoxOuter });
            Library:AddToRegistry(GroupStroke, { Color = 'OutlineColor' });
            Library:AddToRegistry(AccentBar, { BackgroundColor3 = 'AccentColor' });

            local Header = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 6),
                Size = UDim2.new(1, -16, 0, 18),
                ZIndex = 2,
                Parent = BoxOuter,
            });

            local AccentBar = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 0, 0.5, -5),
                Size = UDim2.new(0, 3, 0, 10),
                ZIndex = 3,
                Parent = Header,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = AccentBar });

            Library:CreateLabel({
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -8, 1, 0),
                TextSize = 12,
                Text = Info.Name,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 3,
                Parent = Header,
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 26),
                Size = UDim2.new(1, -12, 1, -30),
                ZIndex = 2,
                Parent = BoxOuter,
            });

            Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = Container });

            function Groupbox:Resize()
                local Size = 0;
                for _, Element in next, Container:GetChildren() do
                    if not Element:IsA('UIListLayout') and Element.Visible then Size = Size + Element.Size.Y.Offset; end
                end
                BoxOuter.Size = UDim2.new(1, 0, 0, 32 + Size);
            end

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);
            Groupbox:AddBlank(2);
            Groupbox:Resize();
            local boxKey = (Info.Name and Info.Name ~= '') and Info.Name or ('Groupbox_' .. tostring(#LeftSide:GetChildren() + #RightSide:GetChildren() + 1));
            Tab.Groupboxes[boxKey] = Groupbox;
            return Groupbox;
        end

        function Tab:AddLeftGroupbox(Name) return Tab:AddGroupbox({ Side = 1, Name = type(Name) == 'string' and Name or '' }); end
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({ Side = 2, Name = type(Name) == 'string' and Name or '' }); end

        function Tab:AddTabbox(Info)
            if type(Info) == 'string' then
                Info = { Name = Info, Side = 1 };
            elseif type(Info) ~= 'table' then
                Info = { Name = '', Side = 1 };
            end
            Info.Side = Info.Side or 1;
            Info.Name = Info.Name or '';

            local Tabbox = { Tabs = {} };
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                Size = UDim2.new(1, 0, 0, 100),
                ZIndex = 1,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Groupbox), Parent = BoxOuter });
            local TabboxStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0, Thickness = 1, Parent = BoxOuter });
            Library:AddToRegistry(TabboxStroke, { Color = 'OutlineColor' });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 6),
                Size = UDim2.new(1, -12, 0, 20),
                ZIndex = 2,
                Parent = BoxOuter,
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
                Parent = TabboxButtons,
            });

            function Tabbox:AddTab(SubTabName)
                SubTabName = SubTabName or 'Tab';
                local SubTab = {};
                local Button = Library:Create('TextButton', {
                    AutoButtonColor = false;
                    BackgroundColor3 = Library.BackgroundColor,
                    BackgroundTransparency = 1;
                    Size = UDim2.new(0.5, -2, 1, 0),
                    Font = Library.Font,
                    Text = SubTabName,
                    TextColor3 = Library.FontColor,
                    TextSize = 11,
                    ZIndex = 3,
                    Parent = TabboxButtons,
                });
                Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Small), Parent = Button });
                local BtnStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 1, Thickness = 1, Parent = Button });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 6, 0, 30),
                    Size = UDim2.new(1, -12, 1, -34),
                    Visible = false,
                    ZIndex = 2,
                    Parent = BoxOuter,
                });

                Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = Container });

                function SubTab:Show()
                    for _, t in next, Tabbox.Tabs do t:Hide(); end
                    Container.Visible = true;
                    Tween(Button, TI_SMOOTH, { BackgroundColor3 = Library.AccentColor, BackgroundTransparency = 0.85, TextColor3 = Library.AccentColor });
                    Tween(BtnStroke, TI_SMOOTH, { Color = Library.AccentColor, Transparency = 0 });
                    SubTab:Resize();
                end

                function SubTab:Hide()
                    Container.Visible = false;
                    Tween(Button, TI_SMOOTH, { BackgroundColor3 = Library.BackgroundColor, BackgroundTransparency = 1, TextColor3 = Library.FontColor });
                    Tween(BtnStroke, TI_SMOOTH, { Color = Library.OutlineColor, Transparency = 1 });
                end

                function SubTab:Resize()
                    local TabCount = 0;
                    for _ in next, Tabbox.Tabs do TabCount = TabCount + 1; end
                    for _, child in next, TabboxButtons:GetChildren() do
                        if child:IsA('TextButton') then child.Size = UDim2.new(1 / math.max(TabCount, 1), -4, 1, 0); end
                    end
                    if not Container.Visible then return end
                    local Size = 0;
                    for _, Element in next, Container:GetChildren() do
                        if not Element:IsA('UIListLayout') and Element.Visible then Size = Size + Element.Size.Y.Offset; end
                    end
                    BoxOuter.Size = UDim2.new(1, 0, 0, 36 + Size);
                end

                Button.MouseEnter:Connect(function()
                    if not Container.Visible then
                        Tween(Button, TI_FAST, { BackgroundTransparency = 0.65 });
                        Tween(BtnStroke, TI_FAST, { Color = Library.OutlineColor, Transparency = 0 });
                    end
                end);
                Button.MouseLeave:Connect(function()
                    if not Container.Visible then
                        Tween(Button, TI_FAST, { BackgroundTransparency = 1 });
                        Tween(BtnStroke, TI_FAST, { Transparency = 1 });
                    end
                end);

                Button.MouseButton1Click:Connect(function() SubTab:Show(); end);
                SubTab.Container = Container;
                Tabbox.Tabs[SubTabName] = SubTab;
                setmetatable(SubTab, BaseGroupbox);
                SubTab:AddBlank(2);
                SubTab:Resize();

                if #TabboxButtons:GetChildren() == 2 then SubTab:Show(); end
                return SubTab;
            end

            local boxKey = (Info.Name and Info.Name ~= '') and Info.Name or ('Tabbox_' .. tostring(#LeftSide:GetChildren() + #RightSide:GetChildren() + 1));
            Tab.Tabboxes[boxKey] = Tabbox;
            return Tabbox;
        end

        function Tab:AddLeftTabbox(Name) return Tab:AddTabbox({ Name = type(Name) == 'string' and Name or '', Side = 1 }); end
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({ Name = type(Name) == 'string' and Name or '', Side = 2 }); end

        -- Apply initial pill state
        if Tab.Active then
            PillStroke.Transparency = 0.25;
            PillStroke.Color = Library.AccentColor;
            PillIcon.TextColor3 = Library.AccentColor;
            TabPill.BackgroundTransparency = 0.92;
        end

        Window.Tabs[Name] = Tab;
        Window.ModularWindows[Name] = ModWindow;
        return Tab;
    end

    function Library:Toggle()
        Library.Toggled = not Library.Toggled;
        Library:SetBlur(Library.Toggled);

        TopDock.Visible = Library.Toggled;
        for name, modWin in next, Window.ModularWindows do
            local tab = Window.Tabs[name];
            if tab and tab.IsOpen then
                modWin.Visible = Library.Toggled;
            end
        end
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle);
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and not Processed) then
            task.spawn(Library.Toggle);
        end
    end));

    if Window.AutoShow then
        Library:SetBlur(true);
    else
        -- silent load: stay fully hidden until the user toggles the ui
        Library.Toggled = false;
        TopDock.Visible = false;
        if BlurEffect then BlurEffect.Enabled = false; end
    end
    Window.Holder = TopDock;
    Library.Window = Window;
    return Window;
end

local function OnPlayerChange()
    local PlayerList = GetPlayersString();
    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end
    end
end

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library;
return Library;
