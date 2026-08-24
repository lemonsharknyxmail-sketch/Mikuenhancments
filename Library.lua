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
while not LocalPlayer do
    task.wait();
    LocalPlayer = Players.LocalPlayer;
end
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
pcall(function() ProtectGui(ScreenGui); end);
ScreenGui.Name = "MikuModularGui";
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
ScreenGui.DisplayOrder = 2147483646;
ScreenGui.ResetOnSpawn = false;

-- executor-safe parenting: gethui() -> CoreGui -> PlayerGui
do
    local Parented = false;
    if gethui then
        local okHui, Hui = pcall(gethui);
        if okHui and Hui then
            local okSet = pcall(function() ScreenGui.Parent = Hui; end);
            Parented = okSet and ScreenGui.Parent ~= nil;
        end
    end
    if not Parented then
        local okCore = pcall(function() ScreenGui.Parent = CoreGui; end);
        Parented = okCore and ScreenGui.Parent ~= nil;
    end
    if not Parented then
        pcall(function()
            local pg = LocalPlayer:FindFirstChildOfClass('PlayerGui') or LocalPlayer:WaitForChild('PlayerGui', 5);
            ScreenGui.Parent = pg or game:GetService('Players').LocalPlayer.PlayerGui;
        end);
    end
end

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

-- // Luxury Cyber Design tokens
local RADIUS = {
    Dock = 14;
    Window = 12;
    Groupbox = 8;
    Control = 6;
    Small = 4;
};

local TI_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
local TI_SMOOTH = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
local TI_SOFT = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out);
local TI_POP = TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out);

local Library = {
    Registry = {};
    RegistryMap = {};
    HudRegistry = {};

    FontColor = Color3.fromRGB(244, 246, 252);
    MainColor = Color3.fromRGB(22, 25, 34);
    BackgroundColor = Color3.fromRGB(14, 16, 22);
    AccentColor = Color3.fromRGB(140, 82, 255);
    OutlineColor = Color3.fromRGB(44, 50, 68);
    RiskColor = Color3.fromRGB(255, 75, 96);
    DimColor = Color3.fromRGB(142, 150, 172);

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

-- Bulletproof Draggable implementation that attaches to handle and all its child labels/frames
function Library:MakeDraggable(Instance, DragHandle)
    Instance.Active = true;
    local handle = DragHandle or Instance;
    handle.Active = true;
    local dragging = false;
    local dragStart = Vector3.zero;
    local startPos = UDim2.new();

    local function StartDragging(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            if Library:MouseIsOverOpenedFrame() then return end
            if DragHandle then
                for _, child in ipairs(DragHandle:GetDescendants()) do
                    if (child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("TextBox")) and child.Visible then
                        if Library:IsMouseOverFrame(child) then
                            return;
                        end
                    end
                end
            end
            dragging = true;
            Library.IsDragging = true;
            dragStart = input.Position;
            startPos = Instance.Position;
        end
    end

    local function AttachToChild(child)
        if child:IsA("GuiObject") and not child:IsA("TextButton") and not child:IsA("ImageButton") and not child:IsA("TextBox") then
            pcall(function()
                child.InputBegan:Connect(StartDragging);
            end);
        end
    end

    pcall(function()
        handle.InputBegan:Connect(StartDragging);
    end);
    for _, child in ipairs(handle:GetDescendants()) do
        AttachToChild(child);
    end
    handle.DescendantAdded:Connect(AttachToChild);

    Library:GiveSignal(InputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false;
                Library.IsDragging = false;
                if WebManager then WebManager:Update(true); end
            end
        end
    end));

    Library:GiveSignal(InputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart;
            Instance.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            );
            if WebManager then WebManager:Update(true); end
        end
    end));
end

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 12);
    local Tooltip = Library:Create('CanvasGroup', {
        GroupTransparency = 1;
        BackgroundColor3 = Library.BackgroundColor,
        Size = UDim2.fromOffset(X + 16, Y + 10),
        ZIndex = 6000,
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
        ZIndex = 6001,
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
    local TextStr = tostring(Text);
    local ok, X, Y = pcall(function()
        local Bounds = TextService:GetTextSize(TextStr, Size, Font or Library.Font, Resolution or Vector2.new(1920, 1080));
        return Bounds.X, Bounds.Y;
    end);
    if ok and X and X > 0 then return X, Y end
    return math.max(#TextStr * 7, 8), math.max(Size or 13, 12);
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
            Toggled = (Info.Mode == 'Always' or Info.Default == 'None');
            Mode = Info.Mode or 'Always';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;
            SyncToggleState = Info.SyncToggleState or false;
        };

        if ParentObj and ParentObj.Type == 'Toggle' then
            ParentObj.KeyPicker = KeyPicker;
        end

        local PickOuter = Library:Create('TextButton', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(0, 48, 0, 18);
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
            Text = '[' .. tostring(Info.Default) .. ']';
            TextColor3 = Library.FontColor;
            ZIndex = 21;
            Active = false;
            Parent = PickOuter;
        });

        local ModeSelectOuter = Library:Create('CanvasGroup', {
            GroupTransparency = 1;
            BackgroundColor3 = Library.BackgroundColor;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(0, 88, 0, 72);
            Visible = false;
            ZIndex = 3000;
            Parent = ScreenGui;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = ModeSelectOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = ModeSelectOuter });

        local function UpdateModePosition()
            local absPos = PickOuter.AbsolutePosition;
            ModeSelectOuter.Position = UDim2.fromOffset(absPos.X + PickOuter.AbsoluteSize.X + 4, absPos.Y);
        end

        PickOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(UpdateModePosition);

        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = ModeSelectOuter });

        local Modes = Info.Modes or { 'Always', 'Hold', 'Toggle' };
        local ModeButtons = {};

        for _, Mode in next, Modes do
            local ModeButton = {};
            local Btn = Library:Create('TextButton', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 24);
                Font = Library.Font;
                TextSize = 12;
                Text = Mode;
                TextColor3 = (KeyPicker.Mode == Mode) and Library.AccentColor or Library.FontColor;
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
                if Mode == 'Always' then
                    KeyPicker.Toggled = true;
                elseif Mode == 'Hold' then
                    KeyPicker.Toggled = false;
                end
                Btn.TextColor3 = Library.AccentColor;
                ModeSelectOuter.Visible = false;
                if KeyPicker.UpdateBindRow then KeyPicker:UpdateBindRow(); end
                Library:SafeCallback(KeyPicker.Callback, KeyPicker:GetState());
            end
            function ModeButton:Deselect() Btn.TextColor3 = Library.FontColor; end

            Btn.MouseButton1Click:Connect(function() ModeButton:Select(); Library:AttemptSave(); end);
            if Mode == KeyPicker.Mode then ModeButton:Select(); end
            ModeButtons[Mode] = ModeButton;
        end

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
                BindRow.Text = string.format('[%s] %s (%s)', tostring(KeyPicker.Value), tostring(Info.Text or Idx), tostring(KeyPicker.Mode));
                if KeyPicker:GetState() then
                    Tween(BindRow, TI_FAST, { TextColor3 = Library.AccentColor });
                else
                    Tween(BindRow, TI_FAST, { TextColor3 = Library.DimColor });
                end
            end
            KeyPicker:UpdateBindRow();
            if Library.ResizeKeybindFrame then Library.ResizeKeybindFrame(); end
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' or KeyPicker.Value == '' then return true; end
                local key = KeyPicker.Value;
                if key == 'MB1' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1);
                elseif key == 'MB2' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                elseif key == 'MB3' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3);
                else
                    local code = Enum.KeyCode[key];
                    if code then return InputService:IsKeyDown(code); end
                end
                return false;
            elseif KeyPicker.Mode == 'Toggle' then
                if KeyPicker.Value == 'None' or KeyPicker.Value == '' then return true; end
                return KeyPicker.Toggled;
            end
            return true;
        end

        function KeyPicker:SetValue(Key, Mode)
            if type(Key) == 'table' then
                Mode = Key[2] or Key.Mode or Key.mode or Mode;
                Key = Key[1] or Key.Key or Key.key or Key.Value or 'None';
            end
            DisplayLabel.Text = '[' .. tostring(Key) .. ']';
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
            Library:SafeCallback(KeyPicker.Callback, KeyPicker:GetState());
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker:GetState());
        end

        local Picking = false;
        local lastBind = 0;
        local pickStartTime = 0;

        ToggleLabel.ZIndex = 6;
        PickOuter.ZIndex = 20;

        local function StartPicking()
            if Picking then return end
            Picking = true;
            pickStartTime = tick();
            lastBind = tick();
            DisplayLabel.Text = '...';
            Tween(PickStroke, TweenInfo.new(0.15), { Color = Library.AccentColor });

            local Event;
            Event = InputService.InputBegan:Connect(function(KeyInput)
                if (tick() - pickStartTime) < 0.22 and (KeyInput.UserInputType == Enum.UserInputType.MouseButton1 or KeyInput.UserInputType == Enum.UserInputType.MouseButton2) then
                    return;
                end

                local Key = nil;
                if KeyInput.UserInputType == Enum.UserInputType.Keyboard then
                    if KeyInput.KeyCode == Enum.KeyCode.Escape then
                        Picking = false;
                        lastBind = tick();
                        DisplayLabel.Text = '[' .. tostring(KeyPicker.Value) .. ']';
                        Tween(PickStroke, TweenInfo.new(0.15), { Color = Library.OutlineColor });
                        Event:Disconnect();
                        return;
                    elseif KeyInput.KeyCode == Enum.KeyCode.Backspace or KeyInput.KeyCode == Enum.KeyCode.Delete then
                        Key = 'None';
                    elseif KeyInput.KeyCode ~= Enum.KeyCode.Unknown then
                        Key = KeyInput.KeyCode.Name;
                    end
                elseif KeyInput.UserInputType == Enum.UserInputType.MouseButton1 then
                    Key = 'MB1';
                elseif KeyInput.UserInputType == Enum.UserInputType.MouseButton2 then
                    Key = 'MB2';
                elseif KeyInput.UserInputType == Enum.UserInputType.MouseButton3 then
                    Key = 'MB3';
                end

                if not Key then return end

                Picking = false;
                lastBind = tick();
                Tween(PickStroke, TweenInfo.new(0.15), { Color = Library.OutlineColor });
                DisplayLabel.Text = '[' .. Key .. ']';
                KeyPicker.Value = Key;
                if KeyPicker.UpdateBindRow then KeyPicker:UpdateBindRow(); end
                Library:SafeCallback(KeyPicker.ChangedCallback, KeyInput.KeyCode or KeyInput.UserInputType);
                Library:SafeCallback(KeyPicker.Changed, KeyInput.KeyCode or KeyInput.UserInputType);
                Library:AttemptSave();
                Event:Disconnect();
            end);
        end

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                StartPicking();
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                UpdateModePosition();
                ModeSelectOuter.Visible = true;
                Tween(ModeSelectOuter, TI_FAST, { GroupTransparency = 0 });
            end
        end);

        -- Toggle & Hold Key Listener
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if InputService:GetFocusedTextBox() ~= nil then return end
            local justRebound = (tick() - lastBind) < 0.25;
            if not Picking and not justRebound then
                local Key = KeyPicker.Value;
                if Key and Key ~= 'None' then
                    local match = false;
                    if (Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1)
                        or (Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2)
                        or (Key == 'MB3' and Input.UserInputType == Enum.UserInputType.MouseButton3)
                        or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key) then
                        match = true;
                    end

                    if match and not Library:IsMouseOverFrame(PickOuter) then
                        if KeyPicker.Mode == 'Toggle' then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick();
                        elseif KeyPicker.Mode == 'Hold' then
                            KeyPicker.Toggled = true;
                            KeyPicker:DoClick();
                        end
                    end
                end
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 and ModeSelectOuter.Visible then
                if not Library:IsMouseOverFrame(ModeSelectOuter) and not Library:IsMouseOverFrame(PickOuter) then
                    ModeSelectOuter.Visible = false;
                end
            end
        end));

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if not Picking and KeyPicker.Mode == 'Hold' then
                local Key = KeyPicker.Value;
                if Key and Key ~= 'None' then
                    local match = false;
                    if (Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1)
                        or (Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2)
                        or (Key == 'MB3' and Input.UserInputType == Enum.UserInputType.MouseButton3)
                        or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key) then
                        match = true;
                    end
                    if match then
                        KeyPicker.Toggled = false;
                        KeyPicker:DoClick();
                    end
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

    function Funcs:AddColorPicker(Idx, Info)
        Info = Info or {};
        local label = self:AddLabel(Info.Text or Info.Title or Idx);
        return label:AddColorPicker(Idx, Info);
    end

    function Funcs:AddKeyPicker(Idx, Info)
        Info = Info or {};
        local label = self:AddLabel(Info.Text or Info.Title or Idx);
        return label:AddKeyPicker(Idx, Info);
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

        function Button:AddButton(...)
            local SubButton = {};
            ProcessButtonParams(SubButton, ...);

            local RowHolder = Outer.Parent:FindFirstChild('ButtonRow_' .. tostring(Outer));
            if not RowHolder then
                RowHolder = Library:Create('Frame', {
                    Name = 'ButtonRow_' .. tostring(Outer),
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -8, 0, 24),
                    ZIndex = 2,
                    LayoutOrder = Outer.LayoutOrder,
                    Parent = Container,
                });
                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Horizontal,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 4),
                    Parent = RowHolder,
                });
                Outer.Parent = RowHolder;
                Outer.Size = UDim2.new(0.5, -2, 1, 0);
            end

            local SubOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                Size = UDim2.new(0.5, -2, 1, 0);
                ZIndex = 2;
                Parent = RowHolder;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = SubOuter });
            local SubStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.15, Thickness = 1, Parent = SubOuter });
            local SubBtnScale = Library:Create('UIScale', { Scale = 1, Parent = SubOuter });

            local SubLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 12;
                Text = SubButton.Text or 'Button';
                ZIndex = 3;
                Parent = SubOuter;
            });

            SubOuter.MouseEnter:Connect(function()
                Tween(SubStroke, TI_SMOOTH, { Color = Library.AccentColor, Transparency = 0 });
                Tween(SubOuter, TI_SMOOTH, { BackgroundColor3 = Library.BackgroundColor });
            end);
            SubOuter.MouseLeave:Connect(function()
                Tween(SubStroke, TI_SMOOTH, { Color = Library.OutlineColor, Transparency = 0.4 });
                Tween(SubOuter, TI_SMOOTH, { BackgroundColor3 = Library.MainColor });
            end);

            SubOuter.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                    Tween(SubBtnScale, TI_FAST, { Scale = 0.975 });
                end
            end);
            SubOuter.InputEnded:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Tween(SubBtnScale, TI_POP, { Scale = 1 });
                    if not Library:MouseIsOverOpenedFrame() then Library:SafeCallback(SubButton.Func); end
                end
            end);

            SubButton.Outer = SubOuter;
            SubButton.Label = SubLabel;
            SubButton.TextLabel = SubLabel;
            setmetatable(SubButton, BaseAddons);
            if type(SubButton.Tooltip) == 'string' then Library:AddToolTip(SubButton.Tooltip, SubOuter); end

            Groupbox:Resize();
            return SubButton;
        end

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
            KeyPicker = nil;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleRow = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, -8, 0, 20);
            ZIndex = 2;
            Parent = Container;
        });

        local CheckOuter = Library:Create('Frame', {
            BorderSizePixel = 0;
            BackgroundColor3 = Toggle.Value and Library.AccentColor or Color3.fromRGB(18, 18, 24);
            Position = UDim2.new(0, 0, 0.5, -7);
            Size = UDim2.new(0, 14, 0, 14);
            ZIndex = 3;
            Parent = ToggleRow;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 3), Parent = CheckOuter });
        local CheckStroke = Library:Create('UIStroke', {
            Color = Toggle.Value and Library.AccentColor or Color3.fromRGB(48, 48, 60),
            Transparency = Toggle.Value and 0 or 0.3,
            Thickness = 1,
            Parent = CheckOuter,
        });

        local CheckInner = Library:Create('Frame', {
            BorderSizePixel = 0;
            BackgroundColor3 = Color3.fromRGB(255, 255, 255);
            AnchorPoint = Vector2.new(0.5, 0.5);
            Position = UDim2.new(0.5, 0, 0.5, 0);
            Size = Toggle.Value and UDim2.new(0, 6, 0, 6) or UDim2.new(0, 0, 0, 0);
            BackgroundTransparency = Toggle.Value and 0 or 1;
            ZIndex = 4;
            Parent = CheckOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 1.5), Parent = CheckInner });

        Library:AddToRegistry(CheckOuter, {
            BackgroundColor3 = function()
                return Toggle.Value and Library.AccentColor or Color3.fromRGB(18, 18, 24);
            end;
        });
        Library:AddToRegistry(CheckStroke, {
            Color = function()
                return Toggle.Value and Library.AccentColor or Color3.fromRGB(48, 48, 60);
            end;
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(1, -24, 1, 0);
            Position = UDim2.new(0, 24, 0, 0);
            TextSize = 13;
            Text = Info.Text or 'Toggle';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextColor3 = Toggle.Value and Library.FontColor or Library.DimColor;
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
            Size = UDim2.new(1, -60, 1, 0);
            Text = '';
            ZIndex = 5;
            Parent = ToggleRow;
        });

        function Toggle:Display()
            local boxCol = Toggle.Value and Library.AccentColor or Color3.fromRGB(18, 18, 24);
            local strokeCol = Toggle.Value and Library.AccentColor or Color3.fromRGB(48, 48, 60);
            local innerSize = Toggle.Value and UDim2.new(0, 6, 0, 6) or UDim2.new(0, 0, 0, 0);
            local innerTrans = Toggle.Value and 0 or 1;

            Tween(CheckOuter, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundColor3 = boxCol });
            Tween(CheckStroke, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Color = strokeCol, Transparency = Toggle.Value and 0 or 0.3 });
            Tween(CheckInner, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = innerSize, BackgroundTransparency = innerTrans });

            if not Toggle.Risky then
                Tween(ToggleLabel, TI_FAST, { TextColor3 = Toggle.Value and Library.FontColor or Library.DimColor });
            end
        end

        function Toggle:GetState()
            if not Toggle.Value then return false end
            if Toggle.KeyPicker then
                return Toggle.KeyPicker:GetState()
            end
            return true
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

        ClickRegion.MouseEnter:Connect(function()
            if not Toggle.Value then
                Tween(CheckStroke, TI_FAST, { Color = Library.AccentColor, Transparency = 0.1 });
                Tween(ToggleLabel, TI_FAST, { TextColor3 = Library.FontColor });
            end
        end);

        ClickRegion.MouseLeave:Connect(function()
            if not Toggle.Value then
                Tween(CheckStroke, TI_FAST, { Color = Color3.fromRGB(48, 48, 60), Transparency = 0.3 });
                Tween(ToggleLabel, TI_FAST, { TextColor3 = Library.DimColor });
            end
        end);

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

        local Knob = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 4, 0, 12),
            ZIndex = 4,
            Parent = Fill,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Knob });

        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' });
        Library:AddToRegistry(TrackStroke, { Color = 'OutlineColor' });
        Library:AddToRegistry(DisplayLabel, { TextColor3 = 'AccentColor' });

        local KnobBig = false;
        local function SetKnob(big)
            if KnobBig == big then return end
            KnobBig = big;
            Tween(Knob, TI_FAST, { Size = big and UDim2.new(0, 5, 0, 14) or UDim2.new(0, 4, 0, 12) });
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

-- < Master Auto-Aligning Notification Engine >
do
    local NotifConfig = {
        Preset = 'Bottom Right',
        CustomX = 98,
        CustomY = 98,
        Width = 280,
    };

    Library.NotificationArea = Library:Create('Frame', {
        Name = 'MikuNotificationArea',
        BackgroundTransparency = 1;
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 280, 0, 400),
        ZIndex = 5000;
        Parent = ScreenGui;
    });

    local NotifLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, 8);
        FillDirection = Enum.FillDirection.Vertical;
        VerticalAlignment = Enum.VerticalAlignment.Bottom;
        HorizontalAlignment = Enum.HorizontalAlignment.Right;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    function Library:ConfigureNotifications(cfg)
        cfg = cfg or {};
        if cfg.Preset then NotifConfig.Preset = cfg.Preset; end
        if cfg.CustomX ~= nil then NotifConfig.CustomX = cfg.CustomX; end
        if cfg.CustomY ~= nil then NotifConfig.CustomY = cfg.CustomY; end
        if cfg.PositionX ~= nil then NotifConfig.CustomX = cfg.PositionX; NotifConfig.Preset = 'Custom'; end
        if cfg.PositionY ~= nil then NotifConfig.CustomY = cfg.PositionY; NotifConfig.Preset = 'Custom'; end
        if cfg.Width then NotifConfig.Width = cfg.Width; end

        local area = Library.NotificationArea;
        if not area then return end

        local p = NotifConfig.Preset;
        local w = NotifConfig.Width or 280;
        area.Size = UDim2.new(0, w, 0, 450);

        if p == 'Bottom Right' then
            area.AnchorPoint = Vector2.new(1, 1);
            area.Position = UDim2.new(1, -16, 1, -16);
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom;
            NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right;
        elseif p == 'Bottom Left' then
            area.AnchorPoint = Vector2.new(0, 1);
            area.Position = UDim2.new(0, 16, 1, -16);
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom;
            NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left;
        elseif p == 'Bottom Center' then
            area.AnchorPoint = Vector2.new(0.5, 1);
            area.Position = UDim2.new(0.5, 0, 1, -16);
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom;
            NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center;
        elseif p == 'Top Right' then
            area.AnchorPoint = Vector2.new(1, 0);
            area.Position = UDim2.new(1, -16, 0, 16);
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Top;
            NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right;
        elseif p == 'Top Left' then
            area.AnchorPoint = Vector2.new(0, 0);
            area.Position = UDim2.new(0, 16, 0, 16);
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Top;
            NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left;
        elseif p == 'Top Center' then
            area.AnchorPoint = Vector2.new(0.5, 0);
            area.Position = UDim2.new(0.5, 0, 0, 16);
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Top;
            NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center;
        elseif p == 'Middle Right' then
            area.AnchorPoint = Vector2.new(1, 0.5);
            area.Position = UDim2.new(1, -16, 0.5, 0);
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Center;
            NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right;
        elseif p == 'Middle Left' then
            area.AnchorPoint = Vector2.new(0, 0.5);
            area.Position = UDim2.new(0, 16, 0.5, 0);
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Center;
            NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left;
        elseif p == 'Custom' then
            local xNorm = math.clamp((NotifConfig.CustomX or 98) / 100, 0, 1);
            local yNorm = math.clamp((NotifConfig.CustomY or 98) / 100, 0, 1);
            area.AnchorPoint = Vector2.new(xNorm, yNorm);
            local offsetXPx = (xNorm <= 0.2 and 16) or (xNorm >= 0.8 and -16) or 0;
            local offsetYPx = (yNorm <= 0.2 and 16) or (yNorm >= 0.8 and -16) or 0;
            area.Position = UDim2.new(xNorm, offsetXPx, yNorm, offsetYPx);
            NotifLayout.VerticalAlignment = yNorm > 0.5 and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top;
            NotifLayout.HorizontalAlignment = xNorm > 0.6 and Enum.HorizontalAlignment.Right or (xNorm < 0.4 and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center);
        end
    end

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

function Library:Notify(Text, Time)
    Time = Time or 4;
    local cardWidth = 280;
    local textBoundsX, textBoundsY = Library:GetTextBounds(Text, Library.Font, 12, Vector2.new(cardWidth - 40, math.huge));
    local cardHeight = math.max(textBoundsY + 22, 42);

    local NotifyCard = Library:Create('CanvasGroup', {
        Name = 'NotifyCard',
        GroupTransparency = 1;
        BackgroundColor3 = Library.BackgroundColor,
        Size = UDim2.new(0, cardWidth, 0, cardHeight),
        ZIndex = 5001,
        Parent = Library.NotificationArea,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = NotifyCard });
    local Stroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.15, Thickness = 1.5, Parent = NotifyCard });
    Library:AddToRegistry(Stroke, { Color = 'OutlineColor' });
    Library:AddToRegistry(NotifyCard, { BackgroundColor3 = 'BackgroundColor' });

    local CardScale = Library:Create('UIScale', { Scale = 0.88, Parent = NotifyCard });

    -- Left glowing accent indicator bar
    local LeftBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -8),
        AnchorPoint = Vector2.new(0, 0.5);
        Position = UDim2.new(0, 5, 0.5, 0);
        ZIndex = 5002,
        Parent = NotifyCard,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = LeftBar });
    Library:AddToRegistry(LeftBar, { BackgroundColor3 = 'AccentColor' });

    -- Glowing status dot
    local Dot = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(4, 4),
        Position = UDim2.new(0, 14, 0, 8),
        ZIndex = 5003,
        Parent = NotifyCard,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Dot });
    Library:AddToRegistry(Dot, { BackgroundColor3 = 'AccentColor' });

    local HeaderTag = Library:CreateLabel({
        Position = UDim2.new(0, 22, 0, 3),
        Size = UDim2.new(1, -26, 0, 14),
        Text = 'NOTIFICATION',
        TextColor3 = Library.AccentColor,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5003,
        Parent = NotifyCard,
    });
    Library:AddToRegistry(HeaderTag, { TextColor3 = 'AccentColor' });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 14, 0, 18),
        Size = UDim2.new(1, -22, 0, textBoundsY + 2),
        Text = Text,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5002,
        Parent = NotifyCard,
    });

    -- Bottom Lifetime Countdown Bar
    local TimeTrack = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        Position = UDim2.new(0, 0, 1, -2),
        Size = UDim2.new(1, 0, 0, 2),
        BorderSizePixel = 0,
        ZIndex = 5003,
        Parent = NotifyCard,
    });
    local TimeFill = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 5004,
        Parent = TimeTrack,
    });
    Library:AddToRegistry(TimeFill, { BackgroundColor3 = 'AccentColor' });

    -- Entrance animation
    Tween(NotifyCard, TI_SMOOTH, { GroupTransparency = 0 });
    Tween(CardScale, TI_POP, { Scale = 1 });
    Tween(TimeFill, TweenInfo.new(Time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { Size = UDim2.new(0, 0, 1, 0) });

    task.delay(Time, function()
        Tween(NotifyCard, TI_SMOOTH, { GroupTransparency = 1 });
        Tween(CardScale, TI_SMOOTH, { Scale = 0.92 });
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

-- ====================================================================
-- MASTER NEXT-GEN CYBER COBWEB PHYSICS SYSTEM (WebManager)
-- Features:
-- 1. Smooth multi-segment quadratic bezier catenary droop curves
-- 2. Smart boundary nearest-edge anchor calculations (never crosses windows)
-- 3. Auto disconnect and reconnect physics with tensile distance culling
-- 4. Authentic spiderweb corner fans and dewdrop beads on open windows
-- ====================================================================
local WebManager = {
    Container = nil,
    StrandPool = {},
    NodePool = {},
    ActiveStrands = 0,
    ActiveNodes = 0,
    Window = nil,
};

function WebManager:Init(Window)
    self.Window = Window;
    if self.Container then return end
    self.Container = Library:Create('Frame', {
        Name = 'MikuWebMeshContainer',
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 2,
        Parent = ScreenGui,
    });
end

function WebManager:GetStrand()
    self.ActiveStrands = self.ActiveStrands + 1;
    local strand = self.StrandPool[self.ActiveStrands];
    if not strand then
        strand = Library:Create('Frame', {
            Name = 'WebStrand',
            BorderSizePixel = 0,
            BackgroundColor3 = Library.AccentColor,
            BackgroundTransparency = 0.45,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, 0, 0, 1),
            ZIndex = 2,
            Parent = self.Container,
        });
        Library:AddToRegistry(strand, { BackgroundColor3 = 'AccentColor' }, true);
        table.insert(self.StrandPool, strand);
    end
    strand.Visible = true;
    return strand;
end

function WebManager:GetNode(size, trans)
    self.ActiveNodes = self.ActiveNodes + 1;
    local node = self.NodePool[self.ActiveNodes];
    if not node then
        node = Library:Create('Frame', {
            Name = 'WebNode',
            BorderSizePixel = 0,
            BackgroundColor3 = Library.AccentColor,
            BackgroundTransparency = trans or 0.25,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(size or 4, size or 4),
            ZIndex = 3,
            Parent = self.Container,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = node });
        Library:AddToRegistry(node, { BackgroundColor3 = 'AccentColor' }, true);
        table.insert(self.NodePool, node);
    end
    node.Size = UDim2.fromOffset(size or 4, size or 4);
    node.BackgroundTransparency = trans or 0.25;
    node.Visible = true;
    return node;
end

function WebManager:Reset()
    for i = 1, #self.StrandPool do
        self.StrandPool[i].Visible = false;
    end
    for i = 1, #self.NodePool do
        self.NodePool[i].Visible = false;
    end
    self.ActiveStrands = 0;
    self.ActiveNodes = 0;
end

function WebManager:DrawSegment(ax, ay, bx, by, trans, thick)
    local dx = bx - ax;
    local dy = by - ay;
    local len = math.sqrt(dx * dx + dy * dy);
    if len < 1.5 then return nil end
    local strand = self:GetStrand();
    strand.Position = UDim2.fromOffset(ax + dx * 0.5, ay + dy * 0.5);
    strand.Size = UDim2.new(0, len, 0, thick or 1);
    strand.Rotation = math.deg(math.atan2(dy, dx));
    strand.BackgroundTransparency = math.clamp(trans or 0.45, 0, 1);
    return strand;
end

-- Multi-segment smooth quadratic catenary droop curve
function WebManager:DrawCatenaryCurve(ax, ay, bx, by, sagAmount, trans, thickness, numSegments, withNodes)
    local dx = bx - ax;
    local dy = by - ay;
    local dist = math.sqrt(dx * dx + dy * dy);
    if dist < 4 then return nil end

    local sag = sagAmount or math.clamp(dist * 0.18, 8, 48);
    local mx = ax + dx * 0.5;
    local my = ay + dy * 0.5 + sag;
    local cx = mx;
    local cy = my + sag * 0.4;

    local N = numSegments or 5;
    local prevX, prevY = ax, ay;
    local midX, midY = mx, my;

    for i = 1, N do
        local t = i / N;
        local invT = 1 - t;
        local curX = invT * invT * ax + 2 * invT * t * cx + t * t * bx;
        local curY = invT * invT * ay + 2 * invT * t * cy + t * t * by;

        self:DrawSegment(prevX, prevY, curX, curY, trans or 0.45, thickness or 1);

        if i == math.floor(N / 2) then
            midX, midY = curX, curY;
            if withNodes ~= false then
                local sagNode = self:GetNode(4, math.max(0.12, (trans or 0.45) - 0.15));
                sagNode.Position = UDim2.fromOffset(curX, curY);
            end
        end
        prevX, prevY = curX, curY;
    end

    return midX, midY;
end

-- Authentic spiderweb corner fan gusset
function WebManager:DrawCornerWeb(ox, oy, dirX, dirY, size, trans)
    size = size or 28;
    trans = trans or 0.55;
    local r1x, r1y = ox + dirX * size, oy;
    local r2x, r2y = ox + dirX * (size * 0.78), oy + dirY * (size * 0.78);
    local r3x, r3y = ox, oy + dirY * size;

    -- 3 Radial silk rays
    self:DrawSegment(ox, oy, r1x, r1y, trans, 1);
    self:DrawSegment(ox, oy, r2x, r2y, trans, 1);
    self:DrawSegment(ox, oy, r3x, r3y, trans, 1);

    -- 2 Concentric sagging web arcs
    local a1x, a1y = ox + dirX * (size * 0.45), oy;
    local a2x, a2y = ox + dirX * (size * 0.38), oy + dirY * (size * 0.38) + 2;
    local a3x, a3y = ox, oy + dirY * (size * 0.45);

    self:DrawSegment(a1x, a1y, a2x, a2y, trans + 0.1, 1);
    self:DrawSegment(a2x, a2y, a3x, a3y, trans + 0.1, 1);

    local b1x, b1y = r1x, r1y;
    local b2x, b2y = r2x, r2y + 3;
    local b3x, b3y = r3x, r3y;

    self:DrawSegment(b1x, b1y, b2x, b2y, trans + 0.05, 1);
    self:DrawSegment(b2x, b2y, b3x, b3y, trans + 0.05, 1);

    -- Tiny dew droplets at ray junctions
    local n1 = self:GetNode(3, trans - 0.1);
    n1.Position = UDim2.fromOffset(r2x, r2y);
    local n2 = self:GetNode(2, trans);
    n2.Position = UDim2.fromOffset(a2x, a2y);
end

local openTabsBuffer = table.create(16);
function WebManager:Update()
    self:Reset();
    if not Library.Toggled or not self.Window then return end

    table.clear(openTabsBuffer);
    for _, tab in next, self.Window.Tabs do
        if tab.IsOpen and tab.ModWindow and tab.ModWindow.Visible then
            table.insert(openTabsBuffer, tab);
        end
    end

    local openCount = #openTabsBuffer;
    if openCount == 0 then return end

    local timeSec = tick();
    local windPulse = math.sin(timeSec * 2.2) * 2.5;

    -- 1. Draw Spiderweb Corner Fans on all open windows
    for _, tab in ipairs(openTabsBuffer) do
        local win = tab.ModWindow;
        if win then
            local winPos, winSize = win.AbsolutePosition, win.AbsoluteSize;
            -- Top-left corner web
            self:DrawCornerWeb(winPos.X, winPos.Y, 1, 1, 26, 0.58);
            -- Top-right corner web
            self:DrawCornerWeb(winPos.X + winSize.X, winPos.Y, -1, 1, 26, 0.58);
        end
    end

    -- 2. Draw Pill-to-Window Hanging Silk Tethers with realistic catenary droop
    for _, tab in ipairs(openTabsBuffer) do
        local pill = tab.TabPill;
        local win = tab.ModWindow;
        if pill and win then
            local pillPos, pillSize = pill.AbsolutePosition, pill.AbsoluteSize;
            local winPos, winSize = win.AbsolutePosition, win.AbsoluteSize;

            local px = pillPos.X + pillSize.X * 0.5;
            local py = pillPos.Y + pillSize.Y - 1;
            local wx = winPos.X + winSize.X * 0.5;
            local wy = winPos.Y;

            -- Pill anchor dewdrop
            local pn = self:GetNode(4, 0.15);
            pn.Position = UDim2.fromOffset(px, py);

            -- Window top anchor dewdrop
            local wn = self:GetNode(4, 0.2);
            wn.Position = UDim2.fromOffset(wx, wy);

            local gapY = wy - py;
            local stemLen = math.clamp(gapY * 0.15, 6, 22);

            -- Vertical anchor stem from pill
            self:DrawSegment(px, py, px, py + stemLen, 0.38, 1.5);
            local stemNode = self:GetNode(3, 0.25);
            stemNode.Position = UDim2.fromOffset(px, py + stemLen);

            -- Hanging multi-segment curved main web line with sag
            local sagAmt = math.clamp(gapY * 0.16 + windPulse, 8, 40);
            local mx, my = self:DrawCatenaryCurve(
                px, py + stemLen,
                wx, wy,
                sagAmt,
                0.40,
                1.2,
                5,
                true
            );

            if mx and my then
                tab._webMid = Vector2.new(mx, my);

                -- Lateral corner fan anchor strands for authentic cobweb tethering
                local lx = winPos.X + 16;
                local rx = winPos.X + winSize.X - 16;
                self:DrawCatenaryCurve(mx, my, lx, wy, 4, 0.62, 1, 3, false);
                self:DrawCatenaryCurve(mx, my, rx, wy, 4, 0.62, 1, 3, false);

                local cl = self:GetNode(3, 0.4);
                cl.Position = UDim2.fromOffset(lx, wy);
                local cr = self:GetNode(3, 0.4);
                cr.Position = UDim2.fromOffset(rx, wy);
            end

            tab._winBounds = { Pos = winPos, Size = winSize };
        end
    end

    -- 3. Interconnect open windows with Smart Nearest-Edge Auto-Connect/Disconnect
    if openCount >= 2 then
        local maxBridgeDist = 420;
        local minBridgeDist = 20;

        for i = 1, openCount do
            for j = i + 1, openCount do
                local tabA = openTabsBuffer[i];
                local tabB = openTabsBuffer[j];
                if tabA._winBounds and tabB._winBounds then
                    local aPos, aSize = tabA._winBounds.Pos, tabA._winBounds.Size;
                    local bPos, bSize = tabB._winBounds.Pos, tabB._winBounds.Size;

                    local centerA = Vector2.new(aPos.X + aSize.X * 0.5, aPos.Y + aSize.Y * 0.5);
                    local centerB = Vector2.new(bPos.X + bSize.X * 0.5, bPos.Y + bSize.Y * 0.5);

                    -- Calculate nearest points on window header bounds to prevent clumsy crossing
                    local ax = math.clamp(centerB.X, aPos.X + 8, aPos.X + aSize.X - 8);
                    local ay = math.clamp(centerB.Y, aPos.Y, aPos.Y + 34);
                    local bx = math.clamp(centerA.X, bPos.X + 8, bPos.X + bSize.X - 8);
                    local by = math.clamp(centerA.Y, bPos.Y, bPos.Y + 34);

                    local dist = math.sqrt((bx - ax)^2 + (by - ay)^2);

                    -- AUTO DISCONNECT & RECONNECT: Only connect within dynamic tensile range
                    if dist >= minBridgeDist and dist <= maxBridgeDist then
                        local alpha = 1 - (dist - minBridgeDist) / (maxBridgeDist - minBridgeDist);
                        local bridgeTrans = math.clamp(0.32 + (1 - alpha) * 0.48, 0.25, 0.88);
                        local bridgeSag = math.clamp(dist * 0.16 - windPulse * 0.8, 6, 42);

                        -- Draw multi-segment catenary droop bridge between closest edges
                        local interMx, interMy = self:DrawCatenaryCurve(
                            ax, ay,
                            bx, by,
                            bridgeSag,
                            bridgeTrans,
                            1.2,
                            5,
                            true
                        );

                        -- Endpoint connection dewdrops
                        local nA = self:GetNode(3, math.max(0.1, bridgeTrans - 0.15));
                        nA.Position = UDim2.fromOffset(ax, ay);
                        local nB = self:GetNode(3, math.max(0.1, bridgeTrans - 0.15));
                        nB.Position = UDim2.fromOffset(bx, by);

                        -- Secondary cross-lattice thread when windows are in close proximity
                        if dist < 260 and interMx and interMy and tabA._webMid and tabB._webMid then
                            self:DrawSegment(tabA._webMid.X, tabA._webMid.Y, interMx, interMy, bridgeTrans + 0.18, 1);
                            self:DrawSegment(tabB._webMid.X, tabB._webMid.Y, interMx, interMy, bridgeTrans + 0.18, 1);
                        end
                    end
                end
            end
        end
    end
end

Library.WebManager = WebManager;

-- ====================================================================
-- TOP DOCK / MODULAR MULTI-WINDOW ARCHITECTURE
-- ====================================================================
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

    WebManager:Init(Window);

    -- Top Navigation Dock Bar
    local TopDock = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 14),
        Size = UDim2.fromOffset(560, 50),
        BackgroundColor3 = Library.BackgroundColor,
        ZIndex = 30,
        Parent = ScreenGui,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Dock), Parent = TopDock });
    local DockStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.15, Thickness = 1.2, Parent = TopDock });
    local DockGradient = Library:Create('UIGradient', {
        Rotation = 90;
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255));
            ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 224, 235));
        });
        Parent = TopDock;
    });
    Library:AddToRegistry(TopDock, { BackgroundColor3 = 'BackgroundColor' });
    Library:AddToRegistry(DockStroke, { Color = 'OutlineColor' });

    -- TopDock Drop Shadow
    Library:Create('ImageLabel', {
        Name = 'DockShadow',
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 24, 1, 24),
        BackgroundTransparency = 1,
        Image = 'rbxassetid://6015897843',
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.4,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ScaleType = Enum.ScaleType.Slice,
        SliceScale = 1,
        ZIndex = 29,
        Parent = TopDock,
    });

    local TitleW = Library:GetTextBounds(Config.Title, Library.Font, 14);
    local HeaderW = math.max(96, 38 + TitleW + 12);

    local DockHeader = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(0, HeaderW - 14, 1, 0),
        ZIndex = 31,
        Parent = TopDock,
    });

    -- Make TopDock draggable by its header
    Library:MakeDraggable(TopDock, DockHeader);

    local PulsingDot = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Library.AccentColor,
        ZIndex = 32,
        Parent = DockHeader,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = PulsingDot });
    Library:AddToRegistry(PulsingDot, { BackgroundColor3 = 'AccentColor' });

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
        ZIndex = 32,
        Active = false,
        Selectable = false,
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
        ZIndex = 32,
        Parent = TopDock,
    });

    -- Horizontal Tab Navigation Pills
    local TabScroll = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, HeaderW + 12, 0, 7),
        Size = UDim2.new(1, -(HeaderW + 152), 1, -14),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X;
        ScrollingDirection = Enum.ScrollingDirection.X;
        ScrollBarThickness = 0,
        Active = false,
        Selectable = false,
        ZIndex = 31,
        Parent = TopDock,
    });

    local TabLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding),
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center;
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabScroll,
    });

    local function FitDockWidth()
        local contentW = TabLayout.AbsoluteContentSize.X;
        if contentW <= 0 then return end
        local cam = workspace.CurrentCamera;
        local maxW = cam and (cam.ViewportSize.X - 40) or 900;
        local w = math.floor(math.clamp(HeaderW + contentW + 160, 620, maxW));
        TopDock.Size = UDim2.fromOffset(w, 50);
        TabScroll.CanvasSize = UDim2.fromOffset(contentW + 12, 0);
    end
    TabLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(FitDockWidth);

    TabScroll.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local maxScroll = math.max(0, TabScroll.AbsoluteCanvasSize.X - TabScroll.AbsoluteWindowSize.X);
            TabScroll.CanvasPosition = Vector2.new(
                math.clamp(TabScroll.CanvasPosition.X - input.Position.Z * 32, 0, maxScroll), 0);
        end
    end);

    -- Quick Actions (Arrange & Hide/Show all)
    local QuickActions = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -136, 0, 7),
        Size = UDim2.new(0, 128, 1, -14),
        ZIndex = 31,
        Parent = TopDock,
    });

    local ArrangeBtn = Library:Create('TextButton', {
        AutoButtonColor = false;
        BackgroundColor3 = Library.MainColor,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.5, -3, 1, 0),
        Font = Library.Font,
        Text = 'arrange',
        TextColor3 = Library.DimColor,
        TextSize = 11,
        ZIndex = 32,
        Active = true,
        Parent = QuickActions,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = ArrangeBtn });
    local ArrangeStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.15, Thickness = 1, Parent = ArrangeBtn });

    ArrangeBtn.MouseEnter:Connect(function()
        Tween(ArrangeBtn, TI_FAST, { TextColor3 = Library.AccentColor, BackgroundColor3 = Library.BackgroundColor });
        Tween(ArrangeStroke, TI_FAST, { Transparency = 0 });
    end);
    ArrangeBtn.MouseLeave:Connect(function()
        Tween(ArrangeBtn, TI_FAST, { TextColor3 = Library.DimColor, BackgroundColor3 = Library.MainColor });
        Tween(ArrangeStroke, TI_FAST, { Transparency = 0.4 });
    end);

    local CloseAllBtn = Library:Create('TextButton', {
        AutoButtonColor = false;
        BackgroundColor3 = Library.MainColor,
        Position = UDim2.new(0.5, 3, 0, 0),
        Size = UDim2.new(0.5, -3, 1, 0),
        Font = Library.Font,
        Text = 'hide all',
        TextColor3 = Library.DimColor,
        TextSize = 11,
        ZIndex = 32,
        Active = true,
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

    function Window:ArrangeWindows()
        local openTabs = {};
        for _, tab in next, Window.Tabs do
            if tab.IsOpen and tab.ModWindow and tab.ModWindow.Visible then
                table.insert(openTabs, tab);
            end
        end

        local cam = workspace.CurrentCamera;
        local vpX = cam and cam.ViewportSize.X or 1920;
        local vpY = cam and cam.ViewportSize.Y or 1080;

        local winW = 460;
        local winH = 520;
        local startX = 35;
        local startY = 75;
        local gapX = 18;
        local gapY = 18;
        local maxCols = math.max(1, math.floor((vpX - startX) / (winW + gapX)));

        for i, tab in ipairs(openTabs) do
            local slotIndex = i - 1;
            local col = slotIndex % maxCols;
            local row = math.floor(slotIndex / maxCols);

            local targetX = math.clamp(startX + col * (winW + gapX), 8, math.max(8, vpX - winW - 8));
            local targetY = math.clamp(startY + row * (winH + gapY), 60, math.max(60, vpY - winH - 8));

            Tween(tab.ModWindow, TI_SOFT, { Position = UDim2.fromOffset(targetX, targetY) });
        end
        task.delay(0.3, function() if WebManager then WebManager:Update(true); end end);
    end

    ArrangeBtn.MouseButton1Click:Connect(function()
        Window:ArrangeWindows();
        Library:Notify('Windows arranged side-by-side!', 2);
    end);

    local lastCloseAll = 0;
    local function ToggleAllTabs()
        local now = tick();
        if (now - lastCloseAll) < 0.22 then return end
        lastCloseAll = now;
        local anyOpen = false;
        for _, tab in next, Window.Tabs do
            if tab.IsOpen then anyOpen = true; break; end
        end
        for _, tab in next, Window.Tabs do
            if anyOpen then tab:CloseWindow(); else tab:OpenWindow(); end
        end
        CloseAllBtn.Text = anyOpen and 'show all' or 'hide all';
    end

    CloseAllBtn.MouseButton1Click:Connect(ToggleAllTabs);

    local windowIndex = 0;

    function Window:AddTab(Name)
        windowIndex = windowIndex + 1;
        Name = Name or ('Tab ' .. windowIndex);
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
            IsOpen = (Window.AutoShow and windowIndex == 1);
            Active = (Window.AutoShow and windowIndex == 1);
        };

        local NameW = Library:GetTextBounds(Name, Library.Font, 12);
        local PillW = NameW + 26;

        local TabPill = Library:Create('TextButton', {
            AutoButtonColor = false;
            BackgroundColor3 = Library.MainColor,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, PillW, 1, 0),
            Text = '',
            Active = true,
            Selectable = true,
            ZIndex = 33,
            Parent = TabScroll,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = TabPill });
        local PillStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 1, Thickness = 1, Parent = TabPill });

        local Underline = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 1);
            Position = UDim2.new(0.5, 0, 1, -3);
            Size = UDim2.new(0, 0, 0, 2);
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            ZIndex = 35;
            Parent = TabPill;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Underline });
        Library:AddToRegistry(Underline, { BackgroundColor3 = 'AccentColor' });

        local PillName = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            Text = Name,
            TextSize = 12;
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex = 34;
            Active = false,
            Selectable = false,
            Parent = TabPill,
        });
        PillName.TextColor3 = Library.DimColor;

        local hoveringPill = false;

        local function RefreshPill(Hovered)
            if Tab.IsOpen then
                Tween(PillStroke, TI_SMOOTH, { Color = Library.AccentColor, Transparency = Hovered and 0.1 or 0.35 });
                Tween(PillName, TI_SMOOTH, { TextColor3 = Library.AccentColor });
                Tween(TabPill, TI_SMOOTH, { BackgroundColor3 = Library.BackgroundColor, BackgroundTransparency = 0 });
                Tween(Underline, TI_SOFT, { Size = UDim2.new(0.55, 0, 0, 2), BackgroundTransparency = 0.05 });
            elseif Hovered then
                Tween(PillStroke, TI_FAST, { Color = Library.OutlineColor, Transparency = 0.25 });
                Tween(PillName, TI_FAST, { TextColor3 = Library.FontColor });
                Tween(TabPill, TI_FAST, { BackgroundColor3 = Library.MainColor, BackgroundTransparency = 0 });
                Tween(Underline, TI_FAST, { Size = UDim2.new(0.18, 0, 0, 2), BackgroundTransparency = 0.45 });
            else
                Tween(PillStroke, TI_SMOOTH, { Color = Library.OutlineColor, Transparency = 1 });
                Tween(PillName, TI_SMOOTH, { TextColor3 = Library.DimColor });
                Tween(TabPill, TI_SMOOTH, { BackgroundTransparency = 1 });
                Tween(Underline, TI_SMOOTH, { Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1 });
            end
        end

        TabPill.MouseEnter:Connect(function()
            hoveringPill = true;
            RefreshPill(true);
        end);

        TabPill.MouseLeave:Connect(function()
            hoveringPill = false;
            RefreshPill(false);
        end);

        -- Floating Modular Window for this Tab
        local ModWindow = Library:Create('Frame', {
            Position = UDim2.fromOffset(70, 90),
            Size = UDim2.fromOffset(460, 520),
            BackgroundColor3 = Library.BackgroundColor,
            Visible = Tab.IsOpen,
            ZIndex = 10,
            Active = true,
            Parent = ScreenGui,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Window), Parent = ModWindow });
        local ModWindowStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.15, Thickness = 1.2, Parent = ModWindow });
        Library:AddToRegistry(ModWindowStroke, { Color = 'OutlineColor' });

        -- ModWindow Drop Shadow
        Library:Create('ImageLabel', {
            Name = 'WindowShadow',
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 28, 1, 28),
            BackgroundTransparency = 1,
            Image = 'rbxassetid://6015897843',
            ImageColor3 = Color3.fromRGB(0, 0, 0),
            ImageTransparency = 0.45,
            SliceCenter = Rect.new(49, 49, 450, 450),
            ScaleType = Enum.ScaleType.Slice,
            SliceScale = 1,
            ZIndex = 9,
            Parent = ModWindow,
        });

        local WinScale = Library:Create('UIScale', { Scale = 1, Parent = ModWindow });

        -- Window Header (Draggable)
        local WinHeader = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            Size = UDim2.new(1, 0, 0, 34),
            ZIndex = 11,
            Active = true,
            Parent = ModWindow,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Window), Parent = WinHeader });

        -- Bottom flat cover for top header corner
        local HeaderCover = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 1, -8),
            Size = UDim2.new(1, 0, 0, 8),
            ZIndex = 11,
            Parent = WinHeader,
        });

        local HeaderAccent = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 12, 0.5, -5);
            Size = UDim2.new(0, 3, 0, 10);
            ZIndex = 12;
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
            ZIndex = 12,
            Active = false,
            Selectable = false,
            Parent = WinHeader,
        });

        -- Close button (x)
        local CloseBtn = Library:Create('TextButton', {
            AutoButtonColor = false;
            BackgroundTransparency = 1;
            AnchorPoint = Vector2.new(1, 0);
            Position = UDim2.new(1, -6, 0, 0);
            Size = UDim2.fromOffset(26, 34);
            Font = Library.Font;
            Text = 'x';
            TextSize = 14;
            TextColor3 = Library.DimColor;
            Active = true,
            Selectable = true,
            ZIndex = 14;
            Parent = WinHeader,
        });
        CloseBtn.MouseEnter:Connect(function()
            Tween(CloseBtn, TI_FAST, { TextColor3 = Library.RiskColor });
        end);
        CloseBtn.MouseLeave:Connect(function()
            Tween(CloseBtn, TI_FAST, { TextColor3 = Library.DimColor });
        end);

        local lastCloseClick = 0;
        local function DoCloseWindow()
            local now = tick();
            if (now - lastCloseClick) < 0.22 then return end
            lastCloseClick = now;
            Tab:CloseWindow();
        end

        CloseBtn.MouseButton1Click:Connect(DoCloseWindow);

        -- Make ModWindow draggable via WinHeader
        Library:MakeDraggable(ModWindow, WinHeader);

        -- Window Focus: Bring window forward on click
        local function FocusWindow()
            for _, otherWin in next, Window.ModularWindows do
                if otherWin and otherWin ~= ModWindow then
                    otherWin.ZIndex = 10;
                end
            end
            ModWindow.ZIndex = 15;
        end
        ModWindow.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                FocusWindow();
            end
        end);

        -- Window Content (Two Columns: Left & Right)
        local ContentBody = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 42),
            Size = UDim2.new(1, -16, 1, -52),
            ZIndex = 11,
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
            ZIndex = 11,
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
            ZIndex = 11,
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
            Tab.IsOpen = true;
            Tab.Active = true;
            if not Tab.HasOpened then
                Tab.HasOpened = true;
                local cam = workspace.CurrentCamera;
                local vpX = cam and cam.ViewportSize.X or 1920;
                local vpY = cam and cam.ViewportSize.Y or 1080;
                local winW = 460;
                local winH = 520;
                local startX = 35;
                local startY = 75;
                local gapX = 18;
                local gapY = 18;

                local maxCols = math.max(1, math.floor((vpX - startX) / (winW + gapX)));
                
                -- Check currently open visible windows to find an unoccupied grid slot
                local occupiedSlots = {};
                for _, otherTab in next, Window.Tabs do
                    if otherTab ~= Tab and otherTab.IsOpen and otherTab.ModWindow and otherTab.ModWindow.Visible then
                        local pos = otherTab.ModWindow.AbsolutePosition;
                        local col = math.floor((pos.X - startX + (winW * 0.4)) / (winW + gapX));
                        local row = math.floor((pos.Y - startY + (winH * 0.4)) / (winH + gapY));
                        if col >= 0 and row >= 0 then
                            occupiedSlots[string.format("%d_%d", col, row)] = true;
                        end
                    end
                end

                -- Find first free non-overlapping slot
                local placed = false;
                for row = 0, 3 do
                    for col = 0, maxCols - 1 do
                        local key = string.format("%d_%d", col, row);
                        if not occupiedSlots[key] then
                            local targetX = math.clamp(startX + col * (winW + gapX), 8, math.max(8, vpX - winW - 8));
                            local targetY = math.clamp(startY + row * (winH + gapY), 60, math.max(60, vpY - winH - 8));
                            ModWindow.Position = UDim2.fromOffset(targetX, targetY);
                            placed = true;
                            break;
                        end
                    end
                    if placed then break; end
                end

                if not placed then
                    local cascade = (windowIndex - 1) % 6;
                    ModWindow.Position = UDim2.fromOffset(
                        math.clamp(startX + cascade * 40, 8, math.max(8, vpX - winW - 8)),
                        math.clamp(startY + cascade * 30, 60, math.max(60, vpY - winH - 8))
                    );
                end
            end
            ModWindow.Visible = true;
            FocusWindow();
            WinScale.Scale = 0.95;
            Tween(WinScale, TI_POP, { Scale = 1 });
            Tween(ModWindowStroke, TI_SMOOTH, { Color = Library.AccentColor, Transparency = 0 });
            task.delay(0.5, function()
                if Tab.Active then Tween(ModWindowStroke, TI_SMOOTH, { Color = Library.OutlineColor, Transparency = 0.25 }); end
            end);
            RefreshPill(hoveringPill);
            if WebManager then WebManager:Update(true); end
        end

        function Tab:CloseWindow()
            Tab.IsOpen = false;
            Tab.Active = false;
            ModWindow.Visible = false;
            WinScale.Scale = 1;
            RefreshPill(hoveringPill);
            WebManager:Update();
        end

        function Tab:ToggleWindow()
            if Tab.IsOpen then Tab:CloseWindow(); else Tab:OpenWindow(); end
        end

        local lastTabClick = 0;
        local function HandlePillClick()
            local now = tick();
            if (now - lastTabClick) < 0.22 then return end
            lastTabClick = now;
            Tween(Underline, TI_FAST, { Size = UDim2.new(0.85, 0, 0, 2) });
            Tab:ToggleWindow();
        end

        TabPill.MouseButton1Click:Connect(HandlePillClick);

        function Tab:ShowTab() Tab:OpenWindow(); end
        function Tab:HideTab() Tab:CloseWindow(); end

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
                ZIndex = 11,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Groupbox), Parent = BoxOuter });
            local GroupStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0, Thickness = 1, Parent = BoxOuter });
            Library:AddToRegistry(GroupStroke, { Color = 'OutlineColor' });

            local Header = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 6),
                Size = UDim2.new(1, -16, 0, 18),
                ZIndex = 12,
                Parent = BoxOuter,
            });

            local AccentBar = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 0, 0.5, -5),
                Size = UDim2.new(0, 3, 0, 10),
                ZIndex = 13,
                Parent = Header,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = AccentBar });
            Library:AddToRegistry(AccentBar, { BackgroundColor3 = 'AccentColor' });

            Library:CreateLabel({
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -8, 1, 0),
                TextSize = 12,
                Text = Info.Name,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 13,
                Parent = Header,
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 26),
                Size = UDim2.new(1, -12, 1, -30),
                ZIndex = 12,
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
                ZIndex = 11,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Groupbox), Parent = BoxOuter });
            local TabboxStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0, Thickness = 1, Parent = BoxOuter });
            Library:AddToRegistry(TabboxStroke, { Color = 'OutlineColor' });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 6),
                Size = UDim2.new(1, -12, 0, 20),
                ZIndex = 12,
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
                    ZIndex = 13,
                    Parent = TabboxButtons,
                });
                Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Small), Parent = Button });
                local BtnStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 1, Thickness = 1, Parent = Button });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 6, 0, 30),
                    Size = UDim2.new(1, -12, 1, -34),
                    Visible = false,
                    ZIndex = 12,
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

        if Tab.Active then
            PillStroke.Transparency = 0.25;
            PillStroke.Color = Library.AccentColor;
            PillName.TextColor3 = Library.AccentColor;
            TabPill.BackgroundTransparency = 0;
        end

        Tab.TabPill = TabPill;
        Tab.ModWindow = ModWindow;

        Window.Tabs[Name] = Tab;
        Window.ModularWindows[Name] = ModWindow;
        return Tab;
    end

    -- Real-time web mesh update connection
    Library:GiveSignal(RenderStepped:Connect(function()
        WebManager:Update();
    end));

    function Library:Toggle(forceState)
        if forceState ~= nil then
            Library.Toggled = forceState;
        else
            Library.Toggled = not Library.Toggled;
        end
        Library:SetBlur(Library.Toggled);

        if TopDock then
            TopDock.Visible = Library.Toggled;
        end

        for name, modWin in next, Window.ModularWindows do
            local tab = Window.Tabs[name];
            if tab then
                modWin.Visible = Library.Toggled and tab.IsOpen;
            end
        end

        WebManager:Update();
    end

    -- Master Keybind Handler: Supports RightShift, RightControl, Insert, Library.ToggleKeybind, and Options.MenuKeybind
    local lastMenuToggle = 0;
    local function HandleMenuToggle(Input, Processed)
        if InputService:GetFocusedTextBox() ~= nil then
            return;
        end

        local isMenuKey = false;
        local keyName = Input.KeyCode and Input.KeyCode.Name;

        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if keyName == Library.ToggleKeybind.Value then
                isMenuKey = true;
            end
        elseif type(Library.ToggleKeybind) == 'string' then
            if keyName == Library.ToggleKeybind then
                isMenuKey = true;
            end
        end

        if not isMenuKey and Options and Options.MenuKeybind and Options.MenuKeybind.Value then
            if keyName == Options.MenuKeybind.Value then
                isMenuKey = true;
            end
        end

        if not isMenuKey then
            if Input.KeyCode == Enum.KeyCode.RightShift 
               or Input.KeyCode == Enum.KeyCode.RightControl 
               or Input.KeyCode == Enum.KeyCode.Insert then
                isMenuKey = true;
            end
        end

        if isMenuKey then
            if (tick() - lastMenuToggle) > 0.15 then
                lastMenuToggle = tick();
                task.spawn(function()
                    Library:Toggle();
                end);
            end
        end
    end

    Library:GiveSignal(InputService.InputBegan:Connect(HandleMenuToggle));

    if Window.AutoShow then
        Library:SetBlur(true);
    else
        Library.Toggled = false;
        TopDock.Visible = false;
        if BlurEffect then BlurEffect.Enabled = false; end
    end
    Window.Holder = TopDock;
    Library.Window = Window;
    return Window;
end

-- ====================================================================
-- MASTER EXTENSIONS: TargetHUD, MiniMap, DamageNumbers, WeatherEngine, MusicPlayer, Hitmarker & ScreenFlash
-- ====================================================================

-- 1. TARGET HUD
do
    local TargetHUD = {
        Frame = nil,
        Enabled = false,
        Target = nil,
        LastSeen = 0,
    };

    function TargetHUD:Init()
        if self.Frame then return end
        local Card = Library:Create('CanvasGroup', {
            Name = 'MikuTargetHUD',
            GroupTransparency = 1,
            Position = UDim2.fromOffset(400, 300),
            Size = UDim2.fromOffset(250, 78),
            BackgroundColor3 = Library.BackgroundColor,
            Visible = false,
            ZIndex = 500,
            Parent = ScreenGui,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Window), Parent = Card });
        local Stroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.1, Thickness = 1.5, Parent = Card });
        Library:AddToRegistry(Stroke, { Color = 'OutlineColor' });
        Library:AddToRegistry(Card, { BackgroundColor3 = 'BackgroundColor' });

        local AvatarBg = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            Position = UDim2.fromOffset(8, 8),
            Size = UDim2.fromOffset(46, 46),
            ZIndex = 501,
            Parent = Card,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = AvatarBg });

        local AvatarImg = Library:Create('ImageLabel', {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = '',
            ZIndex = 502,
            Parent = AvatarBg,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, RADIUS.Control), Parent = AvatarImg });

        local NameLabel = Library:CreateLabel({
            Position = UDim2.fromOffset(60, 6),
            Size = UDim2.new(1, -66, 0, 16),
            Text = 'Target Name',
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 502,
            Parent = Card,
        });

        local InfoLabel = Library:CreateLabel({
            Position = UDim2.fromOffset(60, 22),
            Size = UDim2.new(1, -66, 0, 14),
            Text = 'Distance: 0m | Rifle',
            TextColor3 = Library.DimColor,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 502,
            Parent = Card,
        });

        -- Health Track
        local HpTrack = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            Position = UDim2.fromOffset(60, 39),
            Size = UDim2.new(1, -68, 0, 12),
            ZIndex = 502,
            Parent = Card,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 3), Parent = HpTrack });

        local HpFill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 503,
            Parent = HpTrack,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 3), Parent = HpFill });
        Library:AddToRegistry(HpFill, { BackgroundColor3 = 'AccentColor' });

        local HpText = Library:CreateLabel({
            Size = UDim2.fromScale(1, 1),
            Text = '100 / 100 HP',
            TextSize = 10,
            TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 504,
            Parent = HpTrack,
        });

        -- Shield Track
        local ShieldTrack = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            Position = UDim2.fromOffset(60, 55),
            Size = UDim2.new(1, -68, 0, 8),
            ZIndex = 502,
            Parent = Card,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 2), Parent = ShieldTrack });

        local ShieldFill = Library:Create('Frame', {
            BackgroundColor3 = Color3.fromRGB(0, 220, 255),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 503,
            Parent = ShieldTrack,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 2), Parent = ShieldFill });

        Library:MakeDraggable(Card);

        self.Frame = Card;
        self.AvatarImg = AvatarImg;
        self.NameLabel = NameLabel;
        self.InfoLabel = InfoLabel;
        self.HpFill = HpFill;
        self.HpText = HpText;
        self.ShieldFill = ShieldFill;
    end

    function TargetHUD:Update(info)
        if not self.Enabled then
            if self.Frame and self.Frame.Visible then self.Frame.Visible = false; end
            return;
        end
        self:Init();
        if not info then
            if self.Frame.Visible and (tick() - self.LastSeen) > 1.5 then
                Tween(self.Frame, TI_SMOOTH, { GroupTransparency = 1 });
                task.delay(0.25, function()
                    if not self.Target then self.Frame.Visible = false; end
                end);
            end
            return;
        end

        self.LastSeen = tick();
        self.Target = info.Target;
        self.Frame.Visible = true;
        Tween(self.Frame, TI_FAST, { GroupTransparency = 0 });

        if info.UserId and info.UserId > 0 then
            self.AvatarImg.Image = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=100&height=100&format=png", info.UserId);
        end

        self.NameLabel.Text = tostring(info.Name or 'Target');
        local distStr = string.format("%.0fm", (info.Distance or 0) * 0.28);
        local wepStr = tostring(info.Weapon or 'Unknown');
        self.InfoLabel.Text = string.format("Distance: %s | %s", distStr, wepStr);

        local hp = math.max(0, tonumber(info.Health) or 100);
        local maxHp = math.max(1, tonumber(info.MaxHealth) or 100);
        local hpFrac = math.clamp(hp / maxHp, 0, 1);
        Tween(self.HpFill, TI_FAST, { Size = UDim2.new(hpFrac, 0, 1, 0) });
        self.HpText.Text = string.format("%d / %d HP", math.floor(hp), math.floor(maxHp));

        local shield = math.max(0, tonumber(info.Shield) or 0);
        local maxShield = math.max(1, tonumber(info.MaxShield) or 100);
        local shieldFrac = math.clamp(shield / maxShield, 0, 1);
        Tween(self.ShieldFill, TI_FAST, { Size = UDim2.new(shieldFrac, 0, 1, 0) });
    end

    Library.TargetHUD = TargetHUD;
    function Library:SetTargetHUD(info) TargetHUD:Update(info); end
    function Library:ToggleTargetHUD(bool)
        TargetHUD.Enabled = bool;
        if TargetHUD.Frame then TargetHUD.Frame.Visible = bool; end
    end
end

-- 2. MINI MAP (CoD Style Radar)
do
    local MiniMap = {
        Frame = nil,
        Enabled = false,
        BlipPool = {},
        ActiveBlips = 0,
        Range = 180,
    };

    function MiniMap:Init()
        if self.Frame then return end
        local MapOuter = Library:Create('CanvasGroup', {
            Name = 'MikuMiniMap',
            Position = UDim2.new(1, -210, 0, 70),
            Size = UDim2.fromOffset(160, 160),
            BackgroundColor3 = Library.BackgroundColor,
            Visible = false,
            ZIndex = 400,
            Parent = ScreenGui,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = MapOuter });
        local Stroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Transparency = 0.1, Thickness = 2, Parent = MapOuter });
        Library:AddToRegistry(Stroke, { Color = 'OutlineColor' });
        Library:AddToRegistry(MapOuter, { BackgroundColor3 = 'BackgroundColor' });

        -- Radar grid crosshairs
        local CrossH = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor,
            BackgroundTransparency = 0.6,
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 0, 1),
            ZIndex = 401,
            Parent = MapOuter,
        });
        local CrossV = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor,
            BackgroundTransparency = 0.6,
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(0, 1, 1, 0),
            ZIndex = 401,
            Parent = MapOuter,
        });

        -- Radar Sweep effect
        local Sweep = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ZIndex = 402,
            Parent = MapOuter,
        });
        local SweepGrad = Library:Create('UIGradient', {
            Color = ColorSequence.new(Library.AccentColor),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.6),
                NumberSequenceKeypoint.new(0.3, 0.95),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Rotation = 0,
            Parent = Sweep,
        });

        task.spawn(function()
            while MapOuter.Parent do
                SweepGrad.Rotation = (SweepGrad.Rotation + 3) % 360;
                task.wait(0.02);
            end
        end);

        -- Center Player Pointer
        local CenterBlip = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(12, 12),
            BackgroundTransparency = 1,
            Image = 'rbxassetid://4944686940',
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ZIndex = 410,
            Parent = MapOuter,
        });

        Library:MakeDraggable(MapOuter);

        self.Frame = MapOuter;
        self.CenterBlip = CenterBlip;
    end

    function MiniMap:GetBlip()
        self.ActiveBlips = self.ActiveBlips + 1;
        local blip = self.BlipPool[self.ActiveBlips];
        if not blip then
            blip = Library:Create('Frame', {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(6, 6),
                BorderSizePixel = 0,
                ZIndex = 405,
                Parent = self.Frame,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = blip });
            table.insert(self.BlipPool, blip);
        end
        blip.Visible = true;
        return blip;
    end

    function MiniMap:ResetBlips()
        for _, blip in ipairs(self.BlipPool) do blip.Visible = false; end
        self.ActiveBlips = 0;
    end

    function MiniMap:Update(myPos, myYaw, entities, currentTarget, zoom)
        if not self.Enabled then
            if self.Frame and self.Frame.Visible then self.Frame.Visible = false; end
            return;
        end
        self:Init();
        self.Frame.Visible = true;
        self:ResetBlips();

        local radarRadius = 72;
        local maxDist = zoom or self.Range or 180;
        self.CenterBlip.Rotation = -math.deg(myYaw or 0);

        for _, ent in ipairs(entities or {}) do
            local dx = ent.Pos.X - myPos.X;
            local dz = ent.Pos.Z - myPos.Z;

            -- Rotate relative to player yaw
            local cosY = math.cos(-myYaw);
            local sinY = math.sin(-myYaw);
            local rx = dx * cosY - dz * sinY;
            local rz = dx * sinY + dz * cosY;

            local dist = math.sqrt(rx * rx + rz * rz);
            local clampedDist = math.min(dist, maxDist);
            local scale = clampedDist / maxDist;

            local screenX = 80 + (rx / math.max(dist, 0.001)) * scale * radarRadius;
            local screenY = 80 + (rz / math.max(dist, 0.001)) * scale * radarRadius;

            local blip = self:GetBlip();
            blip.Position = UDim2.fromOffset(screenX, screenY);

            if ent.IsTarget or ent.Player == currentTarget then
                blip.Size = UDim2.fromOffset(8, 8);
                blip.BackgroundColor3 = Color3.fromRGB(255, 215, 0);
            elseif ent.IsTeammate then
                blip.Size = UDim2.fromOffset(5, 5);
                blip.BackgroundColor3 = Color3.fromRGB(0, 230, 115);
            else
                blip.Size = UDim2.fromOffset(6, 6);
                blip.BackgroundColor3 = Color3.fromRGB(255, 60, 80);
            end
        end
    end

    Library.MiniMap = MiniMap;
    function Library:UpdateMiniMap(myPos, myYaw, entities, currentTarget, zoom)
        MiniMap:Update(myPos, myYaw, entities, currentTarget, zoom);
    end
    function Library:ToggleMiniMap(bool)
        MiniMap.Enabled = bool;
        if MiniMap.Frame then MiniMap.Frame.Visible = bool; end
    end
end

-- 3. CUSTOM DAMAGE NUMBERS (3D Floating Popups)
do
    local DamageNumbers = {
        Enabled = true,
        Container = nil,
    };

    function DamageNumbers:Init()
        if self.Container then return end
        self.Container = Library:Create('Frame', {
            Name = 'MikuDamageContainer',
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 2000,
            Parent = ScreenGui,
        });
    end

    function DamageNumbers:Spawn(worldPos, damage, isCrit, isShield)
        if not self.Enabled then return end
        self:Init();
        local cam = workspace.CurrentCamera;
        if not cam then return end

        local screenPos, onScreen = cam:WorldToViewportPoint(worldPos);
        if not onScreen or screenPos.Z <= 0 then return end

        local randOffsetX = math.random(-16, 16);
        local randOffsetY = math.random(-8, 8);

        local startX = screenPos.X + randOffsetX;
        local startY = screenPos.Y + randOffsetY;

        local col = isCrit and Color3.fromRGB(255, 50, 80) or (isShield and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(255, 230, 100));
        local prefix = isCrit and "CRIT " or "";
        local text = prefix .. tostring(math.floor(damage));

        local Tag = Library:Create('TextLabel', {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(startX, startY),
            Size = UDim2.fromOffset(100, 24),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Font = Enum.Font.GothamBold,
            Text = text,
            TextColor3 = col,
            TextSize = isCrit and 18 or 14,
            TextStrokeTransparency = 0.2,
            TextStrokeColor3 = Color3.new(0, 0, 0),
            ZIndex = 2001,
            Parent = self.Container,
        });

        local Scale = Library:Create('UIScale', { Scale = 1.35, Parent = Tag });
        Tween(Scale, TI_POP, { Scale = 1 });

        local targetY = startY - math.random(35, 60);
        local targetX = startX + math.random(-20, 20);

        Tween(Tag, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.fromOffset(targetX, targetY),
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        });

        task.delay(0.85, function()
            Tag:Destroy();
        end);
    end

    Library.DamageNumbers = DamageNumbers;
    function Library:CreateDamageNumber(worldPos, damage, isCrit, isShield)
        DamageNumbers:Spawn(worldPos, damage, isCrit, isShield);
    end
    function Library:ToggleDamageNumbers(bool)
        DamageNumbers.Enabled = bool;
    end
end

-- 4. WEATHER PARTICLE ENGINE (Snow, Rain, Thunder, Sakura, Autumn, Cyber Sparks)
do
    local WeatherEngine = {
        Enabled = false,
        Canvas = nil,
        Type = 'Snow',
        Density = 60,
        Speed = 1,
        Wind = 0.5,
        Particles = {},
    };

    function WeatherEngine:Init()
        if self.Canvas then return end
        self.Canvas = Library:Create('Frame', {
            Name = 'MikuWeatherCanvas',
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ClipsDescendants = true,
            ZIndex = 1,
            Parent = ScreenGui,
        });

        Library:GiveSignal(RenderStepped:Connect(function(dt)
            if not self.Enabled then return end
            self:Update(dt);
        end));
    end

    function WeatherEngine:SetWeather(wType, density, speed, wind)
        self.Type = wType or 'Snow';
        self.Density = math.clamp(density or 60, 10, 150);
        self.Speed = speed or 1;
        self.Wind = wind or 0.5;
        self:Rebuild();
    end

    function WeatherEngine:Rebuild()
        for _, p in ipairs(self.Particles) do p.Inst:Destroy(); end
        self.Particles = {};
        if not self.Enabled then return end
        self:Init();

        local cam = workspace.CurrentCamera;
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080);

        for i = 1, self.Density do
            local inst = Library:Create('Frame', {
                BorderSizePixel = 0,
                ZIndex = 1,
                Parent = self.Canvas,
            });

            local pData = {
                Inst = inst,
                X = math.random(0, vp.X),
                Y = math.random(-50, vp.Y),
                VelX = (math.random() - 0.5) * 20 + self.Wind * 40,
                VelY = math.random(80, 180) * self.Speed,
                Size = math.random(3, 6),
                Rot = math.random(0, 360),
                RotSpeed = (math.random() - 0.5) * 120,
                Phase = math.random() * math.pi * 2,
            };

            if self.Type == 'Snow' then
                inst.BackgroundColor3 = Color3.fromRGB(240, 245, 255);
                inst.BackgroundTransparency = math.random(2, 6) / 10;
                inst.Size = UDim2.fromOffset(pData.Size, pData.Size);
                Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = inst });
            elseif self.Type == 'Rain' then
                inst.BackgroundColor3 = Color3.fromRGB(180, 215, 255);
                inst.BackgroundTransparency = 0.5;
                inst.Size = UDim2.fromOffset(2, math.random(12, 22));
                pData.VelY = math.random(400, 650) * self.Speed;
                pData.VelX = self.Wind * 80;
            elseif self.Type == 'Sakura' then
                inst.BackgroundColor3 = Color3.fromRGB(255, 180, 205);
                inst.BackgroundTransparency = 0.3;
                inst.Size = UDim2.fromOffset(math.random(6, 10), math.random(4, 7));
                Library:Create('UICorner', { CornerRadius = UDim.new(0.5, 0), Parent = inst });
            elseif self.Type == 'Autumn' then
                local hues = { Color3.fromRGB(235, 130, 40), Color3.fromRGB(215, 80, 40), Color3.fromRGB(240, 190, 45) };
                inst.BackgroundColor3 = hues[math.random(1, #hues)];
                inst.BackgroundTransparency = 0.25;
                inst.Size = UDim2.fromOffset(math.random(7, 12), math.random(5, 9));
                Library:Create('UICorner', { CornerRadius = UDim.new(0.4, 0), Parent = inst });
            elseif self.Type == 'Cyber Sparks' then
                inst.BackgroundColor3 = Library.AccentColor;
                inst.BackgroundTransparency = 0.2;
                inst.Size = UDim2.fromOffset(math.random(2, 4), math.random(2, 4));
                pData.VelY = -math.random(60, 140) * self.Speed;
                Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = inst });
            end

            table.insert(self.Particles, pData);
        end
    end

    local thunderTimer = 0;
    function WeatherEngine:Update(dt)
        local cam = workspace.CurrentCamera;
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080);

        -- Thunder flash effect
        if self.Type == 'Thunder' or self.Type == 'Rain' then
            thunderTimer = thunderTimer + dt;
            if thunderTimer > math.random(8, 16) then
                thunderTimer = 0;
                Library:PlayScreenFlash(Color3.fromRGB(220, 235, 255), 0.45, 0.25);
            end
        end

        local timeSec = tick();
        for _, p in ipairs(self.Particles) do
            local drift = math.sin(timeSec * 1.5 + p.Phase) * 15;
            p.X = p.X + (p.VelX + drift) * dt;
            p.Y = p.Y + p.VelY * dt;
            p.Rot = p.Rot + p.RotSpeed * dt;

            if p.Y > vp.Y + 20 then
                p.Y = -20;
                p.X = math.random(0, vp.X);
            elseif p.Y < -30 then
                p.Y = vp.Y + 10;
                p.X = math.random(0, vp.X);
            end

            if p.X > vp.X + 20 then p.X = -20;
            elseif p.X < -20 then p.X = vp.X + 20; end

            p.Inst.Position = UDim2.fromOffset(p.X, p.Y);
            if p.RotSpeed ~= 0 then p.Inst.Rotation = p.Rot; end
        end
    end

    Library.Weather = WeatherEngine;
    function Library:SetWeather(wType, density, speed, wind)
        WeatherEngine:SetWeather(wType, density, speed, wind);
    end
    function Library:ToggleWeather(bool)
        WeatherEngine.Enabled = bool;
        if WeatherEngine.Canvas then WeatherEngine.Canvas.Visible = bool; end
        WeatherEngine:Rebuild();
    end
end

-- 5. BUILT-IN CYBER MUSIC PLAYER
do
    local MusicPlayer = {
        Sound = nil,
        Playing = false,
        CurrentTrack = 1,
        Volume = 0.5,
        Pitch = 1,
        Loop = true,
        Tracks = {
            { Name = "Cyberpunk Phonk", Id = "rbxassetid://9043887091" },
            { Name = "Synthwave Neon",  Id = "rbxassetid://1837849285" },
            { Name = "Lofi Chill Beats", Id = "rbxassetid://9048375035" },
            { Name = "Hyperpop Drift",  Id = "rbxassetid://6998634863" },
            { Name = "Anime Nightcore", Id = "rbxassetid://1843404009" },
        },
    };

    function MusicPlayer:Init()
        if self.Sound then return end
        local snd = Instance.new("Sound");
        snd.Name = "MikuMusicStream";
        snd.Volume = self.Volume;
        snd.PlaybackSpeed = self.Pitch;
        snd.Looped = self.Loop;
        snd.Parent = ScreenGui;
        self.Sound = snd;
    end

    function MusicPlayer:Play(customId)
        self:Init();
        local id = customId or (self.Tracks[self.CurrentTrack] and self.Tracks[self.CurrentTrack].Id);
        if not id or id == "" then return end
        self.Sound.SoundId = tostring(id);
        self.Sound.Volume = self.Volume;
        self.Sound.PlaybackSpeed = self.Pitch;
        self.Sound.Looped = self.Loop;
        self.Sound:Play();
        self.Playing = true;
    end

    function MusicPlayer:Pause()
        if self.Sound then self.Sound:Pause(); end
        self.Playing = false;
    end

    function MusicPlayer:Stop()
        if self.Sound then self.Sound:Stop(); end
        self.Playing = false;
    end

    function MusicPlayer:Next()
        self.CurrentTrack = (self.CurrentTrack % #self.Tracks) + 1;
        if self.Playing then self:Play(); end
    end

    function MusicPlayer:Prev()
        self.CurrentTrack = ((self.CurrentTrack - 2 + #self.Tracks) % #self.Tracks) + 1;
        if self.Playing then self:Play(); end
    end

    function MusicPlayer:SetVolume(vol)
        self.Volume = math.clamp(vol or 0.5, 0, 1);
        if self.Sound then self.Sound.Volume = self.Volume; end
    end

    function MusicPlayer:SetPitch(pitch)
        self.Pitch = math.clamp(pitch or 1, 0.5, 2.0);
        if self.Sound then self.Sound.PlaybackSpeed = self.Pitch; end
    end

    Library.MusicPlayer = MusicPlayer;
    function Library:PlayMusic(id) MusicPlayer:Play(id); end
    function Library:StopMusic() MusicPlayer:Stop(); end
end

-- 6. CUSTOM HITMARKER & SCREEN FLASH SYSTEM
do
    local HitmarkerFrame = nil;
    local FlashFrame = nil;

    function Library:PlayScreenFlash(color, intensity, duration)
        if not FlashFrame then
            FlashFrame = Library:Create('Frame', {
                Name = 'MikuScreenFlash',
                BackgroundColor3 = color or Color3.fromRGB(255, 50, 80),
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 9999,
                Parent = ScreenGui,
            });
        end
        FlashFrame.BackgroundColor3 = color or Color3.fromRGB(255, 50, 80);
        FlashFrame.BackgroundTransparency = 1 - (intensity or 0.4);
        Tween(FlashFrame, TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 1,
        });
    end

    function Library:PlayHitmarker(isHeadshot, style, customSoundId, vol, pitch)
        local center = workspace.CurrentCamera and (workspace.CurrentCamera.ViewportSize * 0.5) or Vector2.new(960, 540);
        local col = isHeadshot and Color3.fromRGB(255, 50, 80) or Color3.fromRGB(255, 255, 255);

        local Marker = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(center.X, center.Y),
            Size = UDim2.fromOffset(24, 24),
            BackgroundTransparency = 1,
            ZIndex = 8000,
            Parent = ScreenGui,
        });

        -- Cross lines
        local L1 = Library:Create('Frame', { BackgroundColor3 = col, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 2), Rotation = 45, Parent = Marker });
        local L2 = Library:Create('Frame', { BackgroundColor3 = col, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 2), Rotation = -45, Parent = Marker });

        local Scale = Library:Create('UIScale', { Scale = 0.6, Parent = Marker });
        Tween(Scale, TI_POP, { Scale = 1.25 });
        Tween(L1, TweenInfo.new(0.22), { BackgroundTransparency = 1 });
        Tween(L2, TweenInfo.new(0.22), { BackgroundTransparency = 1 });

        task.delay(0.25, function() Marker:Destroy(); end);

        if customSoundId and customSoundId ~= "" then
            local s = Instance.new("Sound");
            s.SoundId = tostring(customSoundId);
            s.Volume = vol or 1;
            s.PlaybackSpeed = pitch or (isHeadshot and 1.2 or 1);
            s.Parent = ScreenGui;
            s:Play();
            s.Ended:Connect(function() s:Destroy(); end);
        end
    end
end

-- 7. CUSTOM BACKGROUND & UI GLOW
do
    local CustomBgImage = nil;
    function Library:SetCustomBackground(imageId, trans, scaleType)
        if not imageId or imageId == "" then
            if CustomBgImage then CustomBgImage.Visible = false; end
            return;
        end
        if not CustomBgImage then
            CustomBgImage = Library:Create('ImageLabel', {
                Name = 'MikuCustomUIBackground',
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                ScaleType = Enum.ScaleType.Crop,
                ZIndex = 0,
                Parent = ScreenGui,
            });
        end
        CustomBgImage.Image = tostring(imageId);
        CustomBgImage.ImageTransparency = math.clamp(trans or 0.65, 0, 1);
        if scaleType == 'Fit' then CustomBgImage.ScaleType = Enum.ScaleType.Fit;
        elseif scaleType == 'Stretch' then CustomBgImage.ScaleType = Enum.ScaleType.Stretch;
        else CustomBgImage.ScaleType = Enum.ScaleType.Crop; end
        CustomBgImage.Visible = true;
    end
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
