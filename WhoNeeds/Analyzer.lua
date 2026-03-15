local _, ns = ...
local addon = ns and ns.Addon or _G.WhoNeeds

local WEAPON_CLASS_ID = 2
local ARMOR_CLASS_ID = 4
local SHIELD_SUBCLASS_ID = 6
local BOW_SUBCLASS_ID = 2
local GUN_SUBCLASS_ID = 3
local CROSSBOW_SUBCLASS_ID = 18
local WAND_SUBCLASS_ID = 19
local WARGLAIVE_SUBCLASS_ID = 9

local allowedWeaponSubclassesByClass = {
    DEATHKNIGHT = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
    DEMONHUNTER = { [0] = true, [7] = true, [9] = true, [13] = true },
    DRUID = { [4] = true, [10] = true, [13] = true, [15] = true },
    EVOKER = { [4] = true, [10] = true, [15] = true },
    HUNTER = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [18] = true },
    MAGE = { [7] = true, [10] = true, [15] = true, [19] = true },
    MONK = { [0] = true, [4] = true, [6] = true, [7] = true, [10] = true, [13] = true },
    PALADIN = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
    PRIEST = { [4] = true, [10] = true, [15] = true, [19] = true },
    ROGUE = { [0] = true, [4] = true, [7] = true, [13] = true, [15] = true },
    SHAMAN = { [0] = true, [4] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true },
    WARLOCK = { [7] = true, [10] = true, [15] = true, [19] = true },
    WARRIOR = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true },
}

local shieldClasses = {
    PALADIN = true,
    SHAMAN = true,
    WARRIOR = true,
}

local primaryStatTokens = {
    [LE_UNIT_STAT_STRENGTH or 1] = "STRENGTH",
    [LE_UNIT_STAT_AGILITY or 2] = "AGILITY",
    [LE_UNIT_STAT_INTELLECT or 4] = "INTELLECT",
}

local roleWeights = {
    TANK = {
        ILVL = 3.0,
        PRIMARY = 1.10,
        STAMINA = 0.35,
        HASTE = 1.00,
        MASTERY = 0.95,
        VERS = 0.90,
        CRIT = 0.60,
    },
    HEALER = {
        ILVL = 2.6,
        PRIMARY = 1.20,
        STAMINA = 0.05,
        HASTE = 1.05,
        MASTERY = 1.00,
        CRIT = 0.88,
        VERS = 0.82,
    },
    CASTER = {
        ILVL = 2.8,
        PRIMARY = 1.25,
        STAMINA = 0.05,
        HASTE = 1.05,
        MASTERY = 1.00,
        CRIT = 0.92,
        VERS = 0.84,
    },
    RANGED = {
        ILVL = 2.8,
        PRIMARY = 1.25,
        STAMINA = 0.05,
        HASTE = 1.00,
        MASTERY = 0.96,
        CRIT = 0.92,
        VERS = 0.86,
    },
    MELEE = {
        ILVL = 2.8,
        PRIMARY = 1.25,
        STAMINA = 0.05,
        HASTE = 1.00,
        MASTERY = 0.96,
        CRIT = 0.92,
        VERS = 0.86,
    },
}

local function cloneTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function debugEquipCheck(prefix, itemLink, profile, equipLoc, itemClassID, itemSubClassID, reason)
    if not addon.IsDebugEnabled or not addon:IsDebugEnabled() then
        return
    end
    local _, itemType, itemSubType = GetItemInfo(itemLink)
    local profileClass = profile and profile.classFile or "UNKNOWN"
    local expectedArmor = profile and profile.armorSubclass or "nil"
    addon:DebugLog(
        "%s item=%s class=%s expectedArmor=%s equipLoc=%s itemClassID=%s itemSubClassID=%s itemType=%s itemSubType=%s reason=%s",
        tostring(prefix or "equip-check"),
        tostring(itemLink),
        tostring(profileClass),
        tostring(expectedArmor),
        tostring(equipLoc or "nil"),
        tostring(itemClassID or "nil"),
        tostring(itemSubClassID or "nil"),
        tostring(itemType or "nil"),
        tostring(itemSubType or "nil"),
        tostring(reason or "nil")
    )
end

function addon:GetPlayerRoleBucket(role, primaryStat, classFile)
    if role == "TANK" or role == "HEALER" then
        return role
    end

    if primaryStatTokens[primaryStat] == "INTELLECT" then
        return "CASTER"
    end

    if classFile == "HUNTER" or classFile == "EVOKER" then
        return "RANGED"
    end

    return "MELEE"
end

function addon:GetCurrentSpecInfo()
    local index = GetSpecialization()
    if not index then
        return nil
    end

    local specID, specName, _, _, _, role, primaryStat = GetSpecializationInfo(index)
    return {
        index = index,
        specID = specID,
        specName = specName,
        role = role,
        primaryStat = primaryStat,
    }
end

function addon:GetSpecWeights(specInfo, classFile)
    local bucket = self:GetPlayerRoleBucket(specInfo.role, specInfo.primaryStat, classFile)
    local weights = cloneTable(roleWeights[bucket] or roleWeights.MELEE)
    local externalOverrides = self.externalData and self.externalData.specWeights and self.externalData.specWeights[specInfo.specID]
    local overrides = self.db and self.db.specWeights and self.db.specWeights[specInfo.specID]

    if type(externalOverrides) == "table" then
        for key, value in pairs(externalOverrides) do
            weights[key] = value
        end
    end

    if type(overrides) == "table" then
        for key, value in pairs(overrides) do
            weights[key] = value
        end
    end

    weights.PRIMARY_TOKEN = primaryStatTokens[specInfo.primaryStat]
    weights.ROLE_BUCKET = bucket
    return weights
end

function addon:BuildLocalProfile()
    local _, classFile = UnitClass("player")
    local specInfo = self:GetCurrentSpecInfo()
    local profile = {
        name = self.playerName,
        classFile = classFile,
        armorSubclass = self.constants.armorSubclassByClass[classFile],
        specID = 0,
        specName = "Unknown",
        role = "DAMAGER",
        primaryStat = nil,
        weights = cloneTable(roleWeights.MELEE),
    }

    if specInfo then
        profile.specID = specInfo.specID
        profile.specName = specInfo.specName
        profile.role = specInfo.role
        profile.primaryStat = specInfo.primaryStat
        profile.weights = self:GetSpecWeights(specInfo, classFile)
    end

    self.localProfile = profile
    return profile
end

function addon:GetDetailedItemLevel(itemLink)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local level = C_Item.GetDetailedItemLevelInfo(itemLink)
        if level and level > 0 then
            return level
        end
    end

    if GetDetailedItemLevelInfo then
        local level = GetDetailedItemLevelInfo(itemLink)
        if level and level > 0 then
            return level
        end
    end

    local _, _, _, itemLevel = GetItemInfo(itemLink)
    return itemLevel or 0
end

function addon:GetRelevantStats(itemLink)
    local result = {}
    local rawStats = nil

    if C_Item and C_Item.GetItemStats then
        rawStats = C_Item.GetItemStats(itemLink)
    elseif GetItemStats then
        rawStats = GetItemStats(itemLink)
    end

    if not rawStats then
        return result
    end

    for key, value in pairs(rawStats) do
        local token = self.constants.statKeyMap[key]
        if token then
            result[token] = (result[token] or 0) + value
        end
    end

    return result
end

function addon:GetScoreForItem(itemLink, profile)
    local itemLevel = self:GetDetailedItemLevel(itemLink)
    local stats = self:GetRelevantStats(itemLink)
    local weights = profile.weights
    local weightedStats = 0
    local primaryToken = weights.PRIMARY_TOKEN

    if primaryToken and stats[primaryToken] then
        weightedStats = weightedStats + (stats[primaryToken] * (weights.PRIMARY or 1))
    end

    weightedStats = weightedStats + ((stats.STAMINA or 0) * (weights.STAMINA or 0))
    weightedStats = weightedStats + ((stats.HASTE or 0) * (weights.HASTE or 0))
    weightedStats = weightedStats + ((stats.MASTERY or 0) * (weights.MASTERY or 0))
    weightedStats = weightedStats + ((stats.CRIT or 0) * (weights.CRIT or 0))
    weightedStats = weightedStats + ((stats.VERS or 0) * (weights.VERS or 0))

    return (itemLevel * (weights.ILVL or 1)) + (weightedStats / 12), itemLevel, stats
end

function addon:IsPrimaryArmorMatch(itemLink, profile)
    local _, _, _, equipLoc, _, itemClassID, itemSubClassID = GetItemInfoInstant(itemLink)
    if not equipLoc or equipLoc == "" then
        return false, "Unknown slot"
    end

    if itemClassID ~= ARMOR_CLASS_ID then
        return true
    end

    if equipLoc == "INVTYPE_CLOAK" or equipLoc == "INVTYPE_NECK" or equipLoc == "INVTYPE_FINGER" or equipLoc == "INVTYPE_TRINKET" or equipLoc == "INVTYPE_TABARD" then
        return true
    end

    if itemSubClassID == SHIELD_SUBCLASS_ID then
        if not profile or not shieldClasses[profile.classFile] then
            return false, "Class cannot equip shields"
        end
        return true
    end

    if not profile.armorSubclass or not itemSubClassID then
        return true
    end

    if itemSubClassID ~= profile.armorSubclass then
        return false, "Wrong armor type"
    end

    return true
end

function addon:CanProfileUseWeaponSubclass(profile, itemSubClassID)
    if not profile or not profile.classFile or itemSubClassID == nil then
        return false
    end

    local allowed = allowedWeaponSubclassesByClass[profile.classFile]
    return type(allowed) == "table" and allowed[itemSubClassID] == true
end

function addon:CanProfileUseItem(itemLink, profile)
    if not itemLink or itemLink == "" then
        debugEquipCheck("CanProfileUseItem", itemLink, profile, nil, nil, nil, "Missing item")
        return false, "Missing item"
    end

    local _, _, _, equipLoc, _, itemClassID, itemSubClassID = GetItemInfoInstant(itemLink)
    if not equipLoc or equipLoc == "" then
        debugEquipCheck("CanProfileUseItem", itemLink, profile, equipLoc, itemClassID, itemSubClassID, "Unknown slot")
        return false, "Unknown slot"
    end

    local armorOk, reason = self:IsPrimaryArmorMatch(itemLink, profile)
    if not armorOk then
        debugEquipCheck("CanProfileUseItem", itemLink, profile, equipLoc, itemClassID, itemSubClassID, reason)
        return false, reason
    end

    if not self.constants.equipLocToSlots[equipLoc] and itemClassID ~= ARMOR_CLASS_ID and itemClassID ~= WEAPON_CLASS_ID then
        debugEquipCheck("CanProfileUseItem", itemLink, profile, equipLoc, itemClassID, itemSubClassID, "Class cannot equip it")
        return false, "Class cannot equip it"
    end

    if itemClassID == WEAPON_CLASS_ID and (not equipLoc or equipLoc == "") then
        debugEquipCheck("CanProfileUseItem", itemLink, profile, equipLoc, itemClassID, itemSubClassID, "Unknown weapon slot")
        return false, "Unknown weapon slot"
    end

    if itemClassID == WEAPON_CLASS_ID and not self:CanProfileUseWeaponSubclass(profile, itemSubClassID) then
        local reason = "Class cannot equip this weapon"
        if itemSubClassID == WAND_SUBCLASS_ID then
            reason = "Class cannot equip it"
        elseif itemSubClassID == BOW_SUBCLASS_ID or itemSubClassID == GUN_SUBCLASS_ID or itemSubClassID == CROSSBOW_SUBCLASS_ID or itemSubClassID == WARGLAIVE_SUBCLASS_ID then
            reason = "Class cannot equip this weapon"
        end
        debugEquipCheck("CanProfileUseItem", itemLink, profile, equipLoc, itemClassID, itemSubClassID, reason)
        return false, reason
    end

    return true
end

function addon:CanUseItemForSelf(itemLink, profile)
    return self:CanProfileUseItem(itemLink, profile)
end

function addon:GetEquippedSlotInfo(slotID)
    local cached = self.localGear[slotID]
    if cached then
        return cached
    end

    local link = GetInventoryItemLink("player", slotID)
    if not link then
        return nil
    end

    local score, itemLevel = self:GetScoreForItem(link, self.localProfile)
    local itemID = GetItemInfoInstant(link)
    cached = {
        slotID = slotID,
        link = link,
        itemID = itemID,
        score = score,
        itemLevel = itemLevel,
    }
    self.localGear[slotID] = cached
    return cached
end

function addon:RefreshLocalGear()
    wipe(self.localGear)

    for _, slotID in pairs({
        1, 2, 3, 5, 6, 7, 8, 9, 10,
        11, 12, 13, 14, 15, 16, 17,
    }) do
        self:GetEquippedSlotInfo(slotID)
    end
end

function addon:GetBaselineForEquipLoc(equipLoc)
    local slots = self.constants.equipLocToSlots[equipLoc]
    if not slots then
        return nil
    end

    if equipLoc == "INVTYPE_FINGER" or equipLoc == "INVTYPE_TRINKET" or equipLoc == "INVTYPE_WEAPON" then
        local first = self:GetEquippedSlotInfo(slots[1])
        local second = self:GetEquippedSlotInfo(slots[2])
        if not first then
            return nil, slots[1]
        end
        if not second then
            return nil, slots[2]
        end
        if (first.score or 0) <= (second.score or 0) then
            return first, slots[1]
        end
        return second, slots[2]
    end

    if equipLoc == "INVTYPE_2HWEAPON" then
        local mainHand = self:GetEquippedSlotInfo(16)
        local offHand = self:GetEquippedSlotInfo(17)
        return {
            slotID = 16,
            itemID = mainHand and mainHand.itemID or nil,
            link = mainHand and mainHand.link or nil,
            score = (mainHand and mainHand.score or 0) + (offHand and offHand.score or 0),
            itemLevel = math.floor((((mainHand and mainHand.itemLevel or 0) + (offHand and offHand.itemLevel or 0)) / 2) + 0.5),
        }, 16
    end

    return self:GetEquippedSlotInfo(slots[1]), slots[1]
end

function addon:GetBaselineFromGear(equipLoc, gearMap)
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
            return nil
        end
        if not second then
            return nil
        end
        if (first.itemLevel or 0) <= (second.itemLevel or 0) then
            return first
        end
        return second
    end

    if equipLoc == "INVTYPE_2HWEAPON" then
        local mainHand = getSlot(16)
        local offHand = getSlot(17)
        return {
            slotID = 16,
            itemID = mainHand and mainHand.itemID or nil,
            link = mainHand and mainHand.link or nil,
            itemLevel = math.floor((((mainHand and mainHand.itemLevel or 0) + (offHand and offHand.itemLevel or 0)) / 2) + 0.5),
        }
    end

    return getSlot(slots[1])
end

function addon:GetTopStatSummary(stats, weights)
    local contributions = {}
    for token, amount in pairs(stats) do
        if token ~= weights.PRIMARY_TOKEN and token ~= "STAMINA" then
            local weight = weights[token]
            if weight and amount and amount > 0 then
                table.insert(contributions, {
                    token = token,
                    score = amount * weight,
                    amount = amount,
                })
            end
        end
    end

    table.sort(contributions, function(left, right)
        return left.score > right.score
    end)

    if #contributions == 0 then
        return nil
    end

    local firstAmt = contributions[1] and contributions[1].amount or 0
    local first = (addon.L and addon.L[contributions[1].token]) or self.constants.statLabels[contributions[1].token] or contributions[1].token
    local firstStr = firstAmt .. " " .. first

    local secondAmt = contributions[2] and contributions[2].amount
    local second = contributions[2] and ((addon.L and addon.L[contributions[2].token]) or self.constants.statLabels[contributions[2].token] or contributions[2].token)
    
    if second then
        return firstStr .. "  " .. (addon.L and addon.L.META_SEPARATOR or "-") .. "  " .. secondAmt .. " " .. second
    end
    return firstStr
end

function addon:GetItemAnalysisFlags(itemLink, stats, weights)
    local _, _, _, equipLoc = GetItemInfoInstant(itemLink)
    local primaryToken = weights and weights.PRIMARY_TOKEN or nil
    local modeledCombatStatTotal = 0

    if primaryToken and stats[primaryToken] then
        modeledCombatStatTotal = modeledCombatStatTotal + (stats[primaryToken] or 0)
    end

    modeledCombatStatTotal = modeledCombatStatTotal
        + (stats.HASTE or 0)
        + (stats.MASTERY or 0)
        + (stats.CRIT or 0)
        + (stats.VERS or 0)

    local isTrinket = equipLoc == "INVTYPE_TRINKET"
    local approximate = false
    local note = nil

    if isTrinket then
        approximate = true
        if modeledCombatStatTotal > 0 then
            note = addon.L.SUMMARY_APPROX_TRINKET
        else
            note = addon.L.SUMMARY_APPROX_EFFECT
        end
    elseif modeledCombatStatTotal <= 0 then
        approximate = true
        note = addon.L.SUMMARY_APPROX_EFFECT
    end

    return {
        equipLoc = equipLoc,
        isTrinket = isTrinket,
        approximate = approximate,
        note = note,
        modeledCombatStatTotal = modeledCombatStatTotal,
    }
end

function addon:IsBisItem(specID, itemID)
    local externalBis = self.externalData and self.externalData.bis and self.externalData.bis[specID]
    if type(externalBis) == "table" and externalBis[itemID] == true then
        return true
    end

    local localBis = self.db and self.db.bis and self.db.bis[specID]
    return type(localBis) == "table" and localBis[itemID] == true
end

function addon:EvaluateItemForSelf(itemLink)
    local profile = self.localProfile
    local canUse, reason = self:CanUseItemForSelf(itemLink, profile)
    if not canUse then
        return {
            status = "PASS",
            reason = reason,
        }
    end

    local score, itemLevel, stats = self:GetScoreForItem(itemLink, profile)
    local itemID, _, _, equipLoc = GetItemInfoInstant(itemLink)
    local baseline, slotID = self:GetBaselineForEquipLoc(equipLoc)
    local baselineScore = baseline and baseline.score or 0
    local baselineItemLevel = baseline and baseline.itemLevel or 0
    local delta = score - baselineScore
    local summary = self:GetTopStatSummary(stats, profile.weights)
    local analysis = self:GetItemAnalysisFlags(itemLink, stats, profile.weights)
    local status = "PASS"

    if self:IsBisItem(profile.specID, itemID) then
        status = "BIS"
    elseif not baseline or baselineScore == 0 then
        status = "UPGRADE"
    elseif delta >= (self.db.options.majorUpgrade or 12) then
        status = "UPGRADE"
    elseif delta >= (self.db.options.minUpgrade or 3) then
        status = "SIDEGRADE"
    end

    if analysis.approximate and status == "PASS" and baselineItemLevel > 0 and itemLevel > baselineItemLevel then
        status = "SIDEGRADE"
    end

    if analysis.note and analysis.note ~= "" then
        if summary and summary ~= "" then
            summary = summary .. "  " .. (addon.L and addon.L.META_SEPARATOR or "-") .. "  " .. analysis.note
        else
            summary = analysis.note
        end
    end

    return {
        status = status,
        score = score,
        delta = delta,
        itemLevel = itemLevel,
        summary = summary,
        approximate = analysis.approximate,
        equipLoc = equipLoc,
        slotID = slotID,
        baselineItemID = baseline and baseline.itemID or nil,
        baselineLink = baseline and baseline.link or nil,
        baselineItemLevel = baselineItemLevel,
        reason = reason,
    }
end
