local _, ns = ...
local addon = ns and ns.Addon or _G.WhoNeeds

local eventFrame = CreateFrame("Frame")
local refreshTicker = nil

local function showMissingDataPackPopup()
    StaticPopupDialogs["WHONEEDS_MISSING_DATA_PACK"] = {
        text = addon.L.MISSING_DATA_PACK_POPUP,
        button1 = OKAY,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = STATICPOPUP_NUMDIALOGS,
    }

    StaticPopup_Show("WHONEEDS_MISSING_DATA_PACK")
end

local function scheduleProfileBroadcast()
    if refreshTicker then
        refreshTicker:Cancel()
    end

    refreshTicker = C_Timer.NewTimer(1.0, function()
        refreshTicker = nil
        addon:BuildLocalProfile()
        addon:RefreshLocalGear()
        addon:BroadcastProfile()
        addon:RefreshUI()
    end)
end

local function finishInspect()
    if addon.inspectTimeout then
        addon.inspectTimeout:Cancel()
        addon.inspectTimeout = nil
    end
    if ClearInspectPlayer then
        ClearInspectPlayer()
    end
    addon.pendingInspect = nil
end

function addon:PumpInspectQueue()
    if self.pendingInspect or #self.inspectQueue == 0 then
        return
    end

    while #self.inspectQueue > 0 do
        local nextEntry = table.remove(self.inspectQueue, 1)
        local unit = nextEntry.unit
        if UnitExists(unit) and UnitGUID(unit) == nextEntry.guid and CanInspect(unit) then
            self.pendingInspect = nextEntry
            NotifyInspect(unit)
            self.inspectTimeout = C_Timer.NewTimer(1.5, function()
                finishInspect()
                addon:PumpInspectQueue()
            end)
            return
        end
    end
end

function addon:QueueInspectUnit(unit, force)
    if not unit or not UnitExists(unit) or UnitIsUnit(unit, "player") then
        return
    end
    if not CanInspect(unit) then
        return
    end

    local guid = UnitGUID(unit)
    if not guid then
        return
    end

    local cached = self.inspectCache[guid]
    if cached and not force and (GetTime() - (cached.timestamp or 0)) < 180 then
        return
    end

    if self.pendingInspect and self.pendingInspect.guid == guid then
        return
    end

    for _, queued in ipairs(self.inspectQueue) do
        if queued.guid == guid then
            return
        end
    end

    table.insert(self.inspectQueue, {
        guid = guid,
        unit = unit,
        shortName = self:ShortName(self:GetFullPlayerName(unit) or UnitName(unit)),
    })
    self:PumpInspectQueue()
end

function addon:QueueGroupInspection(force)
    for _, unit in ipairs(self:GetGroupUnitTokens()) do
        self:QueueInspectUnit(unit, force)
    end
end

function addon:CaptureInspectData(unit, guid)
    local shortName = self:ShortName(self:GetFullPlayerName(unit) or UnitName(unit))
    local _, classFile = UnitClass(unit)
    local cache = {
        guid = guid,
        shortName = shortName,
        classFile = classFile,
        specID = GetInspectSpecialization and GetInspectSpecialization(unit) or nil,
        timestamp = GetTime(),
        gear = {},
    }

    for _, slotID in ipairs(self.constants.inspectSlotIDs) do
        local link = GetInventoryItemLink(unit, slotID)
        if link then
            cache.gear[slotID] = {
                slotID = slotID,
                link = link,
                itemID = GetItemInfoInstant(link),
                itemLevel = self:GetDetailedItemLevel(link),
            }
        end
    end

    self.inspectCache[guid] = cache
    self.inspectCacheByName[shortName] = cache
    self.peerProfiles[shortName] = self.peerProfiles[shortName] or {}
    self.peerProfiles[shortName].classFile = classFile
end

function addon:HandleInspectReady(guid)
    if not self.pendingInspect or self.pendingInspect.guid ~= guid then
        return
    end

    local unit = self.pendingInspect.unit
    if not UnitExists(unit) or UnitGUID(unit) ~= guid then
        unit = self:ResolveGroupUnitByGUID(guid)
    end

    if unit and UnitExists(unit) then
        self:CaptureInspectData(unit, guid)
        self:RefreshUI()
    end

    finishInspect()
    self:PumpInspectQueue()
end

function addon:ShowLootWindow()
    self:CreateUI()
    if not self.frame:IsShown() then
        self.frame:Show()
    end
    self:MarkLootSeen()
    self:RefreshUI()
end

function addon:BroadcastProfile()
    if not self.localProfile or not self.localProfile.classFile then
        return
    end

    local message = table.concat({
        "P",
        tostring(self.localProfile.specID or 0),
        self:SanitizeMessage(self.localProfile.specName or "Unknown"),
        self:SanitizeMessage(self.localProfile.role or "DAMAGER"),
        self.localProfile.classFile or "UNKNOWN",
    }, "\t")

    self:SendAddonPacket(message)
    self.peerProfiles[self.playerName] = {
        specID = self.localProfile.specID,
        specName = self.localProfile.specName,
        role = self.localProfile.role,
        classFile = self.localProfile.classFile,
    }
end

function addon:StoreResponse(record, sender, response)
    local previous = record.responses[sender]
    local wasInterested = previous and previous.status ~= "PASS"
    local isInterested = response and response.status ~= "PASS"
    record.nextInterestOrder = math.max(tonumber(record.nextInterestOrder) or 0, tonumber(response.interestOrder) or 0)

    if isInterested then
        if not response.interestOrder or response.interestOrder <= 0 then
            if wasInterested and previous and previous.interestOrder then
                response.interestOrder = previous.interestOrder
            else
                response.interestOrder = self:AllocateInterestOrder(record)
            end
        end
        record.nextInterestOrder = math.max(tonumber(record.nextInterestOrder) or 0, tonumber(response.interestOrder) or 0)
        response.updatedAt = response.updatedAt or GetTime()
    else
        response.interestOrder = nil
        response.updatedAt = nil
    end

    record.responses[sender] = response
    if sender == self.playerName then
        record.localItemLevel = response.itemLevel or record.localItemLevel
        record.localInterest = response.status ~= "PASS"
    end
    self:RefreshUI()
end

function addon:GetResponseRoll(response)
    local roll = tonumber(response and response.roll) or 0
    if roll < 1 or roll > 100 then
        return 0
    end
    return math.floor(roll)
end

function addon:EnsureResponseRoll(record, sender, response)
    if not response or response.status == "PASS" then
        return 0
    end

    local roll = self:GetResponseRoll(response)
    if roll > 0 then
        response.roll = roll
        return roll
    end

    local previous = record and record.responses and record.responses[sender]
    roll = self:GetResponseRoll(previous)
    if roll == 0 then
        roll = math.random(1, 100)
    end

    response.roll = roll
    return roll
end

function addon:SendFitResponse(key, response)
    local message = table.concat({
        "F",
        key,
        response.status or "PASS",
        string.format("%.2f", response.delta or 0),
        tostring(response.itemLevel or 0),
        self:SanitizeMessage(response.summary or response.reason or ""),
        tostring(response.baselineItemID or 0),
        tostring(response.baselineItemLevel or 0),
        tostring(response.interestOrder or 0),
        tostring(response.updatedAt or 0),
        tostring(response.roll or 0),
    }, "\t")

    self:SendAddonPacket(message)
end

function addon:HandleLoot(encounterID, itemID, itemLink, quantity, playerName, classFileName, options)
    local ownerName = playerName or "Unknown"

    self:ContinueWithItem(itemLink, function(link)
        local isTrackable, ignoreReason = self:IsTrackableLootItem(link)
        if not isTrackable then
            self:DebugLog("Ignored loot owner=%s item=%s reason=%s", tostring(ownerName), tostring(link), tostring(ignoreReason or "unknown"))
            return
        end

        local key = self:MakeLootKey(encounterID, ownerName, itemID, quantity)
        local payload = {
            owner = ownerName,
            ownerClass = classFileName,
            itemID = itemID,
            itemLink = link,
            itemName = GetItemInfo(link) or nil,
            quantity = quantity,
        }

        if options and options.forceInstanceKey then
            payload.forceInstanceKey = options.forceInstanceKey
            payload.forceInstanceName = options.forceInstanceName
        end

        local record, isNewRecord = self:GetOrCreateLootRecord(key, payload)

        self.peerProfiles[self:ShortName(ownerName)] = self.peerProfiles[self:ShortName(ownerName)] or {
            classFile = classFileName,
        }
        if not (options and options.simulated) then
            self:MarkPendingEncounterLooter(ownerName)
            local ownerUnit = self:ResolveGroupUnitByName(ownerName)
            if ownerUnit then
                self:QueueInspectUnit(ownerUnit, true)
            end
        end

        self:BuildLocalProfile()
        self:RefreshLocalGear()

        local presentation = self:ResolveItemPresentation(link, itemID)
        record.itemName = presentation.itemName or record.itemName
        record.itemLink = presentation.displayLink or record.itemLink

        local response = self:EvaluateItemForSelf(link)
        if options and options.forceInterested then
            if response.status == "PASS" then
                response.status = "UPGRADE"
                response.delta = math.max(response.delta or 0, 1)
                response.reason = nil
            end
            response.summary = self.L.SUMMARY_FORCED_INTEREST
        end
        response.summary = response.summary or response.reason or self.L.SUMMARY_NO_USEFUL_STATS
        response.itemLevel = response.itemLevel or self:GetDetailedItemLevel(link)

        self:StoreResponse(record, self.playerName, response)
        if options and options.simulated then
            self:ShowLootWindow()
        elseif self.frame and self.frame:IsShown() then
            self:MarkLootSeen()
            self:RefreshUI()
        elseif isNewRecord then
            if self.db and self.db.options and self.db.options.autoOpen then
                self:ShowLootWindow()
            else
                self:SetUnreadLoot(true)
            end
        end
        if not (options and options.simulated) then
            self:SendFitResponse(key, response)
        end
    end)
end

function addon:SimulateLootInput(itemText, ownerText, forceInterested)
    local text = strtrim(tostring(itemText or ""))
    if text == "" then
        print("|cff33ff99WhoNeeds|r " .. self.L.SLASH_SIM_USAGE)
        return
    end

    local ownerName = strtrim(tostring(ownerText or ""))
    if ownerName == "" then
        ownerName = self.playerName
    end

    local itemLink = text:match("(|c.-|h%[.-%]|h|r)")
    local itemID = itemLink and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(itemLink) or nil

    if not itemID then
        itemID = tonumber(text) or tonumber(text:match("item:(%d+)")) or tonumber(text:match("Hitem:(%d+)"))
    end

    if not itemID then
        print("|cff33ff99WhoNeeds|r " .. self.L.SLASH_PARSE_FAILED)
        return
    end

    if not itemLink then
        itemLink = "item:" .. itemID
    end

    self.simulationCounter = (self.simulationCounter or 0) + 1

    local _, classFile = UnitClass("player")
    local ownerClass = self:ShortName(ownerName) == self.playerName and classFile or nil
    local encounterID = 900000 + self.simulationCounter

    self:HandleLoot(encounterID, itemID, itemLink, 1, ownerName, ownerClass, {
        simulated = true,
        forceInterested = forceInterested,
        forceInstanceKey = "Simulation",
        forceInstanceName = self.L.SIMULATIONS,
    })
    print(string.format("|cff33ff99WhoNeeds|r " .. self.L.SLASH_SIM_DONE, ownerName, tostring(itemLink)))
end

function addon:HandleAddonMessage(message, sender)
    local senderKey = self:ShortName(sender)
    if senderKey == self.playerName then
        return
    end

    local command, a, b, c, d, e, f, g, h, i, j = strsplit("\t", message)

    if command == "P" then
        self.peerProfiles[senderKey] = {
            specID = tonumber(a) or 0,
            specName = b or "Unknown",
            role = c or "DAMAGER",
            classFile = d or "UNKNOWN",
        }
        self:RefreshUI()
        return
    end

    if command == "F" then
        local key = a
        local record = self.lootByKey[key]
        if not record then
            return
        end

        self:StoreResponse(record, senderKey, {
            status = b or "PASS",
            delta = tonumber(c) or 0,
            itemLevel = tonumber(d) or 0,
            summary = e or "",
            baselineItemID = tonumber(f) or 0,
            baselineItemLevel = tonumber(g) or 0,
            interestOrder = tonumber(h) or 0,
            updatedAt = tonumber(i) or 0,
            roll = tonumber(j) or 0,
        })
    end
end

function addon:BuildWhisperMessage(record, response)
    local itemLabel = record.itemLink or (record.itemID and ("item:" .. record.itemID)) or self.L.DEFAULT_ITEM_LABEL
    local yourStatus = response and (self.L[response.status] or response.status) or self.L.DEFAULT_STATUS_INTERESTING
    return string.format(self.L.DEFAULT_WHISPER_TEMPLATE, itemLabel, yourStatus)
end

function addon:FormatWhisperTemplate(template, record, response)
    local itemLabel = record.itemLink or (record.itemID and ("item:" .. record.itemID)) or self.L.DEFAULT_ITEM_LABEL
    local statusLabel = response and (self.L[response.status] or response.status) or self.L.DEFAULT_STATUS_INTERESTING
    local normalizedStatus = string.lower(statusLabel or self.L.DEFAULT_STATUS_INTERESTING)
    local message = template:gsub("{item}", itemLabel)
    message = message:gsub("{status}", normalizedStatus)
    message = message:gsub("{owner}", record.owner or self.L.YOU)
    return message
end

function addon:GetWhisperTargetKey(target)
    return self:ShortName(target)
end

function addon:GetWhisperState(record, target)
    if type(record) ~= "table" or not target or target == "" then
        return nil
    end

    record.whisperHistory = type(record.whisperHistory) == "table" and record.whisperHistory or {}
    return record.whisperHistory[self:GetWhisperTargetKey(target)]
end

function addon:GetFastWhisperCooldown()
    local configured = self.db and self.db.options and tonumber(self.db.options.fastWhisperCooldown)
    if configured and configured >= 5 and configured <= 10 then
        return configured
    end
    return 10
end

function addon:GetFastWhisperRemaining(record, target)
    local state = self:GetWhisperState(record, target)
    if not state or not state.lastSentAt then
        return 0
    end

    local remaining = self:GetFastWhisperCooldown() - (GetTime() - state.lastSentAt)
    if remaining < 0 then
        return 0
    end
    return remaining
end

function addon:GetWhisperSummary(record, target)
    local state = self:GetWhisperState(record, target)
    if not state or not state.count or state.count <= 0 then
        return nil
    end

    local text = string.format(self.L.WHISPER_SENT_COUNT, state.count)
    local remaining = self:GetFastWhisperRemaining(record, target)
    if remaining > 0 then
        text = text .. " - " .. string.format(self.L.FAST_ASK_WAIT, math.ceil(remaining))
    end
    return text
end

function addon:RecordWhisper(record, target, message, isFast)
    if type(record) ~= "table" or not target or target == "" then
        return
    end

    record.whisperHistory = type(record.whisperHistory) == "table" and record.whisperHistory or {}

    local key = self:GetWhisperTargetKey(target)
    local state = record.whisperHistory[key] or {
        count = 0,
    }

    state.count = (state.count or 0) + 1
    state.lastSentAt = GetTime()
    state.lastMessage = message
    state.lastTarget = target
    state.lastMethod = isFast and "FAST" or "MENU"

    record.whisperHistory[key] = state
end

function addon:ScheduleFastWhisperRefresh(record, target)
    if not record or not record.key or not target then
        return
    end

    self.whisperCooldownTimers = self.whisperCooldownTimers or {}

    local timerKey = record.key .. ":" .. self:GetWhisperTargetKey(target)
    local existing = self.whisperCooldownTimers[timerKey]
    if existing and existing.Cancel then
        existing:Cancel()
    end

    local remaining = self:GetFastWhisperRemaining(record, target)
    if remaining <= 0 or not C_Timer or not C_Timer.NewTimer then
        self.whisperCooldownTimers[timerKey] = nil
        return
    end

    self.whisperCooldownTimers[timerKey] = C_Timer.NewTimer(remaining + 0.05, function()
        addon.whisperCooldownTimers[timerKey] = nil
        addon:RefreshUI()
    end)
end

function addon:SendLootWhisper(target, record, message, isFast)
    if not target or target == "" or not record or not message or message == "" then
        return false
    end

    local remaining = isFast and self:GetFastWhisperRemaining(record, target) or 0
    if remaining > 0 then
        print(string.format("|cff33ff99WhoNeeds|r " .. self.L.FAST_ASK_BLOCKED, math.ceil(remaining)))
        self:RefreshUI()
        return false
    end

    SendChatMessage(message, "WHISPER", nil, target)
    self:RecordWhisper(record, target, message, isFast)

    if isFast then
        print(string.format("|cff33ff99WhoNeeds|r " .. self.L.FAST_ASK_SENT, target, message))
    end
    self:ScheduleFastWhisperRefresh(record, target)

    self:RefreshUI()
    return true
end

function addon:GetOwnerInspectResponse(record)
    local cache = self.inspectCacheByName[record.ownerShort]
    if not cache or not record.itemLink then
        return nil
    end

    local profile = {
        classFile = cache.classFile,
        armorSubclass = self.constants.armorSubclassByClass[cache.classFile],
    }
    local canUse, reason = self:CanProfileUseItem(record.itemLink, profile)
    if not canUse then
        self:DebugLog(
            "OwnerInspect owner=%s class=%s item=%s reason=%s",
            tostring(record.ownerShort),
            tostring(cache.classFile or "UNKNOWN"),
            tostring(record.itemLink),
            tostring(reason or "nil")
        )
        return {
            status = "PASS",
            delta = 0,
            itemLevel = self:GetDetailedItemLevel(record.itemLink),
            reason = reason,
        }
    end

    local _, _, _, equipLoc = GetItemInfoInstant(record.itemLink)
    if not equipLoc or equipLoc == "" then
        return nil
    end

    local baseline = self:GetBaselineFromGear(equipLoc, cache.gear)
    local itemLevel = self:GetDetailedItemLevel(record.itemLink)
    local baselineLevel = baseline and baseline.itemLevel or 0
    local delta = itemLevel - baselineLevel
    local status = "PASS"

    if not baseline or baselineLevel == 0 then
        status = "UPGRADE"
    elseif delta >= 8 then
        status = "UPGRADE"
    elseif delta > 0 then
        status = "SIDEGRADE"
    end

    if equipLoc == "INVTYPE_TRINKET" and status == "PASS" and baselineLevel > 0 and itemLevel > baselineLevel then
        status = "SIDEGRADE"
    end

    return {
        status = status,
        delta = delta,
        itemLevel = itemLevel,
        summary = (equipLoc == "INVTYPE_TRINKET") and self.L.SUMMARY_APPROX_OWNER or self.L.SUMMARY_OWNER_FALLBACK,
        baselineItemID = baseline and baseline.itemID or nil,
        baselineItemLevel = baseline and baseline.itemLevel or nil,
        approximate = (equipLoc == "INVTYPE_TRINKET"),
    }
end

function addon:IsInspectPendingForPlayer(shortName)
    if not shortName or shortName == "" then
        return false
    end

    if self.pendingInspect and self.pendingInspect.shortName == shortName then
        return true
    end

    for _, queued in ipairs(self.inspectQueue or {}) do
        if queued.shortName == shortName then
            return true
        end
    end

    return false
end

function addon:GetTradeReferenceFromGear(equipLoc, gearMap)
    local slots = self.constants.equipLocToSlots[equipLoc]
    if not slots or not gearMap then
        return nil
    end

    local function getSlot(slotID)
        return gearMap[slotID]
    end

    if equipLoc == "INVTYPE_FINGER" or equipLoc == "INVTYPE_TRINKET" or equipLoc == "INVTYPE_WEAPON" then
        local first = getSlot(slots[1])
        local second = getSlot(slots[2])
        if not first and not second then
            return nil
        end
        if not first then
            return second
        end
        if not second then
            return first
        end
        if (first.itemLevel or 0) >= (second.itemLevel or 0) then
            return first
        end
        return second
    end

    if equipLoc == "INVTYPE_2HWEAPON" then
        local mainHand = getSlot(16)
        local offHand = getSlot(17)
        if not mainHand and not offHand then
            return nil
        end
        if not mainHand then
            return offHand
        end
        if not offHand then
            return mainHand
        end
        if (mainHand.itemLevel or 0) >= (offHand.itemLevel or 0) then
            return mainHand
        end
        return offHand
    end

    return getSlot(slots[1])
end

function addon:GetLootTradableState(record)
    if not record or not record.itemLink then
        return "UNKNOWN"
    end

    local _, _, _, equipLoc = GetItemInfoInstant(record.itemLink)
    if not equipLoc or equipLoc == "" then
        return "UNKNOWN"
    end

    local itemLevel = self:GetDetailedItemLevel(record.itemLink)
    if record.ownerShort == self.playerName then
        local equipped = self:GetTradeReferenceFromGear(equipLoc, self.localGear)
        if not equipped then
            return "UNKNOWN"
        end
        return ((equipped.itemLevel or 0) >= itemLevel) and "YES" or "NO"
    end

    local cache = self.inspectCacheByName[record.ownerShort]
    if not cache or not cache.gear then
        return "UNKNOWN"
    end

    local equipped = self:GetTradeReferenceFromGear(equipLoc, cache.gear)
    if not equipped then
        return "UNKNOWN"
    end
    return ((equipped.itemLevel or 0) >= itemLevel) and "YES" or "NO"
end

function addon:IsLootTradableByOwner(record)
    local state = self:GetLootTradableState(record)
    if state == "YES" then
        return true
    end
    if state == "NO" then
        return false
    end
    return nil
end

function addon:HandleSlashCommand(text)
    local command, rest = text:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" then
        self:ToggleUI()
        return
    end

    if command == "msg" and rest ~= "" then
        self.db.options.whisperMessage = rest
        print(string.format("|cff33ff99WhoNeeds|r " .. self.L.SLASH_MSG_SET, rest))
        return
    end

    if command == "data" then
        local status = self:GetDataStatus()
        if status.hasData then
            print(string.format("|cff33ff99WhoNeeds|r " .. self.L.SLASH_DATA_LOADED, tostring(status.version), tostring(status.source)))
        else
            print("|cff33ff99WhoNeeds|r " .. self.L.SLASH_DATA_MISSING)
        end
        return
    end

    if command == "debug" then
        self.db.options.debugMode = not (self.db.options and self.db.options.debugMode == true)
        print(string.format("|cff33ff99WhoNeeds|r " .. self.L.SLASH_DEBUG_STATE, self.db.options.debugMode and self.L.SLASH_ENABLED or self.L.SLASH_DISABLED))
        return
    end

    if command == "sim" and rest ~= "" then
        local itemText, ownerText = rest:match("^(.-)%s+owner:(.+)$")
        if not itemText then
            itemText = rest
        end
        self:SimulateLootInput(itemText, ownerText, false)
        return
    end

    if command == "simforce" and rest ~= "" then
        local itemText, ownerText = rest:match("^(.-)%s+owner:(.+)$")
        if not itemText then
            itemText = rest
        end
        self:SimulateLootInput(itemText, ownerText, true)
        return
    end

    if command == "bis" then
        local action, value = rest:match("^(%S+)%s*(.-)$")
        local itemID = tonumber(value)
        local specID = self.localProfile and self.localProfile.specID
        if not specID or specID == 0 or not itemID then
            print("|cff33ff99WhoNeeds|r " .. self.L.SLASH_BIS_USAGE)
            return
        end

        self.db.bis[specID] = self.db.bis[specID] or {}
        if action == "add" then
            self.db.bis[specID][itemID] = true
            print(string.format("|cff33ff99WhoNeeds|r " .. self.L.SLASH_BIS_ADDED, itemID, specID))
            return
        end

        if action == "remove" or action == "del" then
            self.db.bis[specID][itemID] = nil
            print(string.format("|cff33ff99WhoNeeds|r " .. self.L.SLASH_BIS_REMOVED, itemID, specID))
            return
        end
    end

    print("|cff33ff99WhoNeeds|r " .. self.L.SLASH_COMMANDS)
end

function addon:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        self:EnsureDatabase()
        self:LoadBundledData()
        self.playerName = self:ShortName(self:GetFullPlayerName("player"))
        self:BuildLocalProfile()
        self:RefreshLocalGear()
        self:CreateUI()
        self:CreateMinimapButton()

        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(self.prefix)
        end

        SLASH_WHONEEDS1 = "/whoneeds"
        SLASH_WHONEEDS2 = "/wn"
        SlashCmdList.WHONEEDS = function(text)
            self:HandleSlashCommand(text or "")
        end

        print("|cff33ff99WhoNeeds|r loaded. Type /whoneeds to open the window.")

        if self:ShouldShowMissingDataPackMessage() then
            print("|cff33ff99WhoNeeds|r WhoNeeds_Data is not installed. The addon is using generic fallback weights only. Install WhoNeeds_Data for curated stat priorities and BiS lists.")
            showMissingDataPackPopup()
            self:MarkMissingDataPackMessageSeen()
        end

        scheduleProfileBroadcast()
        self:QueueGroupInspection(false)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if self.UpdateCurrentInstance then
            self:UpdateCurrentInstance()
        end
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
        scheduleProfileBroadcast()
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            self:QueueGroupInspection(false)
        end
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == "player" then
            scheduleProfileBroadcast()
        end
        return
    end

    if event == "ENCOUNTER_START" then
        self:ClearPendingEncounterLoot()
        return
    end

    if event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, success = ...
        if success == 1 then
            self:StartPendingEncounterLoot(encounterID, encounterName)
            if self.db and self.db.options and self.db.options.autoOpen then
                self:ShowLootWindow()
            end
        else
            self:ClearPendingEncounterLoot()
        end
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix == self.prefix then
            self:HandleAddonMessage(message, sender)
        end
        return
    end

    if event == "INSPECT_READY" then
        local guid = ...
        self:HandleInspectReady(guid)
        return
    end

    if event == "ENCOUNTER_LOOT_RECEIVED" then
        self:HandleLoot(...)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    addon:OnEvent(event, ...)
end)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
