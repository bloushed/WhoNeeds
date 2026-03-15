local _, ns = ...
local addon = ns and ns.Addon or _G.WhoNeeds

local MINIMAP_BUTTON_RADIUS = 92
local MINIMAP_ICON = "Interface\\AddOns\\WhoNeeds\\Media\\WhoNeedsIcon"
local LOOT_ROW_HEIGHT = 116
local LOOT_ROW_STEP = 124

local function isEquipabilityFailure(reason)
    return reason == addon.L.REASON_CLASS_ARMOR
        or reason == addon.L.REASON_CLASS_WEAP
        or reason == addon.L.REASON_CLASS_SHIELD
        or reason == addon.L.REASON_WRONG_ARMOR
        or reason == addon.L.REASON_UNKNOWN_WEAP
        or reason == addon.L.REASON_NOT_EQUIPPABLE
        or reason == addon.L.REASON_MISSING
        or reason == addon.L.REASON_UNKNOWN_SLOT
end

local function setStatusPanelColor(texture, response)
    if not texture then
        return
    end

    local status = response and response.status or nil
    local reason = response and response.reason or ""

    if status == "PASS" and isEquipabilityFailure(reason) then
        texture:SetColorTexture(0.35, 0.05, 0.05, 0.92)
        return
    end

    if status == "BIS" then
        texture:SetColorTexture(0.22, 0.18, 0.05, 0.92)
        return
    end
    if status == "UPGRADE" then
        if (response.delta or 0) < 0 then
            texture:SetColorTexture(0.35, 0.18, 0.05, 0.92) -- Orange for negative upgrade
        else
            texture:SetColorTexture(0.07, 0.18, 0.11, 0.92)
        end
        return
    end
    if status == "SIDEGRADE" then
        texture:SetColorTexture(0.10, 0.14, 0.20, 0.92)
        return
    end
    texture:SetColorTexture(0.12, 0.12, 0.14, 0.9)
end

local function registerEscapeFrame(frame)
    if not frame or type(UISpecialFrames) ~= "table" then
        return
    end

    local name = frame.GetName and frame:GetName() or nil
    if not name or name == "" then
        return
    end

    for _, existing in ipairs(UISpecialFrames) do
        if existing == name then
            return
        end
    end

    table.insert(UISpecialFrames, name)
end

local function copyResponse(response)
    local copy = {}
    if type(response) ~= "table" then
        return copy
    end

    for key, value in pairs(response) do
        copy[key] = value
    end
    return copy
end

local function createModernFrame(name, parent)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    frame.headerBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.headerBg:SetPoint("TOPLEFT", 1, -1)
    frame.headerBg:SetPoint("TOPRIGHT", -1, -1)
    frame.headerBg:SetHeight(30)
    frame.headerBg:SetColorTexture(0.06, 0.06, 0.07, 1)

    frame.headerShine = frame:CreateTexture(nil, "BORDER")
    frame.headerShine:SetPoint("TOPLEFT", frame.headerBg, "TOPLEFT", 0, 0)
    frame.headerShine:SetPoint("TOPRIGHT", frame.headerBg, "TOPRIGHT", 0, 0)
    frame.headerShine:SetHeight(14)
    frame.headerShine:SetColorTexture(1, 1, 1, 0.04)

    frame.headerAccent = frame:CreateTexture(nil, "ARTWORK")
    frame.headerAccent:SetPoint("BOTTOMLEFT", frame.headerBg, "BOTTOMLEFT", 0, 0)
    frame.headerAccent:SetPoint("BOTTOMRIGHT", frame.headerBg, "BOTTOMRIGHT", 0, 0)
    frame.headerAccent:SetHeight(2)
    frame.headerAccent:SetColorTexture(0.80, 0.64, 0.16, 0.95)

    frame.headerBorder = frame:CreateTexture(nil, "BACKGROUND")
    frame.headerBorder:SetPoint("TOPLEFT", frame.headerBg, "BOTTOMLEFT", 0, 0)
    frame.headerBorder:SetPoint("TOPRIGHT", frame.headerBg, "BOTTOMRIGHT", 0, 0)
    frame.headerBorder:SetHeight(1)
    frame.headerBorder:SetColorTexture(0.02, 0.02, 0.03, 1)

    frame.CloseButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    frame.CloseButton:SetSize(24, 24)
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -4)
    frame.CloseButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame.CloseButton:SetBackdropColor(0.15, 0.08, 0.08, 0.98)
    frame.CloseButton:SetBackdropBorderColor(0.42, 0.14, 0.12, 1.00)
    frame.CloseButton.fill = frame.CloseButton:CreateTexture(nil, "BACKGROUND")
    frame.CloseButton.fill:SetPoint("TOPLEFT", 1, -1)
    frame.CloseButton.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.CloseButton.fill:SetColorTexture(0.16, 0.08, 0.08, 0.98)
    frame.CloseButton.label = frame.CloseButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.CloseButton.label:SetPoint("CENTER", 0, 0)
    frame.CloseButton.label:SetText("X")
    frame.CloseButton.label:SetTextColor(1.00, 0.84, 0.72)
    frame.CloseButton:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.90, 0.32, 0.24, 1.00)
        self.fill:SetColorTexture(0.22, 0.10, 0.10, 0.98)
    end)
    frame.CloseButton:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.42, 0.14, 0.12, 1.00)
        self.fill:SetColorTexture(0.16, 0.08, 0.08, 0.98)
    end)
    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    return frame
end

local function createToolbarSection(parent, width, height, titleText)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.10, 0.10, 0.11, 0.92)
    frame:SetBackdropBorderColor(0.02, 0.02, 0.02, 1)

    frame.accent = frame:CreateTexture(nil, "BACKGROUND")
    frame.accent:SetPoint("TOPLEFT", 1, -1)
    frame.accent:SetPoint("BOTTOMLEFT", 1, 1)
    frame.accent:SetWidth(4)
    frame.accent:SetColorTexture(0.76, 0.60, 0.08, 0.95)

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.label:SetPoint("LEFT", 14, 0)
    frame.label:SetText(titleText or "")
    frame.label:SetTextColor(0.95, 0.82, 0.30)

    return frame
end

local function createCollapsibleGroup(parent, titleText, contentHeight, defaultOpen)
    local container = CreateFrame("Frame", nil, parent)
    container:SetWidth(600)
    
    local header = CreateFrame("Button", nil, container)
    header:SetSize(600, 24)
    header:SetPoint("TOPLEFT", 0, 0)
    
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    
    local icon = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    icon:SetPoint("LEFT", 6, 0)
    icon:SetText(defaultOpen and "[-]" or "[+]")
    
    local text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    text:SetText(titleText)
    
    local content = CreateFrame("Frame", nil, container)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    content:SetSize(600, contentHeight)
    content:SetShown(defaultOpen)
    
    header:SetScript("OnClick", function()
        if content:IsShown() then
            content:Hide()
            icon:SetText("[+]")
            container:SetHeight(24)
        else
            content:Show()
            icon:SetText("[-]")
            container:SetHeight(24 + 8 + contentHeight)
        end
        if container.onStateChanged then container.onStateChanged() end
    end)
    
    container:SetHeight(defaultOpen and (24 + 8 + contentHeight) or 24)
    container.header = header
    container.content = content
    return container
end

local function createModernTab(parent, id, text)
    local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tab:SetSize(116, 28)
    tab:SetID(id)

    tab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    tab:SetBackdropColor(0.05, 0.05, 0.06, 0.98)
    tab:SetBackdropBorderColor(0.18, 0.19, 0.22, 1.00)

    tab.fill = tab:CreateTexture(nil, "BACKGROUND")
    tab.fill:SetPoint("TOPLEFT", 1, -1)
    tab.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    tab.fill:SetColorTexture(0.09, 0.09, 0.10, 0.96)

    tab.topAccent = tab:CreateTexture(nil, "ARTWORK")
    tab.topAccent:SetPoint("TOPLEFT", 1, -1)
    tab.topAccent:SetPoint("TOPRIGHT", -1, -1)
    tab.topAccent:SetHeight(2)
    tab.topAccent:SetColorTexture(0.48, 0.50, 0.54, 0.80)

    tab.bottomFade = tab:CreateTexture(nil, "ARTWORK")
    tab.bottomFade:SetPoint("BOTTOMLEFT", 1, 1)
    tab.bottomFade:SetPoint("BOTTOMRIGHT", -1, 1)
    tab.bottomFade:SetHeight(3)
    tab.bottomFade:SetColorTexture(0, 0, 0, 0.35)

    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.label:SetPoint("CENTER", 0, 0)
    tab.label:SetText(text)

    tab.highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    tab.highlight:SetPoint("TOPLEFT", 1, -1)
    tab.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    tab.highlight:SetColorTexture(1, 1, 1, 0.04)

    tab:SetScript("OnEnter", function(self)
        if addon.currentTab ~= id then
            self.fill:SetColorTexture(0.12, 0.11, 0.10, 0.96)
            self.label:SetTextColor(0.95, 0.88, 0.60)
            self.topAccent:SetColorTexture(0.64, 0.54, 0.20, 0.90)
        end
    end)
    tab:SetScript("OnLeave", function(self)
        if addon.currentTab ~= id then
            self.fill:SetColorTexture(0.09, 0.09, 0.10, 0.96)
            self.label:SetTextColor(0.62, 0.63, 0.66)
            self.topAccent:SetColorTexture(0.48, 0.50, 0.54, 0.80)
        end
    end)
    tab:SetScript("OnClick", function() addon:SelectTab(id) end)

    return tab
end

local function getModernButtonPalette(variant)
    if variant == "danger" then
        return {
            bg = { 0.16, 0.08, 0.08, 0.96 },
            border = { 0.42, 0.14, 0.12, 1.00 },
            accent = { 0.90, 0.32, 0.24, 0.95 },
            text = { 1.00, 0.84, 0.72 },
        }
    end
    if variant == "positive" then
        return {
            bg = { 0.07, 0.13, 0.10, 0.96 },
            border = { 0.16, 0.34, 0.24, 1.00 },
            accent = { 0.22, 0.88, 0.52, 0.95 },
            text = { 0.88, 1.00, 0.92 },
        }
    end
    if variant == "muted" then
        return {
            bg = { 0.10, 0.10, 0.11, 0.96 },
            border = { 0.20, 0.21, 0.23, 1.00 },
            accent = { 0.48, 0.50, 0.54, 0.90 },
            text = { 0.82, 0.82, 0.84 },
        }
    end
    return {
        bg = { 0.11, 0.10, 0.08, 0.96 },
        border = { 0.30, 0.24, 0.11, 1.00 },
        accent = { 0.95, 0.76, 0.18, 0.95 },
        text = { 1.00, 0.88, 0.36 },
    }
end

local function refreshModernButtonStyle(button)
    if not button or not button.fill or not button.label then
        return
    end

    local palette = getModernButtonPalette(button.variant)
    local disabled = not button:IsEnabled()
    local hovered = button._hovered
    local pushed = button._pushed

    local bgR, bgG, bgB, bgA = unpack(palette.bg)
    local borderR, borderG, borderB, borderA = unpack(palette.border)
    local accentR, accentG, accentB, accentA = unpack(palette.accent)
    local textR, textG, textB = unpack(palette.text)

    if hovered then
        bgR = math.min(bgR + 0.03, 1)
        bgG = math.min(bgG + 0.03, 1)
        bgB = math.min(bgB + 0.03, 1)
    end
    if pushed then
        bgR = math.max(bgR - 0.03, 0)
        bgG = math.max(bgG - 0.03, 0)
        bgB = math.max(bgB - 0.03, 0)
    end
    if disabled then
        bgA = 0.78
        borderA = 0.65
        accentA = 0.55
        textR, textG, textB = 0.48, 0.48, 0.50
    end

    button:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
    button.fill:SetColorTexture(bgR, bgG, bgB, bgA)
    button.accent:SetColorTexture(accentR, accentG, accentB, accentA)
    button.label:SetTextColor(textR, textG, textB)
    button.highlight:SetShown(hovered and not disabled)
end

local function createModernButton(parent, width, height, text, variant)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0, 0, 0, 0)

    button.fill = button:CreateTexture(nil, "BACKGROUND")
    button.fill:SetPoint("TOPLEFT", 1, -1)
    button.fill:SetPoint("BOTTOMRIGHT", -1, 1)

    button.shine = button:CreateTexture(nil, "BORDER")
    button.shine:SetPoint("TOPLEFT", button.fill, "TOPLEFT", 0, 0)
    button.shine:SetPoint("TOPRIGHT", button.fill, "TOPRIGHT", 0, 0)
    button.shine:SetHeight(math.floor(height * 0.45))
    button.shine:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    if button.shine.SetGradientAlpha then
        button.shine:SetGradientAlpha("VERTICAL", 1, 1, 1, 0.10, 1, 1, 1, 0.00)
    else
        button.shine:SetColorTexture(1, 1, 1, 0.06)
    end

    button.accent = button:CreateTexture(nil, "ARTWORK")
    button.accent:SetPoint("TOPLEFT", 1, -1)
    button.accent:SetPoint("BOTTOMLEFT", 1, 1)
    button.accent:SetWidth(3)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetPoint("TOPLEFT", 1, -1)
    button.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    button.highlight:SetColorTexture(1, 1, 1, 0.05)
    button.highlight:Hide()

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER", 0, 0)
    button.label:SetJustifyH("CENTER")
    button.label:SetWidth(width - 12)
    button.label:SetText(text or "")

    button.variant = variant or "accent"

    function button:SetText(value)
        self.label:SetText(value or "")
    end

    function button:GetText()
        return self.label:GetText()
    end

    function button:GetFontString()
        return self.label
    end

    function button:SetVariant(value)
        self.variant = value or "accent"
        refreshModernButtonStyle(self)
    end

    button:HookScript("OnEnter", function(self)
        self._hovered = true
        refreshModernButtonStyle(self)
    end)
    button:HookScript("OnLeave", function(self)
        self._hovered = false
        self._pushed = false
        refreshModernButtonStyle(self)
    end)
    button:HookScript("OnMouseDown", function(self)
        self._pushed = true
        refreshModernButtonStyle(self)
    end)
    button:HookScript("OnMouseUp", function(self)
        self._pushed = false
        refreshModernButtonStyle(self)
    end)
    button:HookScript("OnEnable", refreshModernButtonStyle)
    button:HookScript("OnDisable", refreshModernButtonStyle)

    refreshModernButtonStyle(button)
    return button
end

local function refreshModernToggleStyle(toggle)
    if not toggle or not toggle.boxFill or not toggle.text then
        return
    end

    local hovered = toggle._hovered
    local checked = toggle.checked
    local boxBgR, boxBgG, boxBgB, boxBgA = 0.08, 0.08, 0.09, 0.98
    local borderR, borderG, borderB, borderA = 0.20, 0.21, 0.23, 1.00
    local accentR, accentG, accentB, accentA = 0.95, 0.76, 0.18, 0.95
    local textR, textG, textB = 0.86, 0.84, 0.78

    if hovered then
        borderR, borderG, borderB = 0.34, 0.28, 0.14
        textR, textG, textB = 1.00, 0.90, 0.46
    end

    toggle.box:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
    toggle.boxFill:SetColorTexture(boxBgR, boxBgG, boxBgB, boxBgA)
    toggle.text:SetTextColor(textR, textG, textB)
    toggle.checkFill:SetColorTexture(accentR, accentG, accentB, accentA)
    toggle.checkFill:SetShown(checked)
    toggle.highlight:SetShown(hovered)
end

local function createModernToggle(parent, width, height, label, mode)
    local toggle = CreateFrame("Button", nil, parent, "BackdropTemplate")
    toggle:SetSize(width, height)
    toggle.mode = mode or "checkbox"
    toggle.checked = false

    toggle.box = CreateFrame("Frame", nil, toggle, "BackdropTemplate")
    toggle.box:SetSize(20, 20)
    toggle.box:SetPoint("LEFT", 0, 0)
    toggle.box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    toggle.box:SetBackdropColor(0, 0, 0, 0)

    toggle.boxFill = toggle.box:CreateTexture(nil, "BACKGROUND")
    toggle.boxFill:SetPoint("TOPLEFT", 1, -1)
    toggle.boxFill:SetPoint("BOTTOMRIGHT", -1, 1)

    toggle.checkFill = toggle.box:CreateTexture(nil, "ARTWORK")
    if toggle.mode == "radio" then
        toggle.checkFill:SetPoint("TOPLEFT", 5, -5)
        toggle.checkFill:SetPoint("BOTTOMRIGHT", -5, 5)
    else
        toggle.checkFill:SetPoint("TOPLEFT", 4, -4)
        toggle.checkFill:SetPoint("BOTTOMRIGHT", -4, 4)
    end

    toggle.highlight = toggle.box:CreateTexture(nil, "HIGHLIGHT")
    toggle.highlight:SetPoint("TOPLEFT", 1, -1)
    toggle.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    toggle.highlight:SetColorTexture(1, 1, 1, 0.05)
    toggle.highlight:Hide()

    toggle.text = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toggle.text:SetPoint("LEFT", toggle.box, "RIGHT", 8, 0)
    toggle.text:SetPoint("RIGHT", toggle, "RIGHT", 0, 0)
    toggle.text:SetJustifyH("LEFT")
    toggle.text:SetText(label or "")

    function toggle:SetChecked(value)
        self.checked = value and true or false
        refreshModernToggleStyle(self)
    end

    function toggle:GetChecked()
        return self.checked and true or false
    end

    function toggle:SetText(value)
        self.text:SetText(value or "")
    end

    toggle:HookScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        if self.mode == "radio" then
            self:SetChecked(true)
        else
            self:SetChecked(not self:GetChecked())
        end
    end)
    toggle:HookScript("OnEnter", function(self)
        self._hovered = true
        refreshModernToggleStyle(self)
    end)
    toggle:HookScript("OnLeave", function(self)
        self._hovered = false
        refreshModernToggleStyle(self)
    end)

    refreshModernToggleStyle(toggle)
    return toggle
end

local function createModernEditBox(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetAutoFocus(false)
    box:SetSize(width, height)
    box:SetFontObject("ChatFontNormal")
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0.09, 0.09, 0.10, 0.96)
    box:SetBackdropBorderColor(0.20, 0.21, 0.23, 1.00)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetTextColor(0.92, 0.92, 0.90)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(0.34, 0.28, 0.14, 1.00)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(0.20, 0.21, 0.23, 1.00)
    end)
    return box
end

local function skinModernScrollButton(button, labelText)
    if not button then
        return
    end

    button:SetSize(12, 12)

    local regions = { button:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end

    if not button.bg then
        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetPoint("TOPLEFT", 0, 0)
        button.bg:SetPoint("BOTTOMRIGHT", 0, 0)
    end
    button.bg:SetColorTexture(0.10, 0.10, 0.11, 0.96)

    if not button.borderTop then
        button.borderTop = button:CreateTexture(nil, "BORDER")
        button.borderTop:SetPoint("TOPLEFT", 0, 0)
        button.borderTop:SetPoint("TOPRIGHT", 0, 0)
        button.borderTop:SetHeight(1)
    end
    if not button.borderBottom then
        button.borderBottom = button:CreateTexture(nil, "BORDER")
        button.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
        button.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
        button.borderBottom:SetHeight(1)
    end
    if not button.borderLeft then
        button.borderLeft = button:CreateTexture(nil, "BORDER")
        button.borderLeft:SetPoint("TOPLEFT", 0, 0)
        button.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
        button.borderLeft:SetWidth(1)
    end
    if not button.borderRight then
        button.borderRight = button:CreateTexture(nil, "BORDER")
        button.borderRight:SetPoint("TOPRIGHT", 0, 0)
        button.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
        button.borderRight:SetWidth(1)
    end
    button.borderTop:SetColorTexture(0.28, 0.24, 0.14, 1)
    button.borderBottom:SetColorTexture(0.28, 0.24, 0.14, 1)
    button.borderLeft:SetColorTexture(0.28, 0.24, 0.14, 1)
    button.borderRight:SetColorTexture(0.28, 0.24, 0.14, 1)

    if not button.label then
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("CENTER", 0, 0)
    end
    button.label:SetText(labelText or "")
    button.label:SetTextColor(1.00, 0.88, 0.36)

    button:HookScript("OnEnter", function(self)
        if self.bg then
            self.bg:SetColorTexture(0.14, 0.12, 0.09, 0.98)
        end
    end)
    button:HookScript("OnLeave", function(self)
        if self.bg then
            self.bg:SetColorTexture(0.10, 0.10, 0.11, 0.96)
        end
    end)
end

local function styleModernScrollBar(scrollFrame)
    if not scrollFrame then
        return
    end

    local scrollBar = scrollFrame.ScrollBar
    if not scrollBar then
        local name = scrollFrame.GetName and scrollFrame:GetName()
        if name and _G[name .. "ScrollBar"] then
            scrollBar = _G[name .. "ScrollBar"]
        end
    end
    if not scrollBar then
        return
    end

    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 18, -1)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 18, 1)
    scrollBar:SetWidth(12)

    local regions = { scrollBar:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end

    if not scrollBar.track then
        scrollBar.track = scrollBar:CreateTexture(nil, "BACKGROUND")
        scrollBar.track:SetPoint("TOPLEFT", 0, -12)
        scrollBar.track:SetPoint("BOTTOMRIGHT", 0, 12)
    end
    scrollBar.track:SetColorTexture(0.08, 0.08, 0.09, 0.96)

    if not scrollBar.trackBorderLeft then
        scrollBar.trackBorderLeft = scrollBar:CreateTexture(nil, "BORDER")
        scrollBar.trackBorderLeft:SetPoint("TOPLEFT", 0, -12)
        scrollBar.trackBorderLeft:SetPoint("BOTTOMLEFT", 0, 12)
        scrollBar.trackBorderLeft:SetWidth(1)
    end
    if not scrollBar.trackBorderRight then
        scrollBar.trackBorderRight = scrollBar:CreateTexture(nil, "BORDER")
        scrollBar.trackBorderRight:SetPoint("TOPRIGHT", 0, -12)
        scrollBar.trackBorderRight:SetPoint("BOTTOMRIGHT", 0, 12)
        scrollBar.trackBorderRight:SetWidth(1)
    end
    scrollBar.trackBorderLeft:SetColorTexture(0.20, 0.21, 0.23, 1)
    scrollBar.trackBorderRight:SetColorTexture(0.20, 0.21, 0.23, 1)

    local thumb = scrollBar.ThumbTexture or (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture()) or nil
    if thumb and thumb.SetTexture then
        thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
        thumb:SetSize(8, 24)
        thumb:SetVertexColor(0.95, 0.76, 0.18, 0.95)
    end

    local upButton = scrollBar.ScrollUpButton or _G[(scrollBar:GetName() or "") .. "ScrollUpButton"]
    local downButton = scrollBar.ScrollDownButton or _G[(scrollBar:GetName() or "") .. "ScrollDownButton"]
    skinModernScrollButton(upButton, "^")
    skinModernScrollButton(downButton, "v")
    if upButton then
        upButton:ClearAllPoints()
        upButton:SetPoint("TOP", scrollBar, "TOP", 0, 0)
    end
    if downButton then
        downButton:ClearAllPoints()
        downButton:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 0)
    end
end

local function ensurePopupOverlay()
    if addon.popupOverlay then
        return addon.popupOverlay
    end

    local overlay = CreateFrame("Button", "WhoNeedsPopupOverlay", UIParent, "BackdropTemplate")
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetToplevel(true)
    overlay:EnableMouse(true)
    overlay:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    overlay:SetBackdropColor(0, 0, 0, 0.01)
    overlay:SetScript("OnClick", function()
        GameTooltip:Hide()
        if addon.frame and addon.frame.askMenu then
            addon.frame.askMenu:Hide()
        end
        if addon.interestedMenu then
            addon.interestedMenu:Hide()
        end
        if addon.langMenu then
            addon.langMenu:Hide()
        end
        if addon.instanceMenu then
            addon.instanceMenu:Hide()
        end
        overlay:Hide()
    end)
    overlay:Hide()
    addon.popupOverlay = overlay
    return overlay
end

local function refreshPopupOverlay()
    local overlay = addon.popupOverlay
    if not overlay then
        return
    end

    local anyPopupShown = false
    if addon.frame and addon.frame.askMenu and addon.frame.askMenu:IsShown() then
        anyPopupShown = true
    elseif addon.interestedMenu and addon.interestedMenu:IsShown() then
        anyPopupShown = true
    elseif addon.langMenu and addon.langMenu:IsShown() then
        anyPopupShown = true
    elseif addon.instanceMenu and addon.instanceMenu:IsShown() then
        anyPopupShown = true
    end

    if anyPopupShown then
        overlay:SetFrameStrata("TOOLTIP")
        overlay:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 90)
        overlay:Show()
        overlay:Raise()
    else
        overlay:Hide()
    end
end

local function showPopupFrame(frame)
    if not frame then
        return
    end

    local overlay = ensurePopupOverlay()
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 90)
    overlay:Show()
    overlay:Raise()

    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel((overlay:GetFrameLevel() or 0) + 10)
    frame:Raise()
    frame:Show()
end

local function createAskMenu()
    local frame = createModernFrame("WhoNeedsAskMenu", UIParent)
    frame:SetSize(500, 320)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()
    frame:SetScript("OnMouseDown", function() end)
    frame:SetScript("OnMouseUp", function() end)
    frame:HookScript("OnHide", refreshPopupOverlay)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.headerBg, "CENTER", 0, 0)
    frame.title:SetText(addon.L.ASK_MENU_TITLE)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", 16, -32)
    frame.subtitle:SetPoint("TOPRIGHT", -16, -32)
    frame.subtitle:SetJustifyH("LEFT")
    frame.subtitle:SetText(addon.L.ASK_MENU_SUBTITLE)

    frame.buttons = {}
    for index = 1, 10 do
        local button = createModernButton(frame, 452, 22, "", "muted")
        button:SetSize(452, 22)
        button:SetPoint("TOPLEFT", 18, -56 - ((index - 1) * 24))
        button:GetFontString():SetJustifyH("LEFT")
        button:GetFontString():SetWidth(430)
        button:GetFontString():ClearAllPoints()
        button:GetFontString():SetPoint("LEFT", 12, 0)
        button:SetScript("OnClick", function(self)
            if not frame.target or not self.message then
                return
            end
            if addon:SendLootWhisper(frame.target, frame.record, self.message, false) then
                frame:Hide()
            end
        end)
        button:SetScript("OnEnter", function(self)
            if not self.message then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.message, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        frame.buttons[index] = button
    end

    return frame
end

local function updateMinimapButtonPosition(button, angle)
    if not button then
        return
    end

    local radians = math.rad(angle or 225)
    local x = math.cos(radians) * MINIMAP_BUTTON_RADIUS
    local y = math.sin(radians) * MINIMAP_BUTTON_RADIUS
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function getLootVerdict(record, localResponse, ownerResponse, tradableState)
    if record.ownerShort == addon.playerName then
        if not localResponse then
            return addon.L.WAITING, 0.50, 0.50, 0.50
        end
        if localResponse.status == "BIS" then
            return addon.L.VERDICT_BIS, 1.00, 0.72, 0.10
        end
        if localResponse.status == "UPGRADE" then
            return addon.L.VERDICT_KEEP, 0.20, 0.95, 0.50
        end
        if localResponse.status == "SIDEGRADE" then
            return addon.L.VERDICT_MAYBE_KEEP, 0.55, 0.82, 1.00
        end
        return addon.L.VERDICT_PASS, 0.60, 0.60, 0.60
    end

    if not localResponse or localResponse.status == "PASS" then
        return addon.L.VERDICT_NOT_FOR_YOU, 0.60, 0.60, 0.60
    end

    if tradableState == "NO" or tradableState == false then
        return addon.L.VERDICT_NOT_TRADABLE, 0.75, 0.28, 0.20
    end

    if not ownerResponse then
        return addon.L.VERDICT_WAIT_OWNER, 0.88, 0.76, 0.28
    end

    if ownerResponse.status == "PASS" then
        return addon.L.VERDICT_ASK_NOW, 0.20, 0.95, 0.50
    end

    if ownerResponse.status == "SIDEGRADE" then
        return addon.L.VERDICT_MAYBE_ASK, 0.95, 0.82, 0.28
    end

    return addon.L.VERDICT_OWNER_NEEDS, 0.90, 0.32, 0.24
end

local function getTradableLabel(tradableState)
    if tradableState == "YES" or tradableState == true then
        return addon.L.TRADEABLE_YES, "66ffcc"
    end
    if tradableState == "NO" or tradableState == false then
        return addon.L.TRADEABLE_NO, "ff9966"
    end
    return addon.L.TRADEABLE_UNKNOWN, "d7c778"
end

local function styleRowButton(button, width)
    if not button then
        return
    end

    button:SetSize(width, 22)
    local text = nil
    if button.GetFontString then
        text = button:GetFontString()
    end
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", 0, 0)
        text:SetWidth(width - 8)
        text:SetJustifyH("CENTER")
    end
    if refreshModernButtonStyle then
        refreshModernButtonStyle(button)
    end
end

local function announceRoll(record)
    if not record then
        return false
    end

    local itemText = record.itemLink or record.itemName or ("item:" .. tostring(record.itemID or "?"))
    local message = string.format(addon.L.ROLL_ANNOUNCE or "Rolling for %s", itemText)
    local chatType = "SAY"
    local inInstanceGroup = false

    if LE_PARTY_CATEGORY_INSTANCE then
        inInstanceGroup = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE)
    end

    if inInstanceGroup then
        chatType = "INSTANCE_CHAT"
    elseif IsInGroup() then
        chatType = IsInRaid() and "RAID" or "PARTY"
    end

    SendChatMessage(message, chatType)
    return true
end

local function createRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(LOOT_ROW_HEIGHT)
    if parent.listAnchor then
        row:SetPoint("TOPLEFT", parent.listAnchor, "TOPLEFT", 0, -((index - 1) * LOOT_ROW_STEP))
        row:SetPoint("TOPRIGHT", parent.listAnchor, "TOPRIGHT", 0, -((index - 1) * LOOT_ROW_STEP))
    else
        row:SetPoint("TOPLEFT", 12, (parent.rowsTopOffset or -76) - ((index - 1) * LOOT_ROW_STEP))
        row:SetPoint("TOPRIGHT", -12, (parent.rowsTopOffset or -76) - ((index - 1) * LOOT_ROW_STEP))
    end

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.07, 0.08, 0.10, 0.94)

    row.verdictBar = row:CreateTexture(nil, "ARTWORK")
    row.verdictBar:SetPoint("TOPLEFT", 0, 0)
    row.verdictBar:SetPoint("BOTTOMLEFT", 0, 0)
    row.verdictBar:SetWidth(4)
    row.verdictBar:SetColorTexture(0.25, 0.25, 0.25, 0.95)

    row.edgeTop = row:CreateTexture(nil, "BORDER")
    row.edgeTop:SetPoint("TOPLEFT", 0, 0)
    row.edgeTop:SetPoint("TOPRIGHT", 0, 0)
    row.edgeTop:SetHeight(1)
    row.edgeTop:SetColorTexture(0.24, 0.26, 0.30, 0.9)

    row.edgeBottom = row:CreateTexture(nil, "BORDER")
    row.edgeBottom:SetPoint("BOTTOMLEFT", 0, 0)
    row.edgeBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    row.edgeBottom:SetHeight(1)
    row.edgeBottom:SetColorTexture(0.02, 0.02, 0.03, 1)

    row.summaryArea = CreateFrame("Frame", nil, row)
    row.summaryArea:SetPoint("TOPLEFT", 14, -12)
    row.summaryArea:SetPoint("TOPRIGHT", -12, -12)
    row.summaryArea:SetHeight(48)

    row.statusArea = CreateFrame("Frame", nil, row)
    row.statusArea:SetPoint("TOPLEFT", row.summaryArea, "BOTTOMLEFT", 0, -6)
    row.statusArea:SetPoint("TOPRIGHT", row.summaryArea, "BOTTOMRIGHT", 0, -6)
    row.statusArea:SetHeight(28)

    row.footerArea = CreateFrame("Frame", nil, row)
    row.footerArea:SetPoint("TOPLEFT", row.statusArea, "BOTTOMLEFT", 0, -6)
    row.footerArea:SetPoint("TOPRIGHT", row.statusArea, "BOTTOMRIGHT", 0, -6)
    row.footerArea:SetPoint("BOTTOMLEFT", 14, 4)
    row.footerArea:SetPoint("BOTTOMRIGHT", -14, 4)

    row.iconFrame = CreateFrame("Frame", nil, row.summaryArea, "BackdropTemplate")
    row.iconFrame:SetSize(50, 50)
    row.iconFrame:SetPoint("TOPLEFT", 0, -2)
    row.iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    row.iconFrame:SetBackdropColor(0.03, 0.03, 0.04, 0.95)
    row.iconFrame:SetBackdropBorderColor(0.18, 0.19, 0.22, 1.00)

    row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", -2, 2)

    row.textArea = CreateFrame("Frame", nil, row.summaryArea)
    row.textArea:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", 12, 2)
    row.textArea:SetPoint("TOPRIGHT", row.summaryArea, "TOPRIGHT", -300, 0)
    row.textArea:SetHeight(48)

    row.glow = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.glow:SetPoint("TOPLEFT", row.textArea, "TOPLEFT", -8, 4)
    row.glow:SetPoint("BOTTOMRIGHT", row.summaryArea, "BOTTOMRIGHT", 0, -2)
    row.glow:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    row.glow:SetBlendMode("ADD")
    row.glow:Hide()

    row.iconBtn = CreateFrame("Button", nil, row.summaryArea)
    row.iconBtn:SetAllPoints(row.iconFrame)
    row.iconBtn:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.iconBtn:SetScript("OnClick", function(self)
        if not self.itemLink then return end
        if IsModifiedClick("DRESSUP") then
            DressUpItemLink(self.itemLink)
        elseif IsModifiedClick("CHATLINK") then
            ChatEdit_InsertLink(self.itemLink)
        end
    end)

    row.iconBorder = row.iconFrame:CreateTexture(nil, "OVERLAY")
    row.iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    row.iconBorder:SetSize(68, 68)
    row.iconBorder:SetPoint("CENTER", row.iconFrame, "CENTER", 0, 0)
    row.iconBorder:SetBlendMode("ADD")
    row.iconBorder:Hide()

    row.verdictText = row.textArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.verdictText:SetPoint("TOPLEFT", row.textArea, "TOPLEFT", 0, -1)
    row.verdictText:SetPoint("TOPRIGHT", row.textArea, "TOPRIGHT", 0, -1)
    row.verdictText:SetJustifyH("LEFT")
    if row.verdictText.SetWordWrap then
        row.verdictText:SetWordWrap(false)
    end
    if row.verdictText.SetMaxLines then
        row.verdictText:SetMaxLines(1)
    end

    row.title = row.textArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.title:SetPoint("TOPLEFT", row.verdictText, "BOTTOMLEFT", 0, -4)
    row.title:SetPoint("TOPRIGHT", row.textArea, "TOPRIGHT", 0, -21)
    row.title:SetJustifyH("LEFT")
    row.title:SetTextColor(0.92, 0.94, 0.98)
    if row.title.SetWordWrap then
        row.title:SetWordWrap(false)
    end
    if row.title.SetMaxLines then
        row.title:SetMaxLines(1)
    end

    row.meta = row.textArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
    row.meta:SetPoint("TOPRIGHT", row.textArea, "TOPRIGHT", 0, -35)
    row.meta:SetJustifyH("LEFT")
    row.meta:SetTextColor(0.70, 0.72, 0.76)
    if row.meta.SetWordWrap then
        row.meta:SetWordWrap(false)
    end
    if row.meta.SetMaxLines then
        row.meta:SetMaxLines(1)
    end

    row.ownerPanel = CreateFrame("Frame", nil, row.statusArea)
    row.ownerPanel:SetPoint("TOPLEFT", 54, 0)
    row.ownerPanel:SetSize(228, 28)
    row.ownerPanel.bg = row.ownerPanel:CreateTexture(nil, "BACKGROUND")
    row.ownerPanel.bg:SetAllPoints()
    row.ownerPanel.bg:SetColorTexture(0.12, 0.12, 0.14, 0.9)
    row.ownerPanel.label = row.ownerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.ownerPanel.label:SetPoint("TOPLEFT", 8, -4)
    row.ownerPanel.label:SetText("")
    row.ownerPanel.value = row.ownerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.ownerPanel.value:SetPoint("TOPLEFT", row.ownerPanel.label, "BOTTOMLEFT", 0, -1)
    row.ownerPanel.value:SetPoint("TOPRIGHT", -8, -16)
    row.ownerPanel.value:SetJustifyH("LEFT")

    row.ilvlText = row.statusArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.ilvlText:SetPoint("TOPLEFT", row.statusArea, "TOPLEFT", 0, -4)
    row.ilvlText:SetPoint("TOPRIGHT", row.statusArea, "TOPLEFT", 42, -4)
    row.ilvlText:SetJustifyH("CENTER")
    row.ilvlText:SetTextColor(1.00, 0.82, 0.20)

    row.youPanel = CreateFrame("Frame", nil, row.statusArea)
    row.youPanel:SetPoint("LEFT", row.ownerPanel, "RIGHT", 8, 0)
    row.youPanel:SetSize(228, 28)
    row.youPanel.bg = row.youPanel:CreateTexture(nil, "BACKGROUND")
    row.youPanel.bg:SetAllPoints()
    row.youPanel.bg:SetColorTexture(0.12, 0.12, 0.14, 0.9)
    row.youPanel.label = row.youPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.youPanel.label:SetPoint("TOPLEFT", 8, -4)
    row.youPanel.label:SetText(addon.L.YOU)
    row.youPanel.value = row.youPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.youPanel.value:SetPoint("TOPLEFT", row.youPanel.label, "BOTTOMLEFT", 0, -1)
    row.youPanel.value:SetPoint("TOPRIGHT", -8, -16)
    row.youPanel.value:SetJustifyH("LEFT")

    row.footerLine = row.footerArea:CreateTexture(nil, "ARTWORK")
    row.footerLine:SetPoint("TOPLEFT", 0, 0)
    row.footerLine:SetPoint("TOPRIGHT", 0, 0)
    row.footerLine:SetHeight(1)
    row.groupInterest = row.footerArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.groupInterest:SetPoint("TOPLEFT", row.footerLine, "BOTTOMLEFT", 0, -3)
    row.groupInterest:SetPoint("TOPRIGHT", row.footerLine, "BOTTOMRIGHT", 0, -3)
    row.groupInterest:SetPoint("BOTTOMLEFT", 0, 0)
    row.groupInterest:SetPoint("BOTTOMRIGHT", 0, 0)
    row.groupInterest:SetJustifyH("LEFT")

    row.footerArea:EnableMouse(true)
    row.footerArea:SetScript("OnEnter", function(self)
        row.groupInterest:SetTextColor(0.95, 0.84, 0.40)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(addon.L.INTEREST_MENU_HINT, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row.footerArea:SetScript("OnLeave", function()
        row.groupInterest:SetTextColor(0.90, 0.90, 0.90)
        GameTooltip:Hide()
    end)
    row.footerArea:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not self.record then
            return
        end
        addon:ShowInterestedMenu(self.record, self)
    end)

    row.btnContainer = CreateFrame("Frame", nil, row.summaryArea)
    row.btnContainer:SetPoint("TOPRIGHT", 0, 0)
    row.btnContainer:SetSize(286, 22)

    row.deleteBtn = createModernButton(row.btnContainer, 22, 22, "X", "danger")
    styleRowButton(row.deleteBtn, 22)
    row.deleteBtn:SetPoint("RIGHT", 0, 0)
    row.deleteBtn:SetText("X")
    row.deleteBtn.label:ClearAllPoints()
    row.deleteBtn.label:SetPoint("CENTER", 0, 1)
    row.deleteBtn.label:SetWidth(22)
    row.deleteBtn.label:SetJustifyH("CENTER")
    row.deleteBtn:SetScript("OnClick", function(self)
        if row.itemKey and row.instanceKey then
            addon:DeleteLootRecord(row.instanceKey, row.itemKey)
        end
    end)

    row.button = createModernButton(row.btnContainer, 54, 22, addon.L.ASK_BUTTON, "muted")
    styleRowButton(row.button, 54)
    row.button:SetPoint("RIGHT", row.deleteBtn, "LEFT", -4, 0)
    row.button:SetText(addon.L.ASK_BUTTON)
    row.button:SetScript("OnClick", function(self)
        local target = self.ownerName
        if not target then
            return
        end
        addon:ShowAskMenu(target, self.record, self.localResponse, self)
    end)

    row.rapidAskBtn = createModernButton(row.btnContainer, 72, 22, addon.L.FAST_ASK, "accent")
    styleRowButton(row.rapidAskBtn, 72)
    row.rapidAskBtn:SetPoint("RIGHT", row.button, "LEFT", -4, 0)
    row.rapidAskBtn:SetText(addon.L.FAST_ASK)
    row.rapidAskBtn:SetScript("OnClick", function(self)
        local target = self.ownerName
        if not target or not self.record then return end

        local templates = addon.db and addon.db.options and addon.db.options.askTemplates or {}
        local fastIndex = addon.db and addon.db.options and addon.db.options.fastAskIndex or 1
        local template = templates[fastIndex] or "Can I get {item}?"

        local message = addon:FormatWhisperTemplate(template, self.record, self.localResponse)
        addon:SendLootWhisper(target, self.record, message, true)
    end)

    row.rollBtn = createModernButton(row.btnContainer, 42, 22, addon.L.ROLL, "muted")
    styleRowButton(row.rollBtn, 42)
    row.rollBtn:SetPoint("RIGHT", row.rapidAskBtn, "LEFT", -4, 0)
    row.rollBtn:SetText(addon.L.ROLL)
    row.rollBtn:SetScript("OnClick", function(self)
        local localResponse = self.localResponse or (self.record and self.record.responses and self.record.responses[addon.playerName]) or nil
        if self.record and localResponse and localResponse.status ~= "PASS" then
            local response = copyResponse(localResponse)
            addon:EnsureResponseRoll(self.record, addon.playerName, response)
            addon:StoreResponse(self.record, addon.playerName, response)
            addon:SendFitResponse(self.record.key, response)
        end
        announceRoll(self.record)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function()
                RandomRoll(1, 100)
            end)
        else
            RandomRoll(1, 100)
        end
    end)

    row.interestBtn = createModernButton(row.btnContainer, 54, 22, addon.L.NEED, "positive")
    styleRowButton(row.interestBtn, 54)
    row.interestBtn:SetPoint("RIGHT", row.rollBtn, "LEFT", -4, 0)
    row.interestBtn:SetText(addon.L.NEED)
    row.interestBtn:SetScript("OnClick", function(self)
        if not row.record then return end
        
        local currentRes = row.record.responses[addon.playerName]
        local isCurrentlyInterested = currentRes and currentRes.status ~= "PASS"
        local response

        if isCurrentlyInterested then
            response = copyResponse(currentRes)
            response.status = "PASS"
            response.reason = response.reason or addon.L.REASON_MANUAL_OVERRIDE
            response.summary = response.summary or addon.L.REASON_MANUAL_OVERRIDE
        else
            response = {
                status = "UPGRADE",
                delta = currentRes and currentRes.delta or 0,
                itemLevel = currentRes and currentRes.itemLevel or 0,
                reason = addon.L.REASON_MANUAL_OVERRIDE,
                summary = addon.L.REASON_MANUAL_OVERRIDE,
            }
            addon:EnsureResponseRoll(row.record, addon.playerName, response)
        end
        
        addon:StoreResponse(row.record, addon.playerName, response)
        addon:SendFitResponse(row.record.key, response)
    end)

    row:SetScript("OnEnter", function(self)
        if not self.itemLink then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

local function createEditBox(parent, width, height)
    return createModernEditBox(parent, width, height)
end

function addon:CreateUI()
    if self.frame then
        return
    end

    local defaultHeight = self.db and self.db.options and self.db.options.frameHeight or 508
    local frame = createModernFrame("WhoNeedsFrame", UIParent)
    frame:SetSize(680, defaultHeight)
    frame:SetPoint("CENTER", 220, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(680, 310, 680, 1200)
    else
        frame:SetMinResize(680, 310)
        frame:SetMaxResize(680, 1200)
    end
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:HookScript("OnHide", function()
        if frame.askMenu and frame.askMenu:IsShown() then
            frame.askMenu:Hide()
        end
        if addon.interestedMenu and addon.interestedMenu:IsShown() then
            addon.interestedMenu:Hide()
        end
        if addon.instanceMenu and addon.instanceMenu:IsShown() then
            addon.instanceMenu:Hide()
        end
        if addon.langMenu and addon.langMenu:IsShown() then
            addon.langMenu:Hide()
        end
        refreshPopupOverlay()
    end)
    registerEscapeFrame(frame)

    local resizeBtn = CreateFrame("Button", nil, frame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if addon.db and addon.db.options then
            addon.db.options.frameHeight = math.floor(frame:GetHeight())
        end
        addon:RefreshUI()
    end)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.headerBg, "CENTER", 0, 0)
    frame.title:SetText("WhoNeeds")
    frame.title:SetTextColor(0.96, 0.91, 0.78)

    frame.pendingLootText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.pendingLootText:SetPoint("TOPRIGHT", -36, -10)
    frame.pendingLootText:SetJustifyH("RIGHT")
    frame.pendingLootText:SetTextColor(0.95, 0.82, 0.30)
    frame.pendingLootText:SetText("")
    frame.pendingLootText:Hide()

    frame.simLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.simLabel:SetPoint("TOPLEFT", 18, -40)
    frame.simLabel:SetText(addon.L.SIMULATION_LABEL)

    frame.simInput = createEditBox(frame, 280, 24)
    frame.simInput:SetPoint("TOPLEFT", 18, -58)
    frame.simInput:SetScript("OnEscapePressed", frame.simInput.ClearFocus)
    frame.simInput:SetScript("OnEnterPressed", function(self)
        addon:SimulateLootInput(self:GetText(), frame.ownerInput:GetText())
    end)

    frame.ownerInput = createEditBox(frame, 120, 24)
    frame.ownerInput:SetPoint("LEFT", frame.simInput, "RIGHT", 10, 0)
    frame.ownerInput:SetScript("OnEscapePressed", frame.ownerInput.ClearFocus)
    frame.ownerInput:SetScript("OnEnterPressed", function(self)
        addon:SimulateLootInput(frame.simInput:GetText(), self:GetText())
    end)

    frame.simHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.simHint:SetPoint("TOPLEFT", frame.simInput, "BOTTOMLEFT", 0, -6)
    frame.simHint:SetText(addon.L.SIMULATION_HINT)

    frame.forceCheck = createModernToggle(frame, 220, 22, addon.L.FORCE_INTEREST, "checkbox")
    frame.forceCheck:SetPoint("TOPLEFT", frame.simHint, "BOTTOMLEFT", 0, -6)

    frame.simButton = createModernButton(frame, 84, 22, addon.L.SIM_BUTTON, "accent")
    frame.simButton:SetSize(84, 22)
    frame.simButton:SetPoint("LEFT", frame.ownerInput, "RIGHT", 10, 0)
    frame.simButton:SetText(addon.L.SIM_BUTTON)
    frame.simButton:SetScript("OnClick", function()
        addon:SimulateLootInput(frame.simInput:GetText(), frame.ownerInput:GetText(), frame.forceCheck:GetChecked())
    end)

    frame.instanceLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.instanceLabel:SetPoint("TOPLEFT", 18, -42)
    frame.instanceLabel:SetText(addon.L.INSTANCE_SECTION)
    frame.instanceLabel:SetTextColor(0.95, 0.82, 0.30)

    frame.instanceDropBtn = createModernButton(frame, 200, 22, addon.L.SELECT_INSTANCE, "muted")
    frame.instanceDropBtn:SetSize(200, 22)
    frame.instanceDropBtn:SetPoint("LEFT", frame.instanceLabel, "RIGHT", 16, 0)
    frame.instanceDropBtn:SetText(addon.L.SELECT_INSTANCE)
    frame.instanceDropBtn:SetScript("OnClick", function(self)
        addon:ShowInstanceMenu(self)
    end)
    
    frame.deleteInstanceBtn = createModernButton(frame, 110, 22, addon.L.DELETE_INSTANCE, "danger")
    frame.deleteInstanceBtn:SetSize(110, 22)
    frame.deleteInstanceBtn:SetPoint("LEFT", frame.instanceDropBtn, "RIGHT", 10, 0)
    frame.deleteInstanceBtn:SetText(addon.L.DELETE_INSTANCE)
    frame.deleteInstanceBtn:SetScript("OnClick", function(self)
        if addon.currentViewInstance then
            addon:DeleteInstance(addon.currentViewInstance)
        end
    end)
    
    frame.filtersLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.filtersLabel:SetPoint("TOPLEFT", 18, -74)
    frame.filtersLabel:SetText(addon.L.FILTERS_SECTION)
    frame.filtersLabel:SetTextColor(0.95, 0.82, 0.30)

    frame.equippableCheck = createModernToggle(frame, 132, 22, addon.L.USABLE_ONLY, "checkbox")
    frame.equippableCheck:SetPoint("LEFT", frame.filtersLabel, "RIGHT", 16, 0)
    frame.equippableCheck:SetChecked(addon.db and addon.db.options and addon.db.options.filterUsableOnly ~= false)
    frame.equippableCheck:SetScript("OnClick", function()
        if addon.db and addon.db.options then
            addon.db.options.filterUsableOnly = frame.equippableCheck:GetChecked() and true or false
        end
        addon.currentPage = 1
        addon:RefreshUI()
    end)
    
    frame.ownDropsCheck = createModernToggle(frame, 132, 22, addon.L.OWN_DROPS, "checkbox")
    frame.ownDropsCheck:SetPoint("LEFT", frame.equippableCheck, "RIGHT", 12, 0)
    frame.ownDropsCheck:SetChecked(not addon.db or not addon.db.options or addon.db.options.filterOwnDrops ~= false)
    frame.ownDropsCheck:SetScript("OnClick", function()
        if addon.db and addon.db.options then
            addon.db.options.filterOwnDrops = frame.ownDropsCheck:GetChecked() and true or false
        end
        addon.currentPage = 1
        addon:RefreshUI()
    end)

    frame.tradableCheck = createModernToggle(frame, 132, 22, addon.L.TRADABLE_ONLY, "checkbox")
    frame.tradableCheck:SetPoint("LEFT", frame.ownDropsCheck, "RIGHT", 12, 0)
    frame.tradableCheck:SetChecked(addon.db and addon.db.options and addon.db.options.filterTradableOnly == true)
    frame.tradableCheck:SetScript("OnClick", function()
        if addon.db and addon.db.options then
            addon.db.options.filterTradableOnly = frame.tradableCheck:GetChecked() and true or false
        end
        addon.currentPage = 1
        addon:RefreshUI()
    end)

    frame.topDivider = frame:CreateTexture(nil, "ARTWORK")
    frame.topDivider:SetPoint("TOPLEFT", 18, -92)
    frame.topDivider:SetPoint("TOPRIGHT", -18, -92)
    frame.topDivider:SetHeight(1)
    frame.topDivider:SetColorTexture(0.20, 0.22, 0.26, 0.9)

    frame.listAnchor = CreateFrame("Frame", nil, frame)
    frame.listAnchor:SetPoint("TOPLEFT", 18, -102)
    frame.listAnchor:SetPoint("TOPRIGHT", -18, -102)
    frame.listAnchor:SetHeight(1)

    frame.askMenu = createAskMenu()

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("TOPLEFT", frame.listAnchor, "TOPLEFT", 0, -18)
    frame.empty:SetText(addon.L.EMPTY_LOOT)

    frame.rowsTopOffset = -102
    frame.rows = {}

    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.pageText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
    frame.pageText:SetText(string.format(addon.L.PAGE, 1, 1))
    
    frame.prevBtn = createModernButton(frame, 80, 22, addon.L.PREVIOUS, "muted")
    frame.prevBtn:SetSize(80, 22)
    frame.prevBtn:SetPoint("RIGHT", frame.pageText, "LEFT", -15, 0)
    frame.prevBtn:SetText(addon.L.PREVIOUS)
    frame.prevBtn:SetScript("OnClick", function()
        addon.currentPage = math.max(1, (addon.currentPage or 1) - 1)
        addon:RefreshUI()
    end)
    
    frame.nextBtn = createModernButton(frame, 80, 22, addon.L.NEXT, "muted")
    frame.nextBtn:SetSize(80, 22)
    frame.nextBtn:SetPoint("LEFT", frame.pageText, "RIGHT", 15, 0)
    frame.nextBtn:SetText(addon.L.NEXT)
    frame.nextBtn:SetScript("OnClick", function()
        addon.currentPage = (addon.currentPage or 1) + 1
        addon:RefreshUI()
    end)

    frame.tabs = {}
    frame.tabs[1] = createModernTab(frame, 1, addon.L.LOOTS)
    frame.tabs[1]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 1)

    frame.tabs[2] = createModernTab(frame, 2, addon.L.SIMULATIONS)
    frame.tabs[2]:SetPoint("LEFT", frame.tabs[1], "RIGHT", 4, 0)
    
    frame.tabs[3] = createModernTab(frame, 3, addon.L.SETTINGS)
    frame.tabs[3]:SetPoint("LEFT", frame.tabs[2], "RIGHT", 4, 0)

    frame.settingsList = CreateFrame("Frame", nil, frame)
    frame.settingsList:SetPoint("TOPLEFT", 18, -44)
    frame.settingsList:SetPoint("BOTTOMRIGHT", -18, 18)
    frame.settingsList:Hide()

    local generalGroup = createCollapsibleGroup(frame.settingsList, addon.L.GENERAL_OPTIONS, 28, true)
    generalGroup:SetPoint("TOPLEFT", 0, 0)
    
    local fastAskGroup = createCollapsibleGroup(frame.settingsList, addon.L.FAST_ASK_TITLE, 305, true)
    fastAskGroup:SetPoint("TOPLEFT", generalGroup, "BOTTOMLEFT", 0, -8)

    local function updateSettingsLayout()
        fastAskGroup:SetPoint("TOPLEFT", generalGroup, "BOTTOMLEFT", 0, -8)
    end
    generalGroup.onStateChanged = updateSettingsLayout

    local autoOpenCheck = createModernToggle(generalGroup.content, 180, 22, addon.L.AUTO_OPEN, "checkbox")
    autoOpenCheck:SetPoint("TOPLEFT", 0, 0)
    
    autoOpenCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(addon.L.AUTO_OPEN_DESC, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    autoOpenCheck:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    autoOpenCheck:SetScript("OnClick", function(self)
        if addon.db and addon.db.options then
            addon.db.options.autoOpen = self:GetChecked()
        end
    end)
    frame.settingsList.autoOpenCheck = autoOpenCheck
    
    local sDesc = fastAskGroup.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sDesc:SetPoint("TOPLEFT", 0, 0)
    sDesc:SetText(addon.L.FAST_ASK_DESC)
    sDesc:SetJustifyH("LEFT")

    local langDropBtn = createModernButton(generalGroup.content, 120, 22, "", "muted")
    langDropBtn:SetSize(120, 22)
    langDropBtn:SetPoint("TOPRIGHT", generalGroup.content, "TOPRIGHT", 0, 0)
    
    local langLabel = generalGroup.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    langLabel:SetPoint("RIGHT", langDropBtn, "LEFT", -8, 0)
    langLabel:SetText(addon.L.LANGUAGE)
    
    local function updateLangBtnText()
        local lopt = addon.db and addon.db.options and addon.db.options.language or "AUTO"
        if lopt == "frFR" then
            langDropBtn:SetText(addon.L.LANGUAGE_FRENCH)
        elseif lopt == "enUS" then
            langDropBtn:SetText(addon.L.LANGUAGE_ENGLISH)
        else
            langDropBtn:SetText(addon.L.LANGUAGE_AUTO)
        end
    end
    updateLangBtnText()
    
    local function langOnClick(self)
        if not addon.langMenu then
            local lm = createModernFrame("WhoNeedsLangMenu", UIParent)
            lm:SetSize(200, 160)
            lm:SetFrameStrata("TOOLTIP")
            lm:SetToplevel(true)
            lm:EnableMouse(true)
            lm:HookScript("OnHide", refreshPopupOverlay)
            registerEscapeFrame(lm)
            lm.title = lm:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lm.title:SetPoint("CENTER", lm.headerBg, "CENTER", 0, 0)
            lm.title:SetText(addon.L.LANGUAGE)
            lm.scrollChild = CreateFrame("Frame")
            lm.scrollChild:SetSize(160, 100)
            lm.scrollFrame = CreateFrame("ScrollFrame", nil, lm, "UIPanelScrollFrameTemplate")
            lm.scrollFrame:SetPoint("TOPLEFT", 12, -32)
            lm.scrollFrame:SetPoint("BOTTOMRIGHT", -32, 12)
            lm.scrollFrame:SetScrollChild(lm.scrollChild)
            styleModernScrollBar(lm.scrollFrame)
            
            local opts = {
                { k = "AUTO", v = addon.L.LANGUAGE_AUTO },
                { k = "enUS", v = addon.L.LANGUAGE_ENGLISH },
                { k = "frFR", v = addon.L.LANGUAGE_FRENCH },
            }
            local yOffs = -4
            for i, opt in ipairs(opts) do
                local b = createModernButton(lm.scrollChild, 140, 24, opt.v, "muted")
                b:SetSize(140, 24)
                b:SetPoint("TOPLEFT", 8, yOffs)
                b:SetText(opt.v)
                b:SetScript("OnClick", function()
                    if addon.db and addon.db.options then
                        addon.db.options.language = opt.k
                        ReloadUI()
                    end
                    lm:Hide()
                end)
                yOffs = yOffs - 28
            end
            addon.langMenu = lm
        end
        addon.langMenu:ClearAllPoints()
        addon.langMenu:SetPoint("TOPRIGHT", langDropBtn, "BOTTOMRIGHT", 0, -4)
        showPopupFrame(addon.langMenu)
    end
    langDropBtn:SetScript("OnClick", langOnClick)

    frame.settingRows = {}
    for i = 1, 8 do
        local r = CreateFrame("Frame", nil, fastAskGroup.content)
        r:SetSize(600, 32)
        r:SetPoint("TOPLEFT", 0, -32 - ((i - 1) * 36))
        
        local check = createModernToggle(r, 22, 22, "", "radio")
        check:SetPoint("LEFT", 0, 0)
        check:SetScript("OnClick", function(self)
            if addon.db and addon.db.options then
                addon.db.options.fastAskIndex = i
            end
            for _, sr in ipairs(frame.settingRows) do sr.check:SetChecked(false) end
            self:SetChecked(true)
        end)
        
        local ebox = createEditBox(r, 540, 24)
        ebox:SetPoint("LEFT", check, "RIGHT", 10, 0)
        ebox:SetScript("OnEscapePressed", ebox.ClearFocus)
        ebox:SetScript("OnTextChanged", function(self, isUserInput)
            if isUserInput and addon.db and addon.db.options and addon.db.options.askTemplates then
                local txt = self:GetText()
                if txt and txt ~= "" then
                    addon.db.options.askTemplates[i] = txt
                else
                    addon.db.options.askTemplates[i] = nil
                end
            end
        end)
        
        r.check = check
        r.ebox = ebox
        frame.settingRows[i] = r
    end

    frame:Hide()
    self.frame = frame
    
    self:SelectTab(1)
end

function addon:SelectTab(tabID)
    self.currentTab = tabID
    
    if self.frame and self.frame.tabs then
        for i, tab in ipairs(self.frame.tabs) do
            if i == tabID then
                tab:SetBackdropBorderColor(0.36, 0.28, 0.12, 1.00)
                tab.fill:SetColorTexture(0.14, 0.11, 0.07, 0.98)
                tab.topAccent:SetColorTexture(0.96, 0.78, 0.20, 0.98)
                tab.label:SetTextColor(1.00, 0.90, 0.46)
            else
                tab:SetBackdropBorderColor(0.18, 0.19, 0.22, 1.00)
                tab.fill:SetColorTexture(0.09, 0.09, 0.10, 0.96)
                tab.topAccent:SetColorTexture(0.48, 0.50, 0.54, 0.80)
                tab.label:SetTextColor(0.62, 0.63, 0.66)
            end
        end
    end
    
    local isSim = (tabID == 2)
    local isSettings = (tabID == 3)
    
    self.frame.simLabel:SetShown(isSim)
    self.frame.simInput:SetShown(isSim)
    self.frame.ownerInput:SetShown(isSim)
    self.frame.simHint:SetShown(isSim)
    self.frame.forceCheck:SetShown(isSim)
    self.frame.simButton:SetShown(isSim)
    self.frame.pendingLootText:Hide()
    
    self.frame.instanceLabel:SetShown(not isSim and not isSettings)
    self.frame.filtersLabel:SetShown(not isSim and not isSettings)
    self.frame.instanceDropBtn:SetShown(not isSim and not isSettings)
    self.frame.deleteInstanceBtn:SetShown(not isSim and not isSettings)
    self.frame.equippableCheck:SetShown(not isSim and not isSettings)
    self.frame.ownDropsCheck:SetShown(not isSim and not isSettings)
    self.frame.tradableCheck:SetShown(not isSim and not isSettings)
    self.frame.topDivider:SetShown(not isSim and not isSettings)
    
    self.frame.settingsList:SetShown(isSettings)

    if isSettings then
        local autoOpen = true
        if self.db and self.db.options and self.db.options.autoOpen ~= nil then
            autoOpen = self.db.options.autoOpen
        end
        self.frame.settingsList.autoOpenCheck:SetChecked(autoOpen)
        
        local fastIndex = self.db and self.db.options and self.db.options.fastAskIndex or 1
        local templates = self.db and self.db.options and self.db.options.askTemplates or {}
        for i, sr in ipairs(self.frame.settingRows) do
            sr.check:SetChecked(i == fastIndex)
            sr.ebox:SetText(templates[i] or "")
        end
    end
    
    if isSim then
        self.currentViewInstance = "Simulation"
    else
        if self.currentViewInstance == "Simulation" then
            self.currentViewInstance = nil
        end
    end
    
    self.frame.rowsTopOffset = isSim and -128 or -76
    
    self.currentPage = 1
    self:RefreshUI()
end

function addon:CreateMinimapButton()
    if self.minimapButton then
        self:UpdateMinimapButton()
        return
    end

    local minimapParent = MinimapCluster or Minimap
    local button = CreateFrame("Button", "WhoNeedsMinimapButton", minimapParent)
    button:SetSize(32, 32)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 8)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.shadow = button:CreateTexture(nil, "BACKGROUND")
    button.shadow:SetTexture(MINIMAP_ICON)
    button.shadow:SetVertexColor(0, 0, 0, 0.45)
    button.shadow:SetSize(28, 28)
    button.shadow:SetPoint("CENTER", 1, -1)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(MINIMAP_ICON)
    button.icon:SetSize(28, 28)
    button.icon:SetTexCoord(0, 1, 0, 1)
    button.icon:SetPoint("CENTER")

    button.iconMask = button:CreateMaskTexture()
    button.iconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    button.iconMask:SetSize(28, 28)
    button.iconMask:SetPoint("CENTER")
    button.icon:AddMaskTexture(button.iconMask)
    button.shadow:AddMaskTexture(button.iconMask)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetSize(46, 46)
    button.highlight:SetPoint("CENTER")

    button.badge = CreateFrame("Frame", nil, button)
    button.badge:SetSize(16, 16)
    button.badge:SetPoint("TOPRIGHT", 2, 2)
    button.badge.bg = button.badge:CreateTexture(nil, "OVERLAY")
    button.badge.bg:SetAllPoints()
    button.badge.bg:SetColorTexture(0.85, 0.12, 0.12, 0.95)
    button.badge.text = button.badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.badge.text:SetPoint("CENTER", 0, 0)
    button.badge.text:SetText("!")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            addon:MarkLootSeen()
            return
        end
        addon:ToggleUI()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("WhoNeeds", 1, 0.82, 0)
        GameTooltip:AddLine(addon.L.MINIMAP_TOOLTIP_OPEN, 1, 1, 1, true)
        if addon.hasUnreadLoot then
            GameTooltip:AddLine(addon.L.MINIMAP_TOOLTIP_NEW, 0.25, 1, 0.25, true)
        else
            GameTooltip:AddLine(addon.L.MINIMAP_TOOLTIP_IDLE, 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine(addon.L.MINIMAP_TOOLTIP_CLEAR, 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine(addon.L.MINIMAP_TOOLTIP_DRAG, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local cursorX, cursorY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale() or 1
            cursorX = cursorX / scale
            cursorY = cursorY / scale

            local centerX, centerY = Minimap:GetCenter()
            local angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX)) % 360
            addon.db.options.minimap.angle = angle
            updateMinimapButtonPosition(self, angle)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    self.minimapButton = button
    self:UpdateMinimapButton()
end

function addon:UpdateMinimapButton()
    if not self.minimapButton or not self.db or not self.db.options then
        return
    end

    local minimapOptions = self.db.options.minimap or {}
    self.db.options.minimap = minimapOptions

    -- No UI currently exposes a minimap hide toggle, so recover from stale hidden state.
    if minimapOptions.hidden == true then
        minimapOptions.hidden = false
    end

    if type(minimapOptions.angle) ~= "number" then
        minimapOptions.angle = 225
    end

    self.minimapButton:SetParent(MinimapCluster or Minimap)
    self.minimapButton:SetFrameStrata("HIGH")
    self.minimapButton:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 8)

    if minimapOptions.hidden then
        self.minimapButton:Hide()
        return
    end

    updateMinimapButtonPosition(self.minimapButton, minimapOptions.angle or 225)
    self.minimapButton.badge:SetShown(self.hasUnreadLoot)
    self.minimapButton:Raise()
    self.minimapButton:Show()
end

local function createInstanceMenu()
    local frame = createModernFrame("WhoNeedsInstanceMenu", UIParent)
    frame:SetSize(300, 400)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()
    frame:HookScript("OnHide", refreshPopupOverlay)
    registerEscapeFrame(frame)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.headerBg, "CENTER", 0, 0)
    frame.title:SetText(addon.L.SELECT_INSTANCE_TITLE)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
    frame.subtitle:SetJustifyH("LEFT")

    frame.scrollFrame = CreateFrame("ScrollFrame", "WhoNeedsAskMenuScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", 12, -32)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -32, 12)
    styleModernScrollBar(frame.scrollFrame)

    frame.scrollChild = CreateFrame("Frame")
    frame.scrollChild:SetSize(250, 10)
    frame.scrollFrame:SetScrollChild(frame.scrollChild)

    frame.buttons = {}
    return frame
end

function addon:ShowInstanceMenu(anchor)
    if not self.instanceMenu then
        self.instanceMenu = createInstanceMenu()
    end

    local menu = self.instanceMenu
    
    for _, btn in ipairs(menu.buttons) do
        btn:Hide()
    end
    
    local instances = {}
    if self.charDB and self.charDB.instances then
        for key, instDB in pairs(self.charDB.instances) do
            table.insert(instances, { key = key, name = instDB.name })
        end
    end
    table.sort(instances, function(a, b) return (a.name or "") < (b.name or "") end)
    
    local yOffset = -4
    for i, inst in ipairs(instances) do
        local btn = menu.buttons[i]
        if not btn then
            btn = createModernButton(menu.scrollChild, 240, 24, "", "muted")
            btn:SetSize(240, 24)
            btn:GetFontString():SetJustifyH("LEFT")
            btn:GetFontString():ClearAllPoints()
            btn:GetFontString():SetPoint("LEFT", 12, 0)
            menu.buttons[i] = btn
        end
        
        btn:SetText(" " .. (inst.name or addon.L.UNKNOWN))
        btn.instanceKey = inst.key
        btn:SetPoint("TOPLEFT", 8, yOffset)
        btn:SetScript("OnClick", function(self)
            addon.currentViewInstance = self.instanceKey
            addon.currentPage = 1
            if addon.charDB and addon.charDB.state then
                addon.charDB.state.lastViewInstance = self.instanceKey
            end
            addon:RefreshUI()
            menu:Hide()
        end)
        btn:Show()
        yOffset = yOffset - 28
    end
    
    menu.scrollChild:SetHeight(math.abs(yOffset))
    
    menu:ClearAllPoints()
    if anchor then
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    else
        menu:SetPoint("CENTER")
    end
    showPopupFrame(menu)
end

function addon:ShowAskMenu(target, record, localResponse, anchor)
    self:CreateUI()

    local askMenu = self.frame and self.frame.askMenu
    if not askMenu then
        return
    end

    askMenu.target = target
    askMenu.record = record
    askMenu.subtitle:SetText(string.format(addon.L.ASK_TOOLTIP, target))
    local templates = self.db and self.db.options and self.db.options.askTemplates or {}
    for index, template in ipairs(templates) do
        local button = askMenu.buttons[index]
        if button and template and template ~= "" then
            local message = self:FormatWhisperTemplate(template, record, localResponse)
            button.message = message
            button:SetText(message)
            button:Show()
        end
    end

    for index = #templates + 1, #askMenu.buttons do
        if askMenu.buttons[index] then
            askMenu.buttons[index]:Hide()
        end
    end

    askMenu:ClearAllPoints()
    if anchor then
        askMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -410, -4)
    else
        askMenu:SetPoint("CENTER")
    end
    showPopupFrame(askMenu)
end

function addon:ToggleUI()
    self:CreateUI()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:MarkLootSeen()
        self:RefreshUI()
    end
end

function addon:GetInterestedEntries(record)
    local interested = {}
    for playerName, response in pairs(record.responses) do
        if response.status ~= "PASS" then
            local profile = self.peerProfiles[playerName]
            local classFile = profile and profile.classFile
            local status = addon.L[response.status] or response.status
            table.insert(interested, {
                name = playerName,
                classFile = classFile,
                status = status,
                score = response.delta or 0,
                roll = self:GetResponseRoll(response),
                order = tonumber(response.interestOrder) or 0,
                updatedAt = tonumber(response.updatedAt) or 0,
            })
        end
    end
    table.sort(interested, function(a, b)
        if a.roll > 0 and b.roll > 0 and a.roll ~= b.roll then
            return a.roll > b.roll
        end
        if a.roll > 0 and b.roll == 0 then
            return true
        end
        if b.roll > 0 and a.roll == 0 then
            return false
        end
        if a.order > 0 and b.order > 0 and a.order ~= b.order then
            return a.order < b.order
        end
        if a.order > 0 and b.order == 0 then
            return true
        end
        if b.order > 0 and a.order == 0 then
            return false
        end
        if a.updatedAt ~= b.updatedAt then
            return a.updatedAt < b.updatedAt
        end
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.name < b.name
    end)

    for index, entry in ipairs(interested) do
        entry.displayOrder = entry.order > 0 and entry.order or index
        local label = string.format(
            "%s (%s %.1f)",
            self:GetColoredName(entry.name, entry.classFile),
            entry.status,
            entry.score
        )
        if entry.roll > 0 then
            entry.text = string.format("|cffffd26a[%d]|r %s", entry.roll, label)
        else
            entry.text = string.format("%d. %s", entry.displayOrder, label)
        end
    end

    return interested
end

function addon:BuildInterestLine(record)
    local interested = self:GetInterestedEntries(record)
    if #interested == 0 then
        return addon.L.INTERESTED .. addon.L.NOBODY_YET
    end

    local texts = {}
    for _, entry in ipairs(interested) do
        table.insert(texts, entry.text)
    end
    return addon.L.INTERESTED .. table.concat(texts, ", ")
end

function addon:ShowInterestedMenu(record, anchor)
    self:CreateUI()

    if not self.interestedMenu then
        self.interestedMenu = self:CreateInterestedMenu()
    end

    local menu = self.interestedMenu
    local entries = self:GetInterestedEntries(record)
    menu.subtitle:SetText(addon.L.INTEREST_MENU_SUBTITLE)
    menu.empty:SetShown(#entries == 0)

    for index, row in ipairs(menu.rows) do
        local entry = entries[index]
        if entry then
            row.text:SetText(entry.text)
            if entry.roll > 0 and index == 1 then
                row.bg:SetColorTexture(0.22, 0.17, 0.05, 0.90)
            elseif entry.roll > 0 then
                row.bg:SetColorTexture(0.16, 0.12, 0.05, 0.88)
            else
                row.bg:SetColorTexture(0.10, 0.10, 0.12, 0.88)
            end
            row.whisperBtn.targetName = entry.name
            row.targetBtn.targetName = entry.name
            row:Show()
        else
            row:Hide()
        end
    end

    menu:ClearAllPoints()
    if anchor then
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    else
        menu:SetPoint("CENTER")
    end
    showPopupFrame(menu)
end

function addon:CreateInterestedMenu()
    local frame = createModernFrame("WhoNeedsInterestedMenu", UIParent)
    frame:SetSize(500, 332)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()
    frame:SetScript("OnMouseDown", function() end)
    frame:SetScript("OnMouseUp", function() end)
    frame:HookScript("OnHide", refreshPopupOverlay)
    registerEscapeFrame(frame)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.headerBg, "CENTER", 0, 0)
    frame.title:SetText(addon.L.INTEREST_MENU_TITLE)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", 16, -32)
    frame.subtitle:SetPoint("TOPRIGHT", -16, -32)
    frame.subtitle:SetJustifyH("LEFT")
    frame.subtitle:SetText(addon.L.INTEREST_MENU_SUBTITLE)

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("TOPLEFT", 18, -64)
    frame.empty:SetText(addon.L.NOBODY_YET)

    frame.rows = {}
    for index = 1, 10 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(464, 24)
        row:SetPoint("TOPLEFT", 18, -56 - ((index - 1) * 26))

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.10, 0.10, 0.12, 0.88)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetPoint("RIGHT", -120, 0)
        row.text:SetJustifyH("LEFT")

        row.whisperBtn = createModernButton(row, 42, 20, addon.L.ASK_BUTTON, "accent")
        row.whisperBtn:SetPoint("RIGHT", -50, 0)
        row.whisperBtn:SetScript("OnClick", function(self)
            if self.targetName and ChatFrame_SendTell then
                ChatFrame_SendTell(self.targetName)
            end
        end)

        row.targetBtn = createModernButton(row, 46, 20, addon.L.TARGET, "muted")
        row.targetBtn:SetPoint("RIGHT", 0, 0)
        row.targetBtn:SetScript("OnClick", function(self)
            if not self.targetName then
                return
            end
            local unit = addon:ResolveGroupUnitByName(self.targetName)
            if unit and TargetUnit then
                TargetUnit(unit)
            elseif TargetByName then
                TargetByName(self.targetName, true)
            end
        end)

        frame.rows[index] = row
    end

    return frame
end

function addon:GetItemUiDetails(itemLink)
    if not itemLink then
        return {
            icon = nil,
            coloredName = nil,
            slotText = addon.L.UNKNOWN_SLOT,
            subtypeText = addon.L.UNKNOWN_TYPE,
        }
    end

    local itemID = GetItemInfoInstant(itemLink)
    local presentation = addon:ResolveItemPresentation(itemLink, itemID)
    local _, _, _, _, _, itemType = GetItemInfo(itemLink)
    local slotText = (presentation.equipLoc and presentation.equipLoc ~= "" and _G[presentation.equipLoc]) or addon.L.MISC
    local subtypeText = presentation.itemSubType or itemType or addon.L.UNKNOWN_TYPE

    return {
        icon = presentation.icon,
        name = presentation.itemName or presentation.displayLink or itemLink,
        coloredName = presentation.coloredName or presentation.displayLink or itemLink,
        slotText = slotText,
        subtypeText = subtypeText,
        quality = presentation.quality,
        color = presentation.color,
    }
end

function addon:GetComparisonText(response, fallbackLabel)
    if not response then
        return fallbackLabel or addon.L.NO_DATA
    end

    local statusText = addon.L[response.status] or response.status or addon.L.UNKNOWN
    local deltaText = string.format("%+.1f", response.delta or 0)
    local baselineText = nil

    if response.baselineItemID and response.baselineItemID > 0 then
        local details = self:GetItemUiDetails("item:" .. response.baselineItemID)
        baselineText = string.format(
            addon.L.COMPARISON_VS_ITEM,
            details.coloredName or details.name or ("item:" .. response.baselineItemID),
            response.baselineItemLevel or "?"
        )
    elseif response.reason then
        baselineText = response.reason
    end

    if baselineText and baselineText ~= "" then
        return string.format("%s %s | %s", statusText, deltaText, baselineText)
    end

    return string.format("%s %s", statusText, deltaText)
end

function addon:GetShortComparisonText(response, fallbackLabel)
    if not response then
        return fallbackLabel or addon.L.NO_DATA
    end

    local statusText = addon.L[response.status] or response.status or addon.L.UNKNOWN
    local delta = response.delta or 0
    local deltaStr = ""
    
    if delta > 0 then
        deltaStr = string.format(" (+%.1f)", delta)
    elseif delta < 0 then
        deltaStr = string.format(" (%.1f)", delta)
    end
    
    local combinedStatus = string.format("%s%s", statusText, deltaStr)
    
    if response.status == "BIS" then
        combinedStatus = string.format("|cffffaa00%s|r", combinedStatus)
    elseif response.status == "UPGRADE" then
        if delta < 0 then
            combinedStatus = string.format("|cffff8800%s|r", combinedStatus) -- Orange
        else
            combinedStatus = string.format("|cff33ff99%s|r", combinedStatus) -- Green
        end
    elseif response.status == "SIDEGRADE" then
        combinedStatus = string.format("|cffaaffcc%s|r", combinedStatus)
    elseif response.status == "PASS" then
        combinedStatus = string.format("|cffaaaaaa%s|r", combinedStatus)
    end

    if response.reason and response.reason ~= "" then
        return string.format("%s | %s", combinedStatus, response.reason)
    end
    if response.summary and response.summary ~= "" then
        return string.format("%s | %s", combinedStatus, response.summary)
    end
    return combinedStatus
end

function addon:GetOwnerPanelText(record)
    if not record or record.ownerShort == self.playerName then
        return nil, addon.L.WAITING
    end

    local ownerResponse = record.responses[record.ownerShort]
    if ownerResponse then
        return ownerResponse, self:GetShortComparisonText(ownerResponse, addon.L.NO_DATA)
    end

    ownerResponse = self:GetOwnerInspectResponse(record)
    if ownerResponse then
        return ownerResponse, self:GetShortComparisonText(ownerResponse, addon.L.NO_DATA_LOOTER)
    end

    if self:IsInspectPendingForPlayer(record.ownerShort) then
        return nil, addon.L.WAITING
    end

    return nil, addon.L.NO_DATA_LOOTER
end

function addon:RefreshUI()
    if not self.frame then
        return
    end

    if self.currentTab == 3 then
        for i, row in ipairs(self.frame.rows) do row:Hide() end
        self.frame.empty:Hide()
        self.frame.pageText:Hide()
        self.frame.prevBtn:Hide()
        self.frame.nextBtn:Hide()
        return
    else
        self.frame.pageText:Show()
        self.frame.prevBtn:Show()
        self.frame.nextBtn:Show()
    end

    if self.frame.ownerInput:GetText() == "" then
        self.frame.ownerInput:SetText(self.playerName or "")
    end

    self.frame.pendingLootText:SetText("")
    self.frame.pendingLootText:Hide()

    if not self.currentViewInstance then
        if self.charDB and self.charDB.state and self.charDB.state.lastViewInstance and self.charDB.instances[self.charDB.state.lastViewInstance] then
            self.currentViewInstance = self.charDB.state.lastViewInstance
        else
            local firstKey = nil
            for k, _ in pairs(self.charDB.instances) do
                if k == "Global" then
                    self.currentViewInstance = "Global"
                    break
                end
                if not firstKey then firstKey = k end
            end
            if not self.currentViewInstance and firstKey then
                self.currentViewInstance = firstKey
            end
        end
    end

    local instDB = self.currentViewInstance and self.charDB.instances[self.currentViewInstance] or nil
    local history = instDB and instDB.lootHistory or {}
    local instName = instDB and instDB.name or addon.L.SELECT_INSTANCE
    
    self.frame.instanceDropBtn:SetText(instName)

    if self.currentViewInstance then
        self:SortInstanceLootHistory(self.currentViewInstance)
    end

    local filteredHistory = {}
    local checkEquippable = self.frame.equippableCheck and self.frame.equippableCheck:GetChecked()
    local checkOwnDrops = self.frame.ownDropsCheck and self.frame.ownDropsCheck:GetChecked()
    local checkTradable = self.frame.tradableCheck and self.frame.tradableCheck:GetChecked()
    for _, record in ipairs(history) do
        local include = true
        if checkEquippable then
            local localResponse = record.responses[self.playerName]
            local reason = localResponse and localResponse.reason or ""
            local status = localResponse and localResponse.status or ""
            if status == "PASS" and isEquipabilityFailure(reason) then
                include = false
            end
        end
        if not checkOwnDrops and record.ownerShort == self.playerName then
            include = false
        end
        if include and checkTradable then
            local tradable = self:IsLootTradableByOwner(record)
            if tradable == false then
                include = false
            end
        end
        
        if include then
            table.insert(filteredHistory, record)
        end
    end

    local availableHeight = self.frame:GetHeight() - math.abs(self.frame.rowsTopOffset or -76) - 52
    local maxRows = math.max(1, math.floor(availableHeight / LOOT_ROW_STEP))
    
    for idx = 1, maxRows do
        if not self.frame.rows[idx] then
            self.frame.rows[idx] = createRow(self.frame, idx)
        end
    end
    for _, r in ipairs(self.frame.rows) do
        r:Hide()
    end
    for idx = 1, maxRows do
        local r = self.frame.rows[idx]
        r:ClearAllPoints()
        if self.frame.listAnchor then
            r:SetPoint("TOPLEFT", self.frame.listAnchor, "TOPLEFT", 0, -((idx - 1) * LOOT_ROW_STEP))
            r:SetPoint("TOPRIGHT", self.frame.listAnchor, "TOPRIGHT", 0, -((idx - 1) * LOOT_ROW_STEP))
        else
            r:SetPoint("TOPLEFT", 12, self.frame.rowsTopOffset - ((idx - 1) * LOOT_ROW_STEP))
            r:SetPoint("TOPRIGHT", -12, self.frame.rowsTopOffset - ((idx - 1) * LOOT_ROW_STEP))
        end
    end

    local shown = 0
    local totalItems = #filteredHistory
    local totalPages = math.max(1, math.ceil(totalItems / maxRows))
    
    self.currentPage = self.currentPage or 1
    
    if self.currentPage > totalPages then
        self.currentPage = totalPages
    end
    if self.currentPage < 1 then
        self.currentPage = 1
    end
    
    self.frame.pageText:SetText(string.format(addon.L.PAGE, self.currentPage, totalPages))
    self.frame.prevBtn:SetEnabled(self.currentPage > 1)
    self.frame.nextBtn:SetEnabled(self.currentPage < totalPages)

    local startIndex = ((self.currentPage - 1) * maxRows) + 1

    for rowIdx = 1, maxRows do
        local row = self.frame.rows[rowIdx]
        local dataIndex = startIndex + rowIdx - 1
        local record = filteredHistory[dataIndex]
        if row and record then
            row:Show()
            shown = shown + 1
            local ownerLabel = self:GetColoredName(record.owner, record.ownerClass)
            local localResponse = record.responses[self.playerName]
            local details = self:GetItemUiDetails(record.itemLink)
            local itemLabel = details.coloredName or details.name or record.itemName or ("item:" .. tostring(record.itemID))
            local title = string.format(addon.L.LOOTED_BY, ownerLabel, itemLabel)
            local detailsParts = {}
            if details.slotText and details.slotText ~= addon.L.MISC then
                table.insert(detailsParts, details.slotText)
            end
            if details.subtypeText and details.subtypeText ~= addon.L.UNKNOWN_TYPE then
                table.insert(detailsParts, details.subtypeText)
            end
            if localResponse and localResponse.summary and localResponse.summary ~= "" then
                table.insert(detailsParts, "|cffffffff" .. localResponse.summary .. "|r")
            end
            local whisperSummary = self:GetWhisperSummary(record, record.owner)
            if whisperSummary then
                table.insert(detailsParts, "|cff88ccff" .. whisperSummary .. "|r")
            end
            local ownerLine = nil
            local ownerResponse = nil
            local tradableState = self:GetLootTradableState(record)
            local tradableText, tradableColor = getTradableLabel(tradableState)
            table.insert(detailsParts, string.format("|cff%s%s|r", tradableColor, tradableText))
            local detail = table.concat(detailsParts, "  " .. addon.L.META_SEPARATOR .. "  ")
            if record.ownerShort == self.playerName then
                ownerLine = self:GetShortComparisonText(localResponse, addon.L.WAITING)
                row.ownerPanel:Hide()
                row.youPanel:ClearAllPoints()
                row.youPanel:SetPoint("TOPLEFT", row.statusArea, "TOPLEFT", 54, 0)
                row.youPanel:SetSize(464, 28)
            else
                ownerResponse, ownerLine = self:GetOwnerPanelText(record)
                row.ownerPanel:Show()
                row.youPanel:ClearAllPoints()
                row.youPanel:SetPoint("LEFT", row.ownerPanel, "RIGHT", 8, 0)
                row.youPanel:SetSize(228, 28)
                setStatusPanelColor(row.ownerPanel.bg, ownerResponse)
            end

            local yourLine = self:GetShortComparisonText(localResponse, addon.L.WAITING)
            local verdictText, verdictR, verdictG, verdictB = getLootVerdict(record, localResponse, ownerResponse, tradableState)

            row.iconBtn.itemLink = record.itemLink

            row.verdictText:SetText(verdictText)
            row.verdictText:SetTextColor(verdictR, verdictG, verdictB)
            row.verdictBar:SetColorTexture(verdictR, verdictG, verdictB, 0.95)
            row.bg:SetColorTexture(verdictR * 0.12, verdictG * 0.12, verdictB * 0.12, 0.92)
            row.title:SetText(title)
            row.meta:SetText(detail)
            row.ilvlText:SetText(record.localItemLevel and ("iLvl " .. record.localItemLevel) or "")
            row.ownerPanel.label:SetText(self:GetColoredName(record.owner, record.ownerClass))
            row.ownerPanel.value:SetText(ownerLine)
            row.youPanel.value:SetText(yourLine)
            row.groupInterest:SetText(self:BuildInterestLine(record))
            setStatusPanelColor(row.youPanel.bg, localResponse)
            row.icon:SetTexture(details.icon or 134400)
            if details.color then
                local r, g, b = details.color.r, details.color.g, details.color.b
                row.iconBorder:SetVertexColor(r, g, b, 1)
                row.iconBorder:Show()
                if CreateColor then
                    row.glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.32), CreateColor(r, g, b, 0))
                else
                    row.glow:SetGradientAlpha("HORIZONTAL", r, g, b, 0.32, r, g, b, 0)
                end
                row.glow:Show()
            else
                row.iconBorder:Hide()
                row.glow:Hide()
            end
            local wantsIt = localResponse and localResponse.status ~= "PASS"
            if wantsIt then
                row.interestBtn:SetText(addon.L.PASS)
                row.interestBtn:SetVariant("muted")
            else
                row.interestBtn:SetText(addon.L.NEED)
                row.interestBtn:SetVariant("positive")
            end

            row.icon:SetTexture(details.icon or 134400)
            row.button.ownerName = record.owner
            row.rapidAskBtn.ownerName = record.owner
            row.itemLink = record.itemLink
            row.button.record = record
            row.rapidAskBtn.record = record
            row.rollBtn.record = record
            row.button.localResponse = localResponse
            row.rapidAskBtn.localResponse = localResponse
            row.rollBtn.localResponse = localResponse
            row.itemKey = record.key
            row.instanceKey = self.currentViewInstance
            row.record = record
            row.footerArea.record = record
            local fastRemaining = self:GetFastWhisperRemaining(record, record.owner)

            local whisperState = self:GetWhisperState(record, record.owner)
            if whisperState and whisperState.count and whisperState.count > 0 then
                row.button:Disable()
                row.button:SetText(addon.L.WHISPER_SENT_MARK)
                row.rapidAskBtn:Disable()
                row.rapidAskBtn:SetText(addon.L.WHISPERED)
            else
                row.button:Enable()
                row.button:SetText(addon.L.ASK_BUTTON)
                row.rapidAskBtn:Enable()
                row.rapidAskBtn:SetText(addon.L.FAST_ASK)
            end

            if whisperState and whisperState.count and whisperState.count > 0 then
                row.button:Enable()
                row.button:SetText(addon.L.ASK_AGAIN)
                row.button:SetVariant("accent")
                if fastRemaining > 0 then
                    row.rapidAskBtn:Disable()
                    row.rapidAskBtn:SetText(string.format("%ds", math.ceil(fastRemaining)))
                    row.rapidAskBtn:SetVariant("muted")
                else
                    row.rapidAskBtn:Enable()
                    row.rapidAskBtn:SetText(addon.L.FAST_ASK)
                    row.rapidAskBtn:SetVariant("accent")
                end
            else
                row.button:SetVariant("muted")
                row.rapidAskBtn:SetVariant("accent")
            end

            row.button:SetShown(true)
            row.deleteBtn:SetShown(true)
            row.interestBtn:SetShown(true)
            row.rollBtn:SetShown(true)
            row.rapidAskBtn:SetShown(true)
            row:Show()
        elseif row then
            row:Hide()
        end
    end

    self.frame.empty:SetShown(shown == 0)
    if self.frame:IsShown() then
        self:MarkLootSeen()
    end
end

