local addonName, ns = ...
ns = ns or {}

local addon = {}
ns.Addon = addon
_G[addonName] = addon

addon.name = addonName
addon.prefix = "WhoNeedsV1"
addon.playerName = nil
addon.db = nil
addon.charDB = nil
addon.lootByKey = {}
addon.peerProfiles = {}
addon.localProfile = {}
addon.localGear = {}
addon.externalData = nil
addon.simulationCounter = 0
addon.inspectQueue = {}
addon.inspectCache = {}
addon.inspectCacheByName = {}
addon.pendingInspect = nil
addon.inspectTimeout = nil
addon.hasUnreadLoot = false
addon.whisperCooldownTimers = {}
addon.pendingEncounterLoot = nil
addon.pendingEncounterLootTimer = nil

addon.constants = {
    slotNames = {
        [1] = "Head",
        [2] = "Neck",
        [3] = "Shoulder",
        [5] = "Chest",
        [6] = "Waist",
        [7] = "Legs",
        [8] = "Feet",
        [9] = "Wrist",
        [10] = "Hands",
        [11] = "Finger 1",
        [12] = "Finger 2",
        [13] = "Trinket 1",
        [14] = "Trinket 2",
        [15] = "Back",
        [16] = "Main Hand",
        [17] = "Off Hand",
        [19] = "Tabard",
    },
    inspectSlotIDs = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 },
    armorSubclassByClass = {
        DEATHKNIGHT = 4,
        DEMONHUNTER = 2,
        DRUID = 2,
        EVOKER = 3,
        HUNTER = 3,
        MAGE = 1,
        MONK = 2,
        PALADIN = 4,
        PRIEST = 1,
        ROGUE = 2,
        SHAMAN = 3,
        WARLOCK = 1,
        WARRIOR = 4,
    },
    equipLocToSlots = {
        INVTYPE_HEAD = { 1 },
        INVTYPE_NECK = { 2 },
        INVTYPE_SHOULDER = { 3 },
        INVTYPE_CHEST = { 5 },
        INVTYPE_ROBE = { 5 },
        INVTYPE_WAIST = { 6 },
        INVTYPE_LEGS = { 7 },
        INVTYPE_FEET = { 8 },
        INVTYPE_WRIST = { 9 },
        INVTYPE_HAND = { 10 },
        INVTYPE_FINGER = { 11, 12 },
        INVTYPE_TRINKET = { 13, 14 },
        INVTYPE_CLOAK = { 15 },
        INVTYPE_WEAPON = { 16, 17 },
        INVTYPE_WEAPONMAINHAND = { 16 },
        INVTYPE_WEAPONOFFHAND = { 17 },
        INVTYPE_2HWEAPON = { 16, 17 },
        INVTYPE_HOLDABLE = { 17 },
        INVTYPE_SHIELD = { 17 },
        INVTYPE_RANGED = { 16 },
        INVTYPE_RANGEDRIGHT = { 16 },
        INVTYPE_TABARD = { 19 },
    },
    statKeyMap = {
        ITEM_MOD_CRIT_RATING = "CRIT",
        ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
        ITEM_MOD_HASTE_RATING = "HASTE",
        ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
        ITEM_MOD_MASTERY_RATING = "MASTERY",
        ITEM_MOD_MASTERY_RATING_SHORT = "MASTERY",
        ITEM_MOD_VERSATILITY = "VERS",
        ITEM_MOD_VERSATILITY_SHORT = "VERS",
        ITEM_MOD_STAMINA = "STAMINA",
        ITEM_MOD_STAMINA_SHORT = "STAMINA",
        ITEM_MOD_STRENGTH = "STRENGTH",
        ITEM_MOD_STRENGTH_SHORT = "STRENGTH",
        ITEM_MOD_AGILITY = "AGILITY",
        ITEM_MOD_AGILITY_SHORT = "AGILITY",
        ITEM_MOD_INTELLECT = "INTELLECT",
        ITEM_MOD_INTELLECT_SHORT = "INTELLECT",
    },
    statLabels = {
        CRIT = "Crit",
        HASTE = "Haste",
        MASTERY = "Mastery",
        VERS = "Vers",
        STAMINA = "Stamina",
        STRENGTH = "Strength",
        AGILITY = "Agility",
        INTELLECT = "Intellect",
    },
    statusOrder = {
        BIS = 1,
        UPGRADE = 2,
        SIDEGRADE = 3,
    },
    statusLabels = {
        BIS = "BiS",
        UPGRADE = "Upgrade",
        SIDEGRADE = "Sidegrade",
        PASS = "Pass",
    },
}

addon.defaults = {
    options = {
        fastAskIndex = 1,
        askTemplates = {
            "Do you need {item}?",
            "Can I get {item}?",
            "Are you keeping {item}?",
            "Do you still need {item}?",
            "Any chance I could get {item}?",
            "Need {item}?",
        },
        minUpgrade = 3,
        majorUpgrade = 12,
        fastWhisperCooldown = 10,
        filterUsableOnly = true,
        filterOwnDrops = true,
        filterTradableOnly = false,
        autoOpen = true,
        minimap = {
            angle = 225,
            hidden = false,
        },
    },
    notices = {
        missingDataPackVersion = nil,
    },
    specWeights = {},
    bis = {},
}

addon.charDefaults = {
    instances = {},
    state = {
        lastViewInstance = nil,
    },
}

local function copyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            copyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function addon:EnsureDatabase()
    if type(WhoNeedsDB) ~= "table" then
        if type(INeedItDB) == "table" then
            WhoNeedsDB = INeedItDB
        else
            WhoNeedsDB = {}
        end
    end

    copyDefaults(self.defaults, WhoNeedsDB)
    self.db = WhoNeedsDB
    
    if type(WhoNeedsCharDB) ~= "table" then
        WhoNeedsCharDB = {}
    end
    copyDefaults(self.charDefaults, WhoNeedsCharDB)
    self.charDB = WhoNeedsCharDB

    if type(self.db.instances) == "table" and next(self.db.instances) ~= nil and (not self.charDB.instances or next(self.charDB.instances) == nil) then
        self.charDB.instances = self.db.instances
        self.db.instances = nil
    end

    if self.db.options and self.db.options.lastViewInstance and not self.charDB.state.lastViewInstance then
        self.charDB.state.lastViewInstance = self.db.options.lastViewInstance
        self.db.options.lastViewInstance = nil
    end

    self.charDB.instances = self.charDB.instances or {}
    self.charDB.state = self.charDB.state or {}
    self:RebuildLootIndex()
end

function addon:RebuildLootIndex()
    self.lootByKey = {}
    local instances = self.charDB and self.charDB.instances or {}
    for instKey, instDB in pairs(instances) do
        if type(instDB) == "table" then
            instDB.loots = instDB.loots or {}
            instDB.lootHistory = instDB.lootHistory or {}
            for key, record in pairs(instDB.loots) do
                self.lootByKey[key] = record
            end
        end
    end
end

function addon:RegisterExternalData(payload)
    if type(payload) ~= "table" then
        return false, "Payload must be a table"
    end

    self.externalData = {
        version = payload.version or "dev",
        source = payload.source or "unknown",
        updatedAt = payload.updatedAt,
        specWeights = type(payload.specWeights) == "table" and payload.specWeights or {},
        bis = type(payload.bis) == "table" and payload.bis or {},
    }

    return true
end

function addon:LoadBundledData()
    local shared = _G.WhoNeedsExternalData
    if type(shared) ~= "table" then
        return false
    end

    self:RegisterExternalData(shared)
    return true
end

function addon:HasExternalData()
    return type(self.externalData) == "table"
end

function addon:GetDataStatus()
    if self:HasExternalData() then
        return {
            hasData = true,
            version = self.externalData.version,
            source = self.externalData.source,
            updatedAt = self.externalData.updatedAt,
        }
    end

    return {
        hasData = false,
    }
end

function addon:ShouldShowMissingDataPackMessage()
    local currentVersion = GetAddOnMetadata and GetAddOnMetadata(self.name, "Version") or "unknown"
    return not self:HasExternalData() and self.db.notices.missingDataPackVersion ~= currentVersion
end

function addon:MarkMissingDataPackMessageSeen()
    local currentVersion = GetAddOnMetadata and GetAddOnMetadata(self.name, "Version") or "unknown"
    self.db.notices.missingDataPackVersion = currentVersion
end

function addon:GetFullPlayerName(unit)
    local name, realm = UnitFullName(unit)
    if not name then
        return nil
    end
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

function addon:ShortName(name)
    if not name or name == "" then
        return "Unknown"
    end
    return Ambiguate(name, "short")
end

function addon:GetGroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

function addon:SendAddonPacket(message)
    local channel = self:GetGroupChannel()
    if not channel then
        return
    end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(self.prefix, message, channel)
    elseif SendAddonMessage then
        SendAddonMessage(self.prefix, message, channel)
    end
end

function addon:ContinueWithItem(itemLink, callback)
    if not itemLink or itemLink == "" then
        return
    end

    local item = Item:CreateFromItemLink(itemLink)
    item:ContinueOnItemLoad(function()
        callback(itemLink)
    end)
end

function addon:SanitizeMessage(text)
    text = tostring(text or "")
    text = text:gsub("[\r\n\t]", " ")
    return text
end

function addon:MakeLootKey(encounterID, playerName, itemID, quantity)
    return string.format("%s:%s:%s:%s", tonumber(encounterID) or 0, self:ShortName(playerName), tonumber(itemID) or 0, tonumber(quantity) or 1)
end

function addon:GetCurrentInstanceKey()
    local name, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    if instanceType == "none" or not name or name == "" then
        return "Global", "Open World"
    end
    
    local key = name
    if difficultyName and difficultyName ~= "" then
        key = key .. " (" .. difficultyName .. ")"
    end
    return key, key
end

function addon:UpdateCurrentInstance()
    if not self.charDB or not self.charDB.instances then return end
    
    local name, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    if instanceType == "none" then
        return -- Do not auto-switch back to Global when zoning out to town
    end
    
    if instanceType ~= "none" and (not difficultyName or difficultyName == "") then
        return -- Still loading instance difficulty, skip to avoid duplicate empty-difficulty instances
    end

    local instanceKey, instanceName = self:GetCurrentInstanceKey()
    
    self.charDB.instances[instanceKey] = self.charDB.instances[instanceKey] or {
        name = instanceName,
        loots = {},
        lootHistory = {}
    }
    
    if self.currentViewInstance ~= instanceKey then
        self.currentViewInstance = instanceKey
        self.currentPage = 1
        if self.charDB.state then
            self.charDB.state.lastViewInstance = instanceKey
        end
        if self.frame and self.frame:IsShown() then
            self:RefreshUI()
        end
    end
end

function addon:SortInstanceLootHistory(instanceKey)
    local instDB = self.charDB and self.charDB.instances and self.charDB.instances[instanceKey]
    if not instDB then return end
    table.sort(instDB.lootHistory, function(left, right)
        return (left.timestamp or 0) > (right.timestamp or 0)
    end)
end

function addon:PruneInstanceLootHistory(instanceKey)
    local instDB = self.charDB and self.charDB.instances and self.charDB.instances[instanceKey]
    if not instDB then return end
    -- Keep up to 200 items per instance to prevent massive DBs, but enough for a full run
    while #instDB.lootHistory > 200 do
        local removed = table.remove(instDB.lootHistory)
        if removed then
            instDB.loots[removed.key] = nil
            self.lootByKey[removed.key] = nil
        end
    end
end

function addon:GetOrCreateLootRecord(key, payload)
    local instanceKey, instanceName = self:GetCurrentInstanceKey()
    
    if payload.forceInstanceKey then
        instanceKey = payload.forceInstanceKey
        instanceName = payload.forceInstanceName or instanceKey
    end

    self.charDB.instances[instanceKey] = self.charDB.instances[instanceKey] or {
        name = instanceName,
        loots = {},
        lootHistory = {}
    }
    
    local instDB = self.charDB.instances[instanceKey]
    local record = instDB.loots[key]
    
    if record then
        return record, false
    end

    record = {
        key = key,
        instanceKey = instanceKey,
        timestamp = GetTime(),
        owner = payload.owner,
        ownerShort = self:ShortName(payload.owner),
        ownerClass = payload.ownerClass,
        itemID = payload.itemID,
        itemLink = payload.itemLink,
        itemName = payload.itemName,
        quantity = payload.quantity or 1,
        responses = {},
        localInterest = nil,
        whisperHistory = {},
    }

    table.insert(instDB.lootHistory, 1, record)
    instDB.loots[key] = record
    self.lootByKey[key] = record
    
    self:PruneInstanceLootHistory(instanceKey)
    self:SortInstanceLootHistory(instanceKey)
    
    self.currentViewInstance = instanceKey
    self.currentPage = 1

    return record, true
end

function addon:GetColoredName(name, classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not color then
        return self:ShortName(name)
    end
    return string.format("|c%s%s|r", color.colorStr, self:ShortName(name))
end

function addon:DeleteLootRecord(instanceKey, lootKey)
    local instDB = self.charDB and self.charDB.instances and self.charDB.instances[instanceKey]
    if not instDB then return end

    instDB.loots[lootKey] = nil
    self.lootByKey[lootKey] = nil
    
    for i, rec in ipairs(instDB.lootHistory) do
        if rec.key == lootKey then
            table.remove(instDB.lootHistory, i)
            break
        end
    end
    
    self:RefreshUI()
end

function addon:DeleteInstance(instanceKey)
    if self.charDB and self.charDB.instances and self.charDB.instances[instanceKey] then
        for key, _ in pairs(self.charDB.instances[instanceKey].loots) do
            self.lootByKey[key] = nil
        end
        self.charDB.instances[instanceKey] = nil
    end
    if self.currentViewInstance == instanceKey then
        self.currentViewInstance = nil
    end
    self.currentPage = 1
    self:RefreshUI()
end

function addon:ClearLootHistory()
    if self.currentViewInstance then
        self:DeleteInstance(self.currentViewInstance)
    end
end

function addon:SetUnreadLoot(hasUnread)
    self.hasUnreadLoot = hasUnread and true or false
    if self.UpdateMinimapButton then
        self:UpdateMinimapButton()
    end
end

function addon:MarkLootSeen()
    self:SetUnreadLoot(false)
end

function addon:GetGroupMemberSnapshot()
    local members = {}
    local seen = {}

    local function addUnit(unit)
        if not unit or not UnitExists(unit) then
            return
        end

        local fullName = self:GetFullPlayerName(unit) or UnitName(unit)
        local shortName = self:ShortName(fullName)
        if shortName and shortName ~= "" and not seen[shortName] then
            seen[shortName] = true
            table.insert(members, shortName)
        end
    end

    addUnit("player")
    for _, unit in ipairs(self:GetGroupUnitTokens()) do
        addUnit(unit)
    end

    return members, seen
end

function addon:ClearPendingEncounterLoot()
    if self.pendingEncounterLootTimer and self.pendingEncounterLootTimer.Cancel then
        self.pendingEncounterLootTimer:Cancel()
    end
    self.pendingEncounterLootTimer = nil
    self.pendingEncounterLoot = nil
    if self.RefreshUI then
        self:RefreshUI()
    end
end

function addon:SchedulePendingEncounterLootClear(delaySeconds)
    if self.pendingEncounterLootTimer and self.pendingEncounterLootTimer.Cancel then
        self.pendingEncounterLootTimer:Cancel()
    end

    if not C_Timer or not C_Timer.NewTimer then
        self.pendingEncounterLootTimer = nil
        return
    end

    self.pendingEncounterLootTimer = C_Timer.NewTimer(delaySeconds or 15, function()
        addon.pendingEncounterLootTimer = nil
        addon.pendingEncounterLoot = nil
        addon:RefreshUI()
    end)
end

function addon:StartPendingEncounterLoot(encounterID, encounterName)
    local members, memberSet = self:GetGroupMemberSnapshot()
    self.pendingEncounterLoot = {
        encounterID = encounterID,
        encounterName = encounterName,
        members = members,
        memberSet = memberSet,
        looters = {},
        total = #members,
        startedAt = GetTime(),
        lastUpdateAt = GetTime(),
    }
    self:SchedulePendingEncounterLootClear(20)
    if self.RefreshUI then
        self:RefreshUI()
    end
end

function addon:MarkPendingEncounterLooter(playerName)
    local state = self.pendingEncounterLoot
    if not state or not playerName or playerName == "" then
        return
    end

    local shortName = self:ShortName(playerName)
    if not shortName or shortName == "" then
        return
    end

    if state.memberSet and not state.memberSet[shortName] then
        state.memberSet[shortName] = true
        table.insert(state.members, shortName)
        state.total = #state.members
    end

    state.looters[shortName] = true
    state.lastUpdateAt = GetTime()

    local remaining = self:GetPendingEncounterLootRemaining()
    if remaining and remaining <= 0 then
        self:SchedulePendingEncounterLootClear(4)
    else
        self:SchedulePendingEncounterLootClear(20)
    end

    if self.RefreshUI then
        self:RefreshUI()
    end
end

function addon:GetPendingEncounterLootRemaining()
    local state = self.pendingEncounterLoot
    if not state or not state.members then
        return nil
    end

    local remaining = 0
    for _, shortName in ipairs(state.members) do
        if not state.looters[shortName] then
            remaining = remaining + 1
        end
    end

    return remaining, state.total, state
end

function addon:GetGroupUnitTokens()
    local units = {}
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            table.insert(units, "raid" .. index)
        end
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            table.insert(units, "party" .. index)
        end
    end
    return units
end

function addon:ResolveGroupUnitByName(name)
    local shortName = self:ShortName(name)
    for _, unit in ipairs(self:GetGroupUnitTokens()) do
        if UnitExists(unit) then
            local unitName = self:ShortName(self:GetFullPlayerName(unit) or UnitName(unit))
            if unitName == shortName then
                return unit
            end
        end
    end
    return nil
end

function addon:ResolveGroupUnitByGUID(guid)
    if not guid then
        return nil
    end
    for _, unit in ipairs(self:GetGroupUnitTokens()) do
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
end

function addon:ResolveItemPresentation(itemLink, itemID)
    local itemName, displayLink, quality, _, _, _, itemSubType, _, equipLoc, icon = GetItemInfo(itemLink)
    if not itemName and itemID and C_Item and C_Item.GetItemNameByID then
        itemName = C_Item.GetItemNameByID(itemID)
    end

    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    
    -- Fallback to parsing color from itemLink if not cached
    if not color and itemLink then
        local matchedColor = string.match(itemLink, "|c(%x%x%x%x%x%x%x%x)")
        if matchedColor then
            -- Find the matching quality ID by hex
            if ITEM_QUALITY_COLORS then
                for q, colorData in pairs(ITEM_QUALITY_COLORS) do
                    if colorData.hex and string.find(string.lower(colorData.hex), string.lower(matchedColor)) then
                        quality = q
                        color = colorData
                        break
                    end
                end
            end
            if not color then
                local aStr, rStr, gStr, bStr = string.match(itemLink, "|c(%x%x)(%x%x)(%x%x)(%x%x)")
                if rStr and gStr and bStr then
                    color = {
                        r = tonumber(rStr, 16) / 255,
                        g = tonumber(gStr, 16) / 255,
                        b = tonumber(bStr, 16) / 255,
                    }
                end
            end
        end
    end

    local coloredName = itemName
    if coloredName and color and color.hex then
        coloredName = color.hex .. coloredName .. FONT_COLOR_CODE_CLOSE
    elseif itemName and not color then
        coloredName = itemLink
    end

    return {
        itemName = itemName,
        coloredName = coloredName,
        displayLink = displayLink or itemLink,
        itemSubType = itemSubType,
        equipLoc = equipLoc,
        icon = icon,
        quality = quality,
        color = color,
    }
end
