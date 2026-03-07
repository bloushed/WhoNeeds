local _, ns = ...
local addon = ns and ns.Addon or _G.WhoNeeds

local MINIMAP_BUTTON_RADIUS = 92
local MINIMAP_ICON = "Interface\\AddOns\\WhoNeeds\\Media\\WhoNeedsIcon"
local LOOT_ROW_HEIGHT = 100
local LOOT_ROW_STEP = 108

local function setStatusPanelColor(texture, response)
    if not texture then
        return
    end

    local status = response and response.status or nil
    local reason = response and response.reason or ""

    if status == "PASS" and (reason == "Class cannot equip it" or reason == "Class cannot equip this weapon" or reason == "Class cannot equip shields" or reason == "Wrong armor type" or reason == "Unknown weapon slot" or reason == "Not equippable" or reason == "Missing item" or reason == "Unknown slot") then
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

local function createAskMenu()
    local frame = CreateFrame("Frame", "WhoNeedsAskMenu", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(500, 320)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
    frame.title:SetText("Ask...")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", 16, -32)
    frame.subtitle:SetPoint("TOPRIGHT", -16, -32)
    frame.subtitle:SetJustifyH("LEFT")
    frame.subtitle:SetText("Choose a whisper to send.")

    frame.buttons = {}
    for index = 1, 10 do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(452, 22)
        button:SetPoint("TOPLEFT", 18, -56 - ((index - 1) * 24))
        button:GetFontString():SetJustifyH("LEFT")
        button:GetFontString():SetWidth(430)
        button:SetScript("OnClick", function(self)
            if not frame.target or not self.message then
                return
            end
            SendChatMessage(self.message, "WHISPER", nil, frame.target)
            frame:Hide()
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

local function createRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(LOOT_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, (parent.rowsTopOffset or -76) - ((index - 1) * LOOT_ROW_STEP))
    row:SetPoint("TOPRIGHT", -12, (parent.rowsTopOffset or -76) - ((index - 1) * LOOT_ROW_STEP))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.07, 0.08, 0.10, 0.94)

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

    row.glow = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.glow:SetPoint("TOPLEFT", row.bg, "TOPLEFT")
    row.glow:SetPoint("BOTTOMLEFT", row.bg, "BOTTOMLEFT")
    row.glow:SetWidth(420)
    row.glow:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    row.glow:SetBlendMode("ADD")
    row.glow:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(42, 42)
    row.icon:SetPoint("TOPLEFT", 14, -14)

    row.iconBg = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.iconBg:SetPoint("TOPLEFT", row.icon, -4, 4)
    row.iconBg:SetPoint("BOTTOMRIGHT", row.icon, 4, -4)
    row.iconBg:SetColorTexture(0.03, 0.03, 0.04, 0.95)

    row.iconBorder = row:CreateTexture(nil, "OVERLAY")
    row.iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    row.iconBorder:SetSize(62, 62)
    row.iconBorder:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
    row.iconBorder:SetBlendMode("ADD")
    row.iconBorder:Hide()

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -1)
    row.title:SetPoint("TOPRIGHT", -96, -14)
    row.title:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)
    row.meta:SetPoint("TOPRIGHT", -96, -20)
    row.meta:SetJustifyH("LEFT")
    row.meta:SetTextColor(0.70, 0.72, 0.76)

    row.ownerPanel = CreateFrame("Frame", nil, row)
    row.ownerPanel:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -34)
    row.ownerPanel:SetSize(228, 28)
    row.ownerPanel.bg = row.ownerPanel:CreateTexture(nil, "BACKGROUND")
    row.ownerPanel.bg:SetAllPoints()
    row.ownerPanel.bg:SetColorTexture(0.12, 0.12, 0.14, 0.9)
    row.ownerPanel.label = row.ownerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.ownerPanel.label:SetPoint("TOPLEFT", 8, -4)
    row.ownerPanel.label:SetText(addon.L.OWNER)
    row.ownerPanel.value = row.ownerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.ownerPanel.value:SetPoint("TOPLEFT", row.ownerPanel.label, "BOTTOMLEFT", 0, -1)
    row.ownerPanel.value:SetPoint("TOPRIGHT", -8, -16)
    row.ownerPanel.value:SetJustifyH("LEFT")

    row.youPanel = CreateFrame("Frame", nil, row)
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

    row.footerLine = row:CreateTexture(nil, "ARTWORK")
    row.footerLine:SetPoint("LEFT", 14, 0)
    row.footerLine:SetPoint("RIGHT", -14, 0)
    row.footerLine:SetHeight(1)
    row.footerLine:SetPoint("BOTTOM", row, "BOTTOM", 0, 28)
    row.groupInterest = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.groupInterest:SetPoint("BOTTOMLEFT", 14, 12)
    row.groupInterest:SetPoint("BOTTOMRIGHT", -14, 12)
    row.groupInterest:SetJustifyH("LEFT")

    row.btnContainer = CreateFrame("Frame", nil, row)
    row.btnContainer:SetPoint("TOPRIGHT", -12, -12)
    row.btnContainer:SetSize(270, 24)

    row.deleteBtn = CreateFrame("Button", nil, row.btnContainer, "UIPanelButtonTemplate")
    row.deleteBtn:SetSize(24, 24)
    row.deleteBtn:SetPoint("RIGHT", 0, 0)
    row.deleteBtn:SetText("X")
    row.deleteBtn:SetScript("OnClick", function(self)
        if row.itemKey and row.instanceKey then
            addon:DeleteLootRecord(row.instanceKey, row.itemKey)
        end
    end)

    row.button = CreateFrame("Button", nil, row.btnContainer, "UIPanelButtonTemplate")
    row.button:SetSize(60, 24)
    row.button:SetPoint("RIGHT", row.deleteBtn, "LEFT", -4, 0)
    row.button:SetText(addon.L.ASK_BUTTON)
    row.button:SetScript("OnClick", function(self)
        local target = self.ownerName
        if not target then
            return
        end
        addon:ShowAskMenu(target, self.record, self.localResponse, self)
    end)

    row.rapidAskBtn = CreateFrame("Button", nil, row.btnContainer, "UIPanelButtonTemplate")
    row.rapidAskBtn:SetSize(72, 24)
    row.rapidAskBtn:SetPoint("RIGHT", row.button, "LEFT", -4, 0)
    row.rapidAskBtn:SetText(addon.L.FAST_ASK)
    row.rapidAskBtn:SetScript("OnClick", function(self)
        local target = self.ownerName
        if not target or not self.record then return end
        
        local templates = addon.db and addon.db.options and addon.db.options.askTemplates or {}
        local fastIndex = addon.db and addon.db.options and addon.db.options.fastAskIndex or 1
        local template = templates[fastIndex] or "Can I get {item}?"
        
        local message = addon:FormatWhisperTemplate(template, self.record, self.localResponse)
        SendChatMessage(message, "WHISPER", nil, target)
        print("|cff33ff99WhoNeeds|r Sent to " .. target .. ": " .. message)
    end)

    row.interestBtn = CreateFrame("Button", nil, row.btnContainer, "UIPanelButtonTemplate")
    row.interestBtn:SetSize(60, 24)
    row.interestBtn:SetPoint("RIGHT", row.rapidAskBtn, "LEFT", -4, 0)
    row.interestBtn:SetText(addon.L.NEED)
    row.interestBtn:SetScript("OnClick", function(self)
        if not row.record then return end
        
        local currentRes = row.record.responses[addon.playerName]
        local isCurrentlyInterested = currentRes and currentRes.status ~= "PASS"
        local newStatus = isCurrentlyInterested and "PASS" or "UPGRADE"
        
        local response = {
            status = newStatus,
            delta = currentRes and currentRes.delta or 0,
            itemLevel = currentRes and currentRes.itemLevel or 0,
            reason = "Manual override"
        }
        
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
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetSize(width, height)
    box:SetFontObject("ChatFontNormal")
    return box
end

function addon:CreateUI()
    if self.frame then
        return
    end

    local defaultHeight = self.db and self.db.options and self.db.options.frameHeight or 508
    local frame = CreateFrame("Frame", "WhoNeedsFrame", UIParent, "BasicFrameTemplateWithInset")
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
    frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
    frame.title:SetText("WhoNeeds")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", 16, -12)
    frame.subtitle:SetText("Boss loot relevance for the current spec")

    frame.simLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.simLabel:SetPoint("TOPLEFT", 18, -44)
    frame.simLabel:SetText(addon.L.SIMULATION_LABEL)

    frame.simInput = createEditBox(frame, 280, 24)
    frame.simInput:SetPoint("TOPLEFT", 18, -62)
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

    frame.forceCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.forceCheck:SetPoint("TOPLEFT", frame.simHint, "BOTTOMLEFT", -2, -2)
    frame.forceCheck.text:SetText(addon.L.FORCE_INTEREST)

    frame.simButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.simButton:SetSize(84, 22)
    frame.simButton:SetPoint("LEFT", frame.ownerInput, "RIGHT", 10, 0)
    frame.simButton:SetText(addon.L.SIM_BUTTON)
    frame.simButton:SetScript("OnClick", function()
        addon:SimulateLootInput(frame.simInput:GetText(), frame.ownerInput:GetText(), frame.forceCheck:GetChecked())
    end)

    frame.instanceDropBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.instanceDropBtn:SetSize(200, 22)
    frame.instanceDropBtn:SetPoint("TOPLEFT", 18, -44)
    frame.instanceDropBtn:SetText(addon.L.SELECT_INSTANCE)
    frame.instanceDropBtn:SetScript("OnClick", function(self)
        addon:ShowInstanceMenu(self)
    end)
    
    frame.deleteInstanceBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.deleteInstanceBtn:SetSize(110, 22)
    frame.deleteInstanceBtn:SetPoint("LEFT", frame.instanceDropBtn, "RIGHT", 10, 0)
    frame.deleteInstanceBtn:SetText(addon.L.DELETE_INSTANCE)
    frame.deleteInstanceBtn:SetScript("OnClick", function(self)
        if addon.currentViewInstance then
            addon:DeleteInstance(addon.currentViewInstance)
        end
    end)
    
    frame.equippableCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.equippableCheck:SetPoint("LEFT", frame.deleteInstanceBtn, "RIGHT", 10, 0)
    frame.equippableCheck.text:SetText(addon.L.USABLE_ONLY)
    frame.equippableCheck:SetChecked(true)
    frame.equippableCheck:SetScript("OnClick", function()
        addon.currentPage = 1
        addon:RefreshUI()
    end)
    
    frame.ownDropsCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.ownDropsCheck:SetPoint("LEFT", frame.equippableCheck, "RIGHT", 100, 0)
    frame.ownDropsCheck.text:SetText(addon.L.OWN_DROPS)
    frame.ownDropsCheck:SetChecked(true)
    frame.ownDropsCheck:SetScript("OnClick", function()
        addon.currentPage = 1
        addon:RefreshUI()
    end)

    frame.askMenu = createAskMenu()

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("TOPLEFT", 18, -130)
    frame.empty:SetText(addon.L.EMPTY_LOOT)

    frame.rowsTopOffset = -76
    frame.rows = {}

    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.pageText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
    frame.pageText:SetText("Page 1 / 1")
    
    frame.prevBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.prevBtn:SetSize(80, 22)
    frame.prevBtn:SetPoint("RIGHT", frame.pageText, "LEFT", -15, 0)
    frame.prevBtn:SetText(addon.L.PREVIOUS)
    frame.prevBtn:SetScript("OnClick", function()
        addon.currentPage = math.max(1, (addon.currentPage or 1) - 1)
        addon:RefreshUI()
    end)
    
    frame.nextBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.nextBtn:SetSize(80, 22)
    frame.nextBtn:SetPoint("LEFT", frame.pageText, "RIGHT", 15, 0)
    frame.nextBtn:SetText(addon.L.NEXT)
    frame.nextBtn:SetScript("OnClick", function()
        addon.currentPage = (addon.currentPage or 1) + 1
        addon:RefreshUI()
    end)

    frame.tab1 = CreateFrame("Button", "$parentTab1", frame, "PanelTabButtonTemplate")
    frame.tab1:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, -28)
    frame.tab1:SetText(addon.L.LOOTS)
    frame.tab1:SetID(1)
    frame.tab1:SetScript("OnClick", function() addon:SelectTab(1) end)

    frame.tab2 = CreateFrame("Button", "$parentTab2", frame, "PanelTabButtonTemplate")
    frame.tab2:SetPoint("LEFT", frame.tab1, "RIGHT", 4, 0)
    frame.tab2:SetText(addon.L.SIMULATIONS)
    frame.tab2:SetID(2)
    frame.tab2:SetScript("OnClick", function() addon:SelectTab(2) end)
    
    frame.tab3 = CreateFrame("Button", "$parentTab3", frame, "PanelTabButtonTemplate")
    frame.tab3:SetPoint("LEFT", frame.tab2, "RIGHT", 4, 0)
    frame.tab3:SetText(addon.L.SETTINGS)
    frame.tab3:SetID(3)
    frame.tab3:SetScript("OnClick", function() addon:SelectTab(3) end)
    
    PanelTemplates_SetNumTabs(frame, 3)

    frame.settingsList = CreateFrame("Frame", nil, frame)
    frame.settingsList:SetPoint("TOPLEFT", 18, -44)
    frame.settingsList:SetPoint("BOTTOMRIGHT", -18, 18)
    frame.settingsList:Hide()

    local autoOpenCheck = CreateFrame("CheckButton", nil, frame.settingsList, "UICheckButtonTemplate")
    autoOpenCheck:SetPoint("TOPLEFT", 0, 0)
    autoOpenCheck.text:SetText(addon.L.AUTO_OPEN)
    
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
    
    local sTitle = frame.settingsList:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sTitle:SetPoint("TOPLEFT", 0, -50)
    sTitle:SetText(addon.L.FAST_ASK_TITLE)
    
    local sDesc = frame.settingsList:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sDesc:SetPoint("TOPLEFT", sTitle, "BOTTOMLEFT", 0, -6)
    sDesc:SetText(addon.L.FAST_ASK_DESC)
    sDesc:SetJustifyH("LEFT")

    local langDropBtn = CreateFrame("Button", nil, frame.settingsList, "UIPanelButtonTemplate")
    langDropBtn:SetSize(120, 22)
    langDropBtn:SetPoint("TOPRIGHT", frame.settingsList, "TOPRIGHT", -12, 0)
    
    local langLabel = frame.settingsList:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    langLabel:SetPoint("RIGHT", langDropBtn, "LEFT", -8, 0)
    langLabel:SetText(addon.L.LANGUAGE)
    
    local function updateLangBtnText()
        local lopt = addon.db and addon.db.options and addon.db.options.language or "AUTO"
        if lopt == "frFR" then langDropBtn:SetText("Français")
        elseif lopt == "enUS" then langDropBtn:SetText("English")
        else langDropBtn:SetText("Auto (Client)") end
    end
    updateLangBtnText()
    
    local function langOnClick(self)
        if not addon.langMenu then
            local lm = CreateFrame("Frame", "WhoNeedsLangMenu", UIParent, "BasicFrameTemplateWithInset")
            lm:SetSize(200, 160)
            lm:SetFrameStrata("DIALOG")
            lm.title = lm:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lm.title:SetPoint("CENTER", lm.TitleBg, "CENTER", 0, 0)
            lm.title:SetText(addon.L.LANGUAGE)
            lm.scrollChild = CreateFrame("Frame")
            lm.scrollChild:SetSize(160, 100)
            lm.scrollFrame = CreateFrame("ScrollFrame", nil, lm, "UIPanelScrollFrameTemplate")
            lm.scrollFrame:SetPoint("TOPLEFT", 12, -32)
            lm.scrollFrame:SetPoint("BOTTOMRIGHT", -32, 12)
            lm.scrollFrame:SetScrollChild(lm.scrollChild)
            
            local opts = { {k="AUTO", v="Auto (Client)"}, {k="enUS", v="English"}, {k="frFR", v="Français"} }
            local yOffs = -4
            for i, opt in ipairs(opts) do
                local b = CreateFrame("Button", nil, lm.scrollChild, "UIPanelButtonTemplate")
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
        addon.langMenu:Show()
    end
    langDropBtn:SetScript("OnClick", langOnClick)

    frame.settingRows = {}
    for i = 1, 8 do
        local r = CreateFrame("Frame", nil, frame.settingsList)
        r:SetSize(600, 32)
        r:SetPoint("TOPLEFT", 0, -106 - ((i - 1) * 36))
        
        local check = CreateFrame("CheckButton", nil, r, "UIRadioButtonTemplate")
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
    
    if PanelTemplates_SetTab then
        PanelTemplates_SetTab(self.frame, tabID)
    end
    
    local isSim = (tabID == 2)
    local isSettings = (tabID == 3)
    
    self.frame.simLabel:SetShown(isSim)
    self.frame.simInput:SetShown(isSim)
    self.frame.ownerInput:SetShown(isSim)
    self.frame.simHint:SetShown(isSim)
    self.frame.forceCheck:SetShown(isSim)
    self.frame.simButton:SetShown(isSim)
    
    self.frame.instanceDropBtn:SetShown(not isSim and not isSettings)
    self.frame.deleteInstanceBtn:SetShown(not isSim and not isSettings)
    self.frame.equippableCheck:SetShown(not isSim and not isSettings)
    self.frame.ownDropsCheck:SetShown(not isSim and not isSettings)
    
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

    local button = CreateFrame("Button", "WhoNeedsMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
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
        GameTooltip:AddLine("Left-click: open or close the loot window.", 1, 1, 1, true)
        if addon.hasUnreadLoot then
            GameTooltip:AddLine("New loot available.", 0.25, 1, 0.25, true)
        else
            GameTooltip:AddLine("No unread loot right now.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine("Right-click: clear the new loot flag.", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Drag: move around the minimap.", 0.7, 0.7, 0.7, true)
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
    if minimapOptions.hidden then
        self.minimapButton:Hide()
        return
    end

    updateMinimapButtonPosition(self.minimapButton, minimapOptions.angle or 225)
    self.minimapButton.badge:SetShown(self.hasUnreadLoot)
    self.minimapButton:Show()
end

local function createInstanceMenu()
    local frame = CreateFrame("Frame", "WhoNeedsInstanceMenu", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(300, 400)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
    frame.title:SetText("Select Instance")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
    frame.subtitle:SetJustifyH("LEFT")

    frame.scrollFrame = CreateFrame("ScrollFrame", "WhoNeedsAskMenuScroll", frame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", 12, -32)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -32, 12)

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
    if self.db and self.db.instances then
        for key, instDB in pairs(self.db.instances) do
            table.insert(instances, { key = key, name = instDB.name })
        end
    end
    table.sort(instances, function(a, b) return (a.name or "") < (b.name or "") end)
    
    local yOffset = -4
    for i, inst in ipairs(instances) do
        local btn = menu.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, menu.scrollChild, "UIPanelButtonTemplate")
            btn:SetSize(240, 24)
            btn:GetFontString():SetJustifyH("LEFT")
            menu.buttons[i] = btn
        end
        
        btn:SetText(" " .. (inst.name or "Unknown"))
        btn.instanceKey = inst.key
        btn:SetPoint("TOPLEFT", 8, yOffset)
        btn:SetScript("OnClick", function(self)
            addon.currentViewInstance = self.instanceKey
            addon.currentPage = 1
            if addon.db and addon.db.options then
                addon.db.options.lastViewInstance = self.instanceKey
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
    menu:Show()
end

function addon:ShowAskMenu(target, record, localResponse, anchor)
    self:CreateUI()

    local askMenu = self.frame and self.frame.askMenu
    if not askMenu then
        return
    end

    askMenu.target = target
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
    askMenu:Show()
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

function addon:BuildInterestLine(record)
    local interested = {}
    for playerName, response in pairs(record.responses) do
        if response.status ~= "PASS" then
            local profile = self.peerProfiles[playerName]
            local classFile = profile and profile.classFile
            local status = addon.L[response.status] or response.status
            local detail = string.format("%s (%s %.1f)", self:GetColoredName(playerName, classFile), status, response.delta or 0)
            table.insert(interested, { name = playerName, text = detail, score = response.delta or 0 })
        end
    end
    if #interested == 0 then
        return addon.L.INTERESTED .. addon.L.NOBODY_YET
    end
    table.sort(interested, function(a, b) return a.score > b.score end)
    local texts = {}
    for _, entry in ipairs(interested) do
        table.insert(texts, entry.text)
    end
    return addon.L.INTERESTED .. table.concat(texts, ", ")
end

function addon:GetItemUiDetails(itemLink)
    if not itemLink then
        return {
            icon = nil,
            coloredName = nil,
            slotText = "Unknown slot",
            subtypeText = "Unknown type",
        }
    end

    local itemID = GetItemInfoInstant(itemLink)
    local presentation = addon:ResolveItemPresentation(itemLink, itemID)
    local _, _, _, _, _, itemType = GetItemInfo(itemLink)
    local slotText = (presentation.equipLoc and presentation.equipLoc ~= "" and _G[presentation.equipLoc]) or "Misc"
    local subtypeText = presentation.itemSubType or itemType or "Unknown type"

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
        return fallbackLabel or "No data"
    end

    local statusText = addon.L[response.status] or response.status or "Unknown"
    local deltaText = string.format("%+.1f", response.delta or 0)
    local baselineText = nil

    if response.baselineItemID and response.baselineItemID > 0 then
        local details = self:GetItemUiDetails("item:" .. response.baselineItemID)
        baselineText = string.format(
            "vs %s (iLvl %s)",
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
        return fallbackLabel or "No data"
    end

    local statusText = addon.L[response.status] or response.status or "Unknown"
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
    return combinedStatus
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

    if not self.currentViewInstance then
        if self.db and self.db.options and self.db.options.lastViewInstance and self.db.instances[self.db.options.lastViewInstance] then
            self.currentViewInstance = self.db.options.lastViewInstance
        else
            local firstKey = nil
            for k, _ in pairs(self.db.instances) do
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

    local instDB = self.currentViewInstance and self.db.instances[self.currentViewInstance] or nil
    local history = instDB and instDB.lootHistory or {}
    local instName = instDB and instDB.name or "Select Instance..."
    
    self.frame.instanceDropBtn:SetText(instName)

    if self.currentViewInstance then
        self:SortInstanceLootHistory(self.currentViewInstance)
    end

    local filteredHistory = {}
    local checkEquippable = self.frame.equippableCheck and self.frame.equippableCheck:GetChecked()
    local checkOwnDrops = self.frame.ownDropsCheck and self.frame.ownDropsCheck:GetChecked()
    for _, record in ipairs(history) do
        local include = true
        if checkEquippable then
            local localResponse = record.responses[self.playerName]
            local reason = localResponse and localResponse.reason or ""
            local status = localResponse and localResponse.status or ""
            if status == "PASS" and (reason == "Class cannot equip it" or reason == "Class cannot equip this weapon" or reason == "Class cannot equip shields" or reason == "Wrong armor type" or reason == "Unknown weapon slot" or reason == "Not equippable" or reason == "Missing item" or reason == "Unknown slot") then
                include = false
            end
        end
        if not checkOwnDrops and record.ownerShort == self.playerName then
            include = false
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
        r:SetPoint("TOPLEFT", 12, self.frame.rowsTopOffset - ((idx - 1) * LOOT_ROW_STEP))
        r:SetPoint("TOPRIGHT", -12, self.frame.rowsTopOffset - ((idx - 1) * LOOT_ROW_STEP))
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
            local title = string.format("%s looted %s", ownerLabel, itemLabel)
            local detailsParts = {}
            if record.localItemLevel then
                table.insert(detailsParts, "|cffffcc00iLvl " .. record.localItemLevel .. "|r")
            end
            if details.slotText and details.slotText ~= "Misc" then
                table.insert(detailsParts, details.slotText)
            end
            if details.subtypeText and details.subtypeText ~= "Unknown type" then
                table.insert(detailsParts, details.subtypeText)
            end
            if localResponse and localResponse.summary and localResponse.summary ~= "" then
                table.insert(detailsParts, "|cffffffff" .. localResponse.summary .. "|r")
            end
            local detail = table.concat(detailsParts, "  •  ")

            local ownerLine = nil
            if record.ownerShort == self.playerName then
                ownerLine = self:GetShortComparisonText(localResponse, addon.L.WAITING)
                row.ownerPanel:Hide()
                row.youPanel:ClearAllPoints()
                row.youPanel:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -34)
                row.youPanel:SetSize(464, 28)
            else
                local ownerResponse = record.responses[record.ownerShort]
                if not ownerResponse then
                    ownerResponse = self:GetOwnerInspectResponse(record)
                end
                ownerLine = self:GetShortComparisonText(ownerResponse, addon.L.WAITING)
                row.ownerPanel:Show()
                row.youPanel:ClearAllPoints()
                row.youPanel:SetPoint("LEFT", row.ownerPanel, "RIGHT", 8, 0)
                row.youPanel:SetSize(228, 28)
                setStatusPanelColor(row.ownerPanel.bg, ownerResponse)
            end
            
            local yourLine = self:GetShortComparisonText(localResponse, addon.L.WAITING)

            row.title:SetText(title)
            row.meta:SetText(detail)
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
                    row.glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.25), CreateColor(r, g, b, 0))
                else
                    row.glow:SetGradientAlpha("HORIZONTAL", r, g, b, 0.25, r, g, b, 0)
                end
                row.glow:Show()
            else
                row.iconBorder:Hide()
                row.glow:Hide()
            end
            local wantsIt = localResponse and localResponse.status ~= "PASS"
            if wantsIt then
                row.interestBtn:SetText("Pass")
            else
                row.interestBtn:SetText("Need !")
            end

            row.icon:SetTexture(details.icon or 134400)
            row.button.ownerName = record.owner
            row.rapidAskBtn.ownerName = record.owner
            row.itemLink = record.itemLink
            row.button.record = record
            row.rapidAskBtn.record = record
            row.button.localResponse = localResponse
            row.rapidAskBtn.localResponse = localResponse
            row.button:SetShown(true)
            row.instanceKey = self.currentViewInstance
            row.itemKey = record.key
            row.record = record
            row.deleteBtn:SetShown(true)
            row.interestBtn:SetShown(true)
            row.rapidAskBtn:SetShown(record.ownerShort ~= self.playerName)
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
