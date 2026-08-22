local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService');
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};
    HudRegistry = {};

    FontColor = Color3.fromRGB(240, 240, 245);
    MainColor = Color3.fromRGB(24, 24, 28);
    BackgroundColor = Color3.fromRGB(16, 16, 20);
    AccentColor = Color3.fromRGB(0, 210, 255);
    OutlineColor = Color3.fromRGB(42, 44, 52);
    RiskColor = Color3.fromRGB(255, 65, 85);

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.GothamMedium;

    OpenedFrames = {};
    DependencyBoxes = {};
    Signals = {};
    ScreenGui = ScreenGui;
    Toggled = false;
};

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
    if not Library.NotifyOnError then
        return f(...);
    end
    local success, event = pcall(f, ...);
    if not success then
        local _, i = event:find(":%d+: ");
        if not i then
            return Library:Notify(tostring(event));
        end
        return Library:Notify(event:sub(i + 1), 3);
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

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        Transparency = 0.5;
        LineJoinMode = Enum.LineJoinMode.Round;
        Parent = Inst;
    });
end

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 14;
        TextStrokeTransparency = 1;
    });

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;
    local dragging = false;
    local dragInput, dragStart, startPos;

    Instance.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local mousePos = Vector2.new(input.Position.X, input.Position.Y);
            local objPos = Instance.AbsolutePosition;
            if (mousePos.Y - objPos.Y) <= (Cutoff or 40) then
                dragging = true;
                dragStart = input.Position;
                startPos = Instance.Position;

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false;
                    end
                end)
            end
        end
    end)

    Instance.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input;
        end
    end)

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
    end)
end

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 13);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        Size = UDim2.fromOffset(X + 12, Y + 8),
        ZIndex = 1000,
        Visible = false,
        Parent = Library.ScreenGui,
    });

    Library:Create('UICorner', {
        CornerRadius = UDim.new(0, 4),
        Parent = Tooltip,
    });

    Library:Create('UIStroke', {
        Color = Library.OutlineColor,
        Thickness = 1,
        Parent = Tooltip,
    });

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(6, 4),
        Size = UDim2.fromOffset(X, Y),
        TextSize = 13,
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Tooltip.ZIndex + 1,
        Parent = Tooltip,
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false;

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true;
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12);
        Tooltip.Visible = true;

        while IsHovering do
            RunService.Heartbeat:Wait();
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12);
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
            Tween(TargetInstance, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [Property] = col });
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end
        end
    end);

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[TargetInstance];
        for Property, ColorIdx in next, PropertiesDefault do
            local col = Library[ColorIdx] or ColorIdx;
            Tween(TargetInstance, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [Property] = col });
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end
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
        if Depbox and Depbox.Update then
            Depbox:Update();
        end
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
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };
    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;
    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end
end

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end
        end
        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end
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
    if Library.OnUnload then
        pcall(Library.OnUnload);
    end
    ScreenGui:Destroy();
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback;
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end
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

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            Size = UDim2.new(0, 24, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        Library:Create('UICorner', {
            CornerRadius = UDim.new(0, 4),
            Parent = DisplayFrame,
        });

        local DisplayStroke = Library:Create('UIStroke', {
            Color = Library:GetDarkerColor(ColorPicker.Value),
            Thickness = 1,
            Parent = DisplayFrame,
        });

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Library.BackgroundColor;
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 20),
            Size = UDim2.fromOffset(230, Info.Transparency and 275 or 255);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        Library:Create('UICorner', {
            CornerRadius = UDim.new(0, 6),
            Parent = PickerFrameOuter,
        });

        Library:Create('UIStroke', {
            Color = Library.OutlineColor,
            Thickness = 1,
            Parent = PickerFrameOuter,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 20);
        end)

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 2),
            ZIndex = 17,
            Parent = PickerFrameOuter,
        });

        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });

        local SatVibMapOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            Position = UDim2.new(0, 8, 0, 25),
            Size = UDim2.new(0, 192, 0, 192),
            ZIndex = 17,
            Parent = PickerFrameOuter,
        });

        Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = SatVibMapOuter });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapOuter;
        });

        Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = SatVibMap });

        local CursorOuter = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 8, 0, 8);
            BackgroundColor3 = Color3.new(1, 1, 1);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = CursorOuter });
        Library:Create('UIStroke', { Color = Color3.new(0, 0, 0), Thickness = 1, Parent = CursorOuter });

        local HueSelectorOuter = Library:Create('Frame', {
            Position = UDim2.new(0, 206, 0, 25);
            Size = UDim2.new(0, 16, 0, 192);
            ZIndex = 17;
            Parent = PickerFrameOuter;
        });

        Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = HueSelectorOuter });

        local HueSelectorInner = Library:Create('Frame', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = HueSelectorInner });

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 19;
            Parent = HueSelectorInner;
        });
        Library:Create('UIStroke', { Color = Color3.new(0, 0, 0), Thickness = 1, Parent = HueCursor });

        local HueBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            Position = UDim2.fromOffset(8, 224),
            Size = UDim2.new(0.5, -12, 0, 22),
            ZIndex = 18,
            Parent = PickerFrameOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = HueBoxOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = HueBoxOuter });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 6, 0, 0);
            Size = UDim2.new(1, -12, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(150, 150, 160);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 13;
            TextStrokeTransparency = 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxOuter;
        });

        local RgbBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            Position = UDim2.new(0.5, 4, 0, 224),
            Size = UDim2.new(0.5, -12, 0, 22),
            ZIndex = 18,
            Parent = PickerFrameOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = RgbBoxOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = RgbBoxOuter });

        local RgbBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 6, 0, 0);
            Size = UDim2.new(1, -12, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(150, 150, 160);
            PlaceholderText = 'RGB color',
            Text = '255, 255, 255',
            TextColor3 = Library.FontColor;
            TextSize = 13;
            TextStrokeTransparency = 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = RgbBoxOuter;
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, -16, 0, 18);
            Position = UDim2.fromOffset(8, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 13;
            Text = ColorPicker.Title;
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local ContextMenu = { Options = {} };
        do
            ContextMenu.Container = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                ZIndex = 30,
                Visible = false,
                Parent = ScreenGui
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = ContextMenu.Container });
            Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = ContextMenu.Container });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = ContextMenu.Container,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 6,
                    DisplayFrame.AbsolutePosition.Y
                );
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition);
            task.spawn(updateMenuPosition);

            function ContextMenu:Show() self.Container.Visible = true; end
            function ContextMenu:Hide() self.Container.Visible = false; end

            function ContextMenu:AddOption(Str, Callback)
                Callback = Callback or function() end;
                local Btn = Library:Create('TextButton', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    TextSize = 12,
                    Font = Library.Font,
                    Text = '  ' .. Str,
                    TextColor3 = Library.FontColor,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 31,
                    Parent = ContextMenu.Container,
                });
                Btn.MouseEnter:Connect(function()
                    Tween(Btn, TweenInfo.new(0.15), { TextColor3 = Library.AccentColor });
                end);
                Btn.MouseLeave:Connect(function()
                    Tween(Btn, TweenInfo.new(0.15), { TextColor3 = Library.FontColor });
                end);
                Btn.MouseButton1Click:Connect(function()
                    ContextMenu:Hide();
                    Callback();
                end);
                ContextMenu.Container.Size = UDim2.fromOffset(120, #ContextMenu.Container:GetChildren() * 20);
            end

            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, '#' .. ColorPicker.Value:ToHex());
                Library:Notify('Copied HEX code to clipboard!', 2);
            end);
            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '));
                Library:Notify('Copied RGB values to clipboard!', 2);
            end);
        end

        local SequenceTable = {};
        for H = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(H, Color3.fromHSV(H, 1, 1)));
        end

        Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text);
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result);
                end
            end
            ColorPicker:Display();
        end);

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)');
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b));
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
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ');

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value);
        end

        function ColorPicker:Show()
            for Frame, _ in next, Library.OpenedFrames do
                if Frame and Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end
            end
            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end

        function ColorPicker:SetValue(HSV, Transparency)
            if typeof(HSV) == 'Color3' then
                ColorPicker:SetValueRGB(HSV, Transparency);
                return;
            elseif type(HSV) == 'string' then
                local success, col = pcall(Color3.fromHex, HSV);
                if success and typeof(col) == 'Color3' then
                    ColorPicker:SetValueRGB(col, Transparency);
                    return;
                end
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
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();
                    RenderStepped:Wait();
                end
                Library:AttemptSave();
            end
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();
                    RenderStepped:Wait();
                end
                Library:AttemptSave();
            end
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide();
                else
                    ContextMenu:Hide();
                    ColorPicker:Show();
                end
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show();
                ColorPicker:Hide();
            end
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < AbsPos.Y or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    ColorPicker:Hide();
                end
                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide();
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

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' };
            Info.Mode = 'Toggle';
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(0, 32, 0, 16);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = PickOuter });
        local PickStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = PickOuter });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 12;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickOuter;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 6, ToggleLabel.AbsolutePosition.Y);
            Size = UDim2.new(0, 68, 0, 54);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });

        Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = ModeSelectOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = ModeSelectOuter });

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 6, ToggleLabel.AbsolutePosition.Y);
        end);

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectOuter;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        }, true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for _, Mode in next, Modes do
            local ModeButton = {};
            local Btn = Library:Create('TextButton', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 18);
                Font = Library.Font;
                TextSize = 12;
                Text = Mode;
                TextColor3 = Library.FontColor;
                ZIndex = 16;
                Parent = ModeSelectOuter;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do Button:Deselect(); end
                KeyPicker.Mode = Mode;
                Btn.TextColor3 = Library.AccentColor;
                ModeSelectOuter.Visible = false;
            end

            function ModeButton:Deselect()
                Btn.TextColor3 = Library.FontColor;
            end

            Btn.MouseButton1Click:Connect(function()
                ModeButton:Select();
                Library:AttemptSave();
            end);

            if Mode == KeyPicker.Mode then ModeButton:Select(); end
            ModeButtons[Mode] = ModeButton;
        end

        function KeyPicker:Update()
            if Info.NoUI then return end
            local State = KeyPicker:GetState();
            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text or 'Keybind', KeyPicker.Mode);
            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;
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
            KeyPicker:Update();
        end

        function KeyPicker:OnClick(Callback) KeyPicker.Clicked = Callback; end
        function KeyPicker:OnChanged(Callback) KeyPicker.Changed = Callback; Callback(KeyPicker.Value); end

        if ParentObj.Addons then table.insert(ParentObj.Addons, KeyPicker); end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value);
            end
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled);
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled);
        end

        local Picking = false;
        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;
                DisplayLabel.Text = '...';
                Tween(PickStroke, TweenInfo.new(0.2), { Color = Library.AccentColor });

                local Event;
                Event = InputService.InputBegan:Connect(function(KeyInput)
                    local Key;
                    if KeyInput.UserInputType == Enum.UserInputType.Keyboard then
                        Key = KeyInput.KeyCode.Name;
                    elseif KeyInput.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif KeyInput.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    end
                    Picking = false;
                    Tween(PickStroke, TweenInfo.new(0.2), { Color = Library.OutlineColor });
                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;
                    Library:SafeCallback(KeyPicker.ChangedCallback, KeyInput.KeyCode or KeyInput.UserInputType);
                    Library:SafeCallback(KeyPicker.Changed, KeyInput.KeyCode or KeyInput.UserInputType);
                    Library:AttemptSave();
                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = not ModeSelectOuter.Visible;
            end
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if not Picking then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;
                    if (Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1)
                        or (Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2)
                        or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key) then
                        KeyPicker.Toggled = not KeyPicker.Toggled;
                        KeyPicker:DoClick();
                    end
                end
                KeyPicker:Update();
            end
        end));

        KeyPicker:Update();
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
            Text = Text;
            TextWrapped = DoesWrap or false;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 13, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)));
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
            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end
        ProcessButtonParams(Button, ...);

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(BtnObj)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                Size = UDim2.new(1, -8, 0, 24);
                ZIndex = 5;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 5), Parent = Outer });
            local Stroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = Outer });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 13;
                Text = BtnObj.Text;
                ZIndex = 6;
                Parent = Outer;
            });

            Outer.MouseEnter:Connect(function()
                Tween(Stroke, TweenInfo.new(0.2), { Color = Library.AccentColor });
                Tween(Outer, TweenInfo.new(0.2), { BackgroundColor3 = Library.BackgroundColor });
            end);
            Outer.MouseLeave:Connect(function()
                Tween(Stroke, TweenInfo.new(0.2), { Color = Library.OutlineColor });
                Tween(Outer, TweenInfo.new(0.2), { BackgroundColor3 = Library.MainColor });
            end);

            return Outer, Label, Stroke;
        end

        local function InitEvents(BtnObj)
            BtnObj.Outer.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                    Tween(BtnObj.Outer, TweenInfo.new(0.08), { Size = UDim2.new(1, -12, 0, 22) });
                end
            end);
            BtnObj.Outer.InputEnded:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Tween(BtnObj.Outer, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(1, -8, 0, 24) });
                    if not Library:MouseIsOverOpenedFrame() then
                        Library:SafeCallback(BtnObj.Func);
                    end
                end
            end);
        end

        Button.Outer, Button.Label, Button.Stroke = CreateBaseButton(Button);
        Button.Outer.Parent = Container;
        InitEvents(Button);

        if type(Button.Tooltip) == 'string' then
            Library:AddToolTip(Button.Tooltip, Button.Outer);
        end

        Groupbox:AddBlank(4);
        Groupbox:Resize();
        return Button;
    end

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Divider = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -8, 0, 1);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(Divider, { BackgroundColor3 = 'OutlineColor' });
        Groupbox:AddBlank(6);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.');
        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:CreateLabel({
            Size = UDim2.new(1, -8, 0, 14);
            TextSize = 13;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(2);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, -8, 0, 24);
            ZIndex = 5;
            Parent = Container;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 5), Parent = TextBoxOuter });
        local BoxStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = TextBoxOuter });

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -16, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(130, 130, 145);
            PlaceholderText = Info.Placeholder or 'Type here...';
            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 13;
            TextStrokeTransparency = 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 7;
            Parent = TextBoxOuter;
        });

        Box.Focused:Connect(function()
            Tween(BoxStroke, TweenInfo.new(0.2), { Color = Library.AccentColor });
        end);
        Box.FocusLost:Connect(function()
            Tween(BoxStroke, TweenInfo.new(0.2), { Color = Library.OutlineColor });
        end);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end
            if Textbox.Numeric and (not tonumber(Text)) and Text:len() > 0 then
                Text = Textbox.Value;
            end
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
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end

        Groupbox:AddBlank(4);
        Groupbox:Resize();
        Options[Idx] = Textbox;
        return Textbox;
    end

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing `Text` string.');
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
            ZIndex = 5;
            Parent = Container;
        });

        local SwitchTrack = Library:Create('Frame', {
            BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.OutlineColor;
            Position = UDim2.new(0, 0, 0.5, -8);
            Size = UDim2.new(0, 30, 0, 16);
            ZIndex = 6;
            Parent = ToggleRow;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = SwitchTrack });

        local SwitchThumb = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            Position = Toggle.Value and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6);
            Size = UDim2.new(0, 12, 0, 12);
            ZIndex = 7;
            Parent = SwitchTrack;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = SwitchThumb });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(1, -38, 1, 0);
            Position = UDim2.new(0, 38, 0, 0);
            TextSize = 13;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
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
            Size = UDim2.new(1, 0, 1, 0);
            Text = '';
            ZIndex = 8;
            Parent = ToggleRow;
        });

        function Toggle:Display()
            local targetCol = Toggle.Value and Library.AccentColor or Library.OutlineColor;
            local targetPos = Toggle.Value and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6);
            Tween(SwitchTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = targetCol });
            Tween(SwitchThumb, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos });
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);
            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool;
                    Addon:Update();
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

        if Toggle.Risky then
            ToggleLabel.TextColor3 = Library.RiskColor;
        end

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
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding or 0;
            MaxSize = 220;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local HeaderFrame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, -8, 0, 14);
            ZIndex = 5;
            Parent = Container;
        });

        local SliderLabel = Library:CreateLabel({
            Size = UDim2.new(0.65, 0, 1, 0);
            TextSize = 13;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = HeaderFrame;
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(0.35, 0, 1, 0);
            Position = UDim2.new(0.65, 0, 0, 0);
            TextSize = 13;
            Text = tostring(Slider.Value);
            TextColor3 = Library.AccentColor;
            TextXAlignment = Enum.TextXAlignment.Right;
            ZIndex = 5;
            Parent = HeaderFrame;
        });

        Groupbox:AddBlank(3);

        local Track = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, -8, 0, 8);
            ZIndex = 5;
            Parent = Container;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Track });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = Track });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 6;
            Parent = Track;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Fill });

        local Knob = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundColor3 = Color3.new(1, 1, 1);
            Position = UDim2.new(1, 0, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            ZIndex = 7;
            Parent = Fill;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = Knob });
        Library:Create('UIStroke', { Color = Library.AccentColor, Thickness = 2, Parent = Knob });

        function Slider:Display()
            local Suffix = Info.Suffix or '';
            DisplayLabel.Text = string.format('%s%s', tostring(Slider.Value), Suffix);

            local fraction = math.clamp((Slider.Value - Slider.Min) / (Slider.Max - Slider.Min), 0, 1);
            Tween(Fill, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(fraction, 0, 1, 0) });
        end

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end

        local function Round(Value)
            if Slider.Rounding == 0 then return math.floor(Value); end
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value));
        end

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
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {} or Info.Default;
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
                ZIndex = 5;
                Parent = Container;
            });
            Groupbox:AddBlank(2);
        end

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, -8, 0, 24);
            ZIndex = 5;
            Parent = Container;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 5), Parent = DropdownOuter });
        local DropStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = DropdownOuter });

        local ItemLabel = Library:CreateLabel({
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -30, 1, 0);
            TextSize = 13;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        local Arrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -20, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ImageColor3 = Library.FontColor;
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.fromOffset(200, 120);
            Visible = false;
            ZIndex = 50;
            Parent = ScreenGui;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 5), Parent = ListOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = ListOuter });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ScrollBarThickness = 3;
            ScrollBarImageColor3 = Library.AccentColor;
            ZIndex = 51;
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
                    BackgroundColor3 = Library.MainColor;
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, -4, 0, 22);
                    Position = UDim2.new(0, 2, 0, 0);
                    Font = Library.Font;
                    Text = '  ' .. tostring(val);
                    TextColor3 = Library.FontColor;
                    TextSize = 13;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 52;
                    Parent = Scrolling;
                });
                Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = Btn });

                Btn.MouseEnter:Connect(function()
                    Tween(Btn, TweenInfo.new(0.15), { BackgroundTransparency = 0, TextColor3 = Library.AccentColor });
                end);
                Btn.MouseLeave:Connect(function()
                    local isSelected = Info.Multi and Dropdown.Value[val] or (Dropdown.Value == val);
                    Tween(Btn, TweenInfo.new(0.15), { BackgroundTransparency = isSelected and 0.5 or 1, TextColor3 = isSelected and Library.AccentColor or Library.FontColor });
                end);

                Btn.MouseButton1Click:Connect(function()
                    if Info.Multi then
                        Dropdown.Value[val] = not Dropdown.Value[val];
                    else
                        Dropdown.Value = val;
                        Dropdown:Close();
                    end
                    Dropdown:Display();
                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                    Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
                    Library:AttemptSave();
                end);
            end
            RecalculateListPosition();
        end

        function Dropdown:Open()
            Dropdown:BuildDropdownList();
            RecalculateListPosition();
            ListOuter.Visible = true;
            Tween(Arrow, TweenInfo.new(0.2), { Rotation = 180 });
            Tween(DropStroke, TweenInfo.new(0.2), { Color = Library.AccentColor });
            Library.OpenedFrames[ListOuter] = true;
        end

        function Dropdown:Close()
            ListOuter.Visible = false;
            Tween(Arrow, TweenInfo.new(0.2), { Rotation = 0 });
            Tween(DropStroke, TweenInfo.new(0.2), { Color = Library.OutlineColor });
            Library.OpenedFrames[ListOuter] = nil;
        end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then Dropdown:Close(); else Dropdown:Open(); end
            end
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and ListOuter.Visible then
                if not Library:IsMouseOverFrame(ListOuter) and not Library:IsMouseOverFrame(DropdownOuter) then
                    Dropdown:Close();
                end
            end
        end));

        function Dropdown:SetValue(Val)
            Dropdown.Value = Val;
            Dropdown:Display();
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end

        function Dropdown:SetValues(NewValues)
            Dropdown.Values = NewValues;
            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end

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

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            local Size = 0;
            for _, Element in next, Frame:GetChildren() do
                if not Element:IsA('UIListLayout') and Element.Visible then
                    Size = Size + Element.Size.Y.Offset;
                end
            end
            Holder.Size = UDim2.new(1, 0, 0, Size);
            Groupbox:Resize();
        end

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Expected = Dependency[2];
                if Elem.Value ~= Expected then
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
        ZIndex = 1000;
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
        Position = UDim2.new(0, 20, 0, 20);
        Size = UDim2.new(0, 180, 0, 26);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6), Parent = WatermarkOuter });
    Library:Create('UIStroke', { Color = Library.AccentColor, Thickness = 1, Parent = WatermarkOuter });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 8, 0, 0);
        Size = UDim2.new(1, -16, 1, 0);
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
        Position = UDim2.new(0, 20, 0.5, 0);
        Size = UDim2.new(0, 200, 0, 24);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6), Parent = KeybindOuter });
    Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = KeybindOuter });

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, -16, 0, 24);
        Position = UDim2.fromOffset(8, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = 'Keybinds',
        TextSize = 13,
        ZIndex = 104,
        Parent = KeybindOuter;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, -16, 1, -24);
        Position = UDim2.new(0, 8, 0, 24);
        ZIndex = 101;
        Parent = KeybindOuter;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 13);
    Library.Watermark.Size = UDim2.new(0, X + 20, 0, 26);
    Library.WatermarkText.Text = Text;
    Library:SetWatermarkVisibility(true);
end

function Library:Notify(Text, Time)
    Time = Time or 4;
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 13);
    local NotifyCard = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        Size = UDim2.new(1, 0, 0, math.max(YSize + 16, 32)),
        BackgroundTransparency = 1,
        ZIndex = 1001,
        Parent = Library.NotificationArea,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6), Parent = NotifyCard });
    local Stroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Transparency = 1, Parent = NotifyCard });

    local LeftBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0),
        ZIndex = 1002,
        Parent = NotifyCard,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 2), Parent = LeftBar });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -20, 1, 0),
        Text = Text,
        TextSize = 13,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1002,
        Parent = NotifyCard,
    });

    Tween(NotifyCard, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 });
    Tween(Stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0 });
    Tween(NotifyLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 });

    task.delay(Time, function()
        Tween(NotifyCard, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 });
        Tween(Stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 });
        Tween(NotifyLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 });
        task.wait(0.35);
        NotifyCard:Destroy();
    end);
end

function Library:Loader(Info)
    Info = Info or {};
    local Name = Info.Name or 'MIKU';
    local Duration = Info.Duration or 2;

    local LoaderGui = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(260, 120),
        BackgroundColor3 = Library.BackgroundColor,
        ZIndex = 2000,
        Parent = ScreenGui,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 10), Parent = LoaderGui });
    Library:Create('UIStroke', { Color = Library.AccentColor, Thickness = 1.5, Parent = LoaderGui });

    local TitleLabel = Library:CreateLabel({
        Position = UDim2.new(0, 0, 0, 20),
        Size = UDim2.new(1, 0, 0, 28),
        Text = Name,
        TextColor3 = Library.AccentColor,
        TextSize = 22,
        ZIndex = 2001,
        Parent = LoaderGui,
    });

    local ProgressTrack = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        Position = UDim2.new(0, 20, 0, 70),
        Size = UDim2.new(1, -40, 0, 6),
        ZIndex = 2001,
        Parent = LoaderGui,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = ProgressTrack });

    local ProgressBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 2002,
        Parent = ProgressTrack,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = ProgressBar });

    Tween(ProgressBar, TweenInfo.new(Duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) });

    task.delay(Duration + 0.3, function()
        Tween(LoaderGui, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 });
        Tween(TitleLabel, TweenInfo.new(0.4), { TextTransparency = 1 });
        Tween(ProgressBar, TweenInfo.new(0.4), { BackgroundTransparency = 1 });
        Tween(ProgressTrack, TweenInfo.new(0.4), { BackgroundTransparency = 1 });
        task.wait(0.45);
        LoaderGui:Destroy();
    end);
end

function Library:CreateWindow(...)
    local Arguments = { ... };
    local Config = { AnchorPoint = Vector2.zero };

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1];
        Config.AutoShow = Arguments[2] or false;
    end

    Config.Title = Config.Title or 'MIKU';
    Config.TabPadding = Config.TabPadding or 6;
    Config.MenuFadeTime = Config.MenuFadeTime or 0.2;
    Config.Position = Config.Position or UDim2.fromOffset(175, 60);
    Config.Size = Config.Size or UDim2.fromOffset(580, 620);

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5);
        Config.Position = UDim2.fromScale(0.5, 0.5);
    end

    local Window = { Tabs = {} };

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Library.BackgroundColor,
        Position = Config.Position,
        Size = Config.Size,
        Visible = false,
        ZIndex = 1,
        Parent = ScreenGui,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 10), Parent = Outer });
    local WindowStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1.5, Parent = Outer });

    Library:MakeDraggable(Outer, 40);

    -- Top Header Bar
    local HeaderBar = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 10),
        Size = UDim2.new(1, -32, 0, 30),
        ZIndex = 2,
        Parent = Outer,
    });

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0, 120, 1, 0),
        Text = Config.Title,
        TextColor3 = Library.AccentColor,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = HeaderBar,
    });

    -- Top Tab Bar Area
    local TabArea = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 130, 0, 0),
        Size = UDim2.new(1, -130, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ZIndex = 2,
        Parent = HeaderBar,
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabArea,
    });

    TabListLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        TabArea.CanvasSize = UDim2.fromOffset(TabListLayout.AbsoluteContentSize.X, 0);
    end);

    -- Main Content Area
    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        Position = UDim2.new(0, 12, 0, 48),
        Size = UDim2.new(1, -24, 1, -60),
        ZIndex = 2,
        Parent = Outer,
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 8), Parent = TabContainer });
    Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = TabContainer });

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end

    function Window:AddTab(Name)
        local Tab = { Groupboxes = {}; Tabboxes = {}; };
        local TabWidth = Library:GetTextBounds(Name, Library.Font, 13) + 20;

        local TabBtn = Library:Create('TextButton', {
            BackgroundColor3 = Library.MainColor,
            Size = UDim2.new(0, TabWidth, 1, 0),
            Font = Library.Font,
            Text = Name,
            TextColor3 = Library.FontColor,
            TextSize = 13,
            ZIndex = 3,
            Parent = TabArea,
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 6), Parent = TabBtn });
        local TabStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = TabBtn });

        local TabFrame = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Visible = false,
            ZIndex = 3,
            Parent = TabContainer,
        });

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 8, 0, 8),
            Size = UDim2.new(0.5, -12, 1, -16),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.AccentColor,
            ZIndex = 4,
            Parent = TabFrame,
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0.5, 4, 0, 8),
            Size = UDim2.new(0.5, -12, 1, -16),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.AccentColor,
            ZIndex = 4,
            Parent = TabFrame,
        });

        for _, Side in next, { LeftSide, RightSide } do
            local layout = Library:Create('UIListLayout', {
                Padding = UDim.new(0, 10),
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Parent = Side,
            });
            layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10);
            end);
        end

        function Tab:ShowTab()
            for _, t in next, Window.Tabs do t:HideTab(); end
            Tween(TabBtn, TweenInfo.new(0.2), { BackgroundColor3 = Library.AccentColor, TextColor3 = Color3.new(0, 0, 0) });
            Tween(TabStroke, TweenInfo.new(0.2), { Color = Library.AccentColor });
            TabFrame.Visible = true;
        end

        function Tab:HideTab()
            Tween(TabBtn, TweenInfo.new(0.2), { BackgroundColor3 = Library.MainColor, TextColor3 = Library.FontColor });
            Tween(TabStroke, TweenInfo.new(0.2), { Color = Library.OutlineColor });
            TabFrame.Visible = false;
        end

        function Tab:SetLayoutOrder(Order)
            TabBtn.LayoutOrder = Order;
        end

        TabBtn.MouseButton1Click:Connect(function()
            Tab:ShowTab();
        end);

        function Tab:AddGroupbox(Info)
            local Groupbox = {};
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                Size = UDim2.new(1, -4, 0, 100),
                ZIndex = 4,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 6), Parent = BoxOuter });
            Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = BoxOuter });

            local Header = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 6),
                Size = UDim2.new(1, -16, 0, 18),
                ZIndex = 5,
                Parent = BoxOuter,
            });

            local AccentLine = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 0, 0.5, -5),
                Size = UDim2.new(0, 3, 0, 10),
                ZIndex = 6,
                Parent = Header,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = AccentLine });

            Library:CreateLabel({
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -8, 1, 0),
                TextSize = 13,
                Text = Info.Name,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 6,
                Parent = Header,
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 28),
                Size = UDim2.new(1, -12, 1, -32),
                ZIndex = 5,
                Parent = BoxOuter,
            });

            local ListLayout = Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = Container,
            });

            function Groupbox:Resize()
                local Size = 0;
                for _, Element in next, Container:GetChildren() do
                    if not Element:IsA('UIListLayout') and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end
                end
                BoxOuter.Size = UDim2.new(1, -4, 0, 34 + Size);
            end

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);
            Groupbox:AddBlank(2);
            Groupbox:Resize();
            Tab.Groupboxes[Info.Name] = Groupbox;
            return Groupbox;
        end

        function Tab:AddLeftGroupbox(Name) return Tab:AddGroupbox({ Side = 1, Name = Name }); end
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({ Side = 2, Name = Name }); end

        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {} };
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                Size = UDim2.new(1, -4, 0, 100),
                ZIndex = 4,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 6), Parent = BoxOuter });
            Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = BoxOuter });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 6),
                Size = UDim2.new(1, -12, 0, 22),
                ZIndex = 5,
                Parent = BoxOuter,
            });

            local ListLayout = Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
                Parent = TabboxButtons,
            });

            function Tabbox:AddTab(SubTabName)
                local SubTab = {};
                local Button = Library:Create('TextButton', {
                    BackgroundColor3 = Library.MainColor,
                    Size = UDim2.new(0.5, -2, 1, 0),
                    Font = Library.Font,
                    Text = SubTabName,
                    TextColor3 = Library.FontColor,
                    TextSize = 12,
                    ZIndex = 6,
                    Parent = TabboxButtons,
                });
                Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = Button });
                local BtnStroke = Library:Create('UIStroke', { Color = Library.OutlineColor, Thickness = 1, Parent = Button });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 6, 0, 32),
                    Size = UDim2.new(1, -12, 1, -36),
                    Visible = false,
                    ZIndex = 5,
                    Parent = BoxOuter,
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = Container,
                });

                function SubTab:Show()
                    for _, t in next, Tabbox.Tabs do t:Hide(); end
                    Container.Visible = true;
                    Tween(Button, TweenInfo.new(0.2), { BackgroundColor3 = Library.AccentColor, TextColor3 = Color3.new(0, 0, 0) });
                    Tween(BtnStroke, TweenInfo.new(0.2), { Color = Library.AccentColor });
                    SubTab:Resize();
                end

                function SubTab:Hide()
                    Container.Visible = false;
                    Tween(Button, TweenInfo.new(0.2), { BackgroundColor3 = Library.MainColor, TextColor3 = Library.FontColor });
                    Tween(BtnStroke, TweenInfo.new(0.2), { Color = Library.OutlineColor });
                end

                function SubTab:Resize()
                    local TabCount = 0;
                    for _ in next, Tabbox.Tabs do TabCount = TabCount + 1; end
                    for _, child in next, TabboxButtons:GetChildren() do
                        if child:IsA('TextButton') then
                            child.Size = UDim2.new(1 / TabCount, -4, 1, 0);
                        end
                    end
                    if not Container.Visible then return end
                    local Size = 0;
                    for _, Element in next, Container:GetChildren() do
                        if not Element:IsA('UIListLayout') and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end
                    end
                    BoxOuter.Size = UDim2.new(1, -4, 0, 38 + Size);
                end

                Button.MouseButton1Click:Connect(function()
                    SubTab:Show();
                end);

                SubTab.Container = Container;
                Tabbox.Tabs[SubTabName] = SubTab;
                setmetatable(SubTab, BaseGroupbox);
                SubTab:AddBlank(2);
                SubTab:Resize();

                if #TabboxButtons:GetChildren() == 2 then SubTab:Show(); end
                return SubTab;
            end

            Tab.Tabboxes[Info.Name or ''] = Tabbox;
            return Tabbox;
        end

        function Tab:AddLeftTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 1 }); end
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 2 }); end

        if #TabArea:GetChildren() == 2 then Tab:ShowTab(); end
        Window.Tabs[Name] = Tab;
        return Tab;
    end

    function Library:Toggle()
        Library.Toggled = not Library.Toggled;
        if Library.Toggled then
            Outer.Visible = true;
            Outer.Position = Config.Position + UDim2.fromOffset(0, 15);
            Tween(Outer, TweenInfo.new(Config.MenuFadeTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = Config.Position;
            });
        else
            Tween(Outer, TweenInfo.new(Config.MenuFadeTime, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = Config.Position + UDim2.fromOffset(0, 15);
            });
            task.delay(Config.MenuFadeTime, function()
                if not Library.Toggled then Outer.Visible = false; end
            end);
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

    if Config.AutoShow then task.spawn(Library.Toggle); end
    Window.Holder = Outer;
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