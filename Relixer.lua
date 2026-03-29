----- BINDINGS -----

BINDING_HEADER_RELIXER = "Relixer"

------ HELPER FUNCTIONS ------

local RelixerSpellIdCache = {}
local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"
local RELIC_SLOT = 18

local spellCacheFrame = CreateFrame("Frame")
spellCacheFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
spellCacheFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
spellCacheFrame:SetScript("OnEvent", function()
	RelixerSpellIdCache = {}
end)

local function getSpellId(targetSpellName, targetSpellRank)
	local cacheKey
	if targetSpellRank and targetSpellRank ~= "" then
		cacheKey = targetSpellName .. "|" .. targetSpellRank
	else
		cacheKey = targetSpellName
	end

	local cachedId = RelixerSpellIdCache[cacheKey]
	if cachedId then
		return cachedId
	end

	-- NamPower fast path: direct lookup by spell name/rank.
	-- Only use spell IDs when spell-id cooldown API is available.
	if type(GetSpellIdForName) == "function" and type(GetSpellIdCooldown) == "function" then
		local queryName = targetSpellName
		if targetSpellRank and targetSpellRank ~= "" then
			queryName = targetSpellName .. "(" .. targetSpellRank .. ")"
		end
			local npSpellId = GetSpellIdForName(queryName)
		if npSpellId and npSpellId > 0 then
			RelixerSpellIdCache[cacheKey] = npSpellId
			return npSpellId
		end
	end

	local lastMatch = nil
	for i = 1, 200 do
		local spellName, spellRank = GetSpellName(i, "spell")
		if spellName == targetSpellName then
			lastMatch = i -- Keep track of the latest match
			if targetSpellRank and spellRank == targetSpellRank then
				RelixerSpellIdCache[cacheKey] = i
				return i -- Return immediately if rank matches
			end
		end
	end
	RelixerSpellIdCache[cacheKey] = lastMatch
    return lastMatch -- Return the highest rank if no specific rank is requested
end



local function GetCooldown(spellId)
	if not spellId then
		return 10
	end

	if type(GetSpellIdCooldown) == "function" then
		local cd = GetSpellIdCooldown(spellId)
		if cd and cd.cooldownRemainingMs then
			return cd.cooldownRemainingMs / 1000
		end
	end

	local start, duration, enabled = GetSpellCooldown(spellId, "spell")
	if duration == 0 then
		return 0
	end

	return start + duration - GetTime()
end

local function SpellReady(spellId)
	if type(GetSpellIdCooldown) == "function" then
		local cd = GetSpellIdCooldown(spellId)
		if cd and cd.isOnCooldown ~= nil then
			return cd.isOnCooldown == 0
		end
	end

	local start, duration, enabled = GetSpellCooldown(spellId, "spell")
	return duration == 0
end

local function ItemLinkToName(link)
	if link then
		return string.gsub(link, "^.*%[(.*)%].*$", "%1")
	end
end

local function FindItem(item)
	if not item then
		return
	end

	item = string.lower(ItemLinkToName(item))
	local link

	for i = 1, 23 do
		link = GetInventoryItemLink(PLAYER_UNIT, i)
		if link then
			if item == string.lower(ItemLinkToName(link)) then
				return i, nil, GetInventoryItemTexture(PLAYER_UNIT, i), GetInventoryItemCount(PLAYER_UNIT, i)
			end
		end
	end

	local count, bag, slot, texture
	local totalcount = 0
	for i = 0, NUM_BAG_FRAMES do
		for j = 1, MAX_CONTAINER_ITEMS do
			link = GetContainerItemLink(i, j)
			if link then
				if item == string.lower(ItemLinkToName(link)) then
					bag, slot = i, j
					texture, count = GetContainerItemInfo(i, j)
					totalcount = totalcount + count
				end
			end
		end
	end

	return bag, slot, texture, totalcount
end

local function UseItemByName(item)
	local bag, slot = FindItem(item)
	if not bag then
		return
	end

	if slot then
		UseContainerItem(bag, slot) -- use, equip item in bag
		return bag, slot
	else
		UseInventoryItem(bag) -- unequip from body
		return bag
	end
end

function EquipItemByName(itemName)
	for bag = 0, 4 do -- Loops through all bags (0 to 4 includes backpack and additional bags)
		for slot = 1, GetContainerNumSlots(bag) do
			local itemLink = GetContainerItemLink(bag, slot)
			if itemLink and string.find(itemLink, itemName, 1, true) then
				UseContainerItem(bag, slot) -- Equips the item
				return -- Stop searching once the item is found and equipped
			end
		end
	end
end


-- Check if a specific totem is equipped in the relic slot
local function IsRelicEquipped(itemName)
	local equippedItemLink = GetInventoryItemLink(PLAYER_UNIT, RELIC_SLOT)
	if equippedItemLink and string.find(equippedItemLink, itemName, 1, true) then
		return true
	end
	return false
end

-- Relic slot equip cooldown (seconds the relic must be equipped before its bonus is active)
local RELIC_EQUIP_CD = 1.5

-- Pending delayed cast after relic swap
local pendingCastName = nil
local pendingCastRank = nil
local pendingCastAt   = 0

local function BuildSpellCastName(spellName, spellRank)
	if spellRank and spellRank ~= "" then
		return spellName .. "(" .. spellRank .. ")"
	end
	return spellName
end

local relixerTimer = CreateFrame("Frame")
relixerTimer:SetScript("OnUpdate", function()
	if pendingCastName and GetTime() >= pendingCastAt then
		local spellName = pendingCastName
		local spellRank = pendingCastRank
		pendingCastName = nil
		pendingCastRank = nil
		local spellId = getSpellId(spellName, spellRank)
		if SpellReady(spellId) and UnitCanAttack(PLAYER_UNIT, TARGET_UNIT) then
			CastSpellByName(BuildSpellCastName(spellName, spellRank))
        end
    end
end)

------ RELIC MONITOR FRAME ------

local relicMonitorFrame = nil
local relicMonitorIcon = nil
local lastRelicLink = nil

local function UpdateRelicMonitor(force)
	if not relicMonitorFrame then
		return
	end
	if not relicMonitorIcon then
		return
	end

	local relicLink = GetInventoryItemLink(PLAYER_UNIT, RELIC_SLOT)
	if not force and relicLink == lastRelicLink then
		return
	end
	lastRelicLink = relicLink

	if relicLink then
		local relicTexture = GetInventoryItemTexture(PLAYER_UNIT, RELIC_SLOT)
		relicMonitorIcon:SetTexture(relicTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
	else
		relicMonitorIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	end
end

local function CreateRelicMonitorFrame()
	relicMonitorFrame = CreateFrame("Frame", "RelixerRelicMonitorFrame", UIParent)
	relicMonitorFrame:SetWidth(26)
	relicMonitorFrame:SetHeight(26)
	relicMonitorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
	relicMonitorFrame:EnableMouse(true)
	relicMonitorFrame:SetMovable(true)
	relicMonitorFrame:RegisterForDrag("LeftButton")
	relicMonitorFrame:SetScript("OnDragStart", function()
		if IsShiftKeyDown() then
			relicMonitorFrame:StartMoving()
		end
	end)
	relicMonitorFrame:SetScript("OnDragStop", function()
		relicMonitorFrame:StopMovingOrSizing()
	end)

	relicMonitorIcon = relicMonitorFrame:CreateTexture(nil, "ARTWORK")
	relicMonitorIcon:SetWidth(24)
	relicMonitorIcon:SetHeight(24)
	relicMonitorIcon:SetPoint("CENTER", relicMonitorFrame, "CENTER", 0, 0)

	relicMonitorFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	relicMonitorFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
	relicMonitorFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	relicMonitorFrame:SetScript("OnEvent", function()
		UpdateRelicMonitor(true)
	end)

	UpdateRelicMonitor(true)
end

function Relixer_ToggleRelicMonitor()
	if not relicMonitorFrame then
		return
	end

	if relicMonitorFrame:IsShown() then
		relicMonitorFrame:Hide()
	else
		relicMonitorFrame:Show()
		UpdateRelicMonitor(true)
	end
end

CreateRelicMonitorFrame()

local function CastSwapByName(targetSpellName, targetSpellRank, itemName)
	local spellId = getSpellId(targetSpellName, targetSpellRank)
	if not spellId then return end
	if not SpellReady(spellId) then return end
	local spellCastName = BuildSpellCastName(targetSpellName, targetSpellRank)

	if IsRelicEquipped(itemName) then
		-- Relic already equipped; cancel any pending delayed cast and fire immediately
		pendingCastName = nil
		pendingCastRank = nil
		CastSpellByName(spellCastName)
	else
		-- Equip the relic and schedule the spell cast after RELIC_EQUIP_CD
		-- so the relic bonus is active when the spell lands.
		-- The 1.5 s equip CD aligns with the shock/LS GCD, so by the time
		-- the pending cast fires both cooldowns have expired.
		UseItemByName(itemName)
		pendingCastName = targetSpellName
		pendingCastRank = targetSpellRank
		pendingCastAt   = GetTime() + RELIC_EQUIP_CD
	end
end

local function TryCastWithRelicSwap(spellName, spellRank, relicName, rangeSpellName)
	local spellId = getSpellId(spellName, spellRank)
	local spellCooldown = GetCooldown(spellId)
	local rangeCheckSpell = rangeSpellName or spellName

	if not IsRelicEquipped(relicName)
		and spellCooldown == 0
		and UnitCanAttack(PLAYER_UNIT, TARGET_UNIT)
		and IsSpellInRange(rangeCheckSpell) == 1
	then
		CastSwapByName(spellName, spellRank, relicName)
	else
		CastSpellByName(BuildSpellCastName(spellName, spellRank))
	end
end


------ LS ------

function Relixer_LS()
	TryCastWithRelicSwap("Lightning Strike", nil, "Totem of Crackling Thunder")
end

------ SHOCKS ------

function Relixer_FrostShockMax()
	TryCastWithRelicSwap("Frost Shock", nil, "Totem of the Stonebreaker")
end


function Relixer_FrostShockMin()
	TryCastWithRelicSwap("Frost Shock", "Rank 1", "Totem of the Stonebreaker")
end

function Relixer_EarthShockMax()
	TryCastWithRelicSwap("Earth Shock", nil, "Totem of the Stonebreaker")
end

function Relixer_EarthShockMin()
	TryCastWithRelicSwap("Earth Shock", "Rank 1", "Totem of the Stonebreaker")
end

function Relixer_FlameShockMax()
	TryCastWithRelicSwap("Flame Shock", nil, "Totem of the Stonebreaker")
end

function Relixer_FlameShockMin()
	TryCastWithRelicSwap("Flame Shock", "Rank 1", "Totem of the Stonebreaker")
end

function Relixer_FireShock()
	TryCastWithRelicSwap("Flame Shock", nil, "Totem of Rage")
end

function Relixer_MB()
	TryCastWithRelicSwap("Molten Blast", nil, "Totem of Eruption", "Flame Shock")
end

function Relixer_LB()
	TryCastWithRelicSwap("Lightning Bolt", nil, "Totem of the Storm", "Flame Shock")
end

function Relixer_CL()
	TryCastWithRelicSwap("Chain Lightning", nil, "Totem of the Storm")
end

function Relixer_CLL()
	local clCooldown = GetCooldown(getSpellId("Chain Lightning"))

	if clCooldown == 0 then
		if not IsRelicEquipped("Totem of the Storm") and UnitCanAttack(PLAYER_UNIT, TARGET_UNIT) and IsSpellInRange("Chain Lightning") == 1 then
			CastSwapByName("Chain Lightning", nil, "Totem of the Storm")
		else
			CastSpellByName("Chain Lightning")
		end
	else
		Relixer_LB()
	end
end


------ SLASH COMMANDS ------

SLASH_RELIXER_LS1 = "/relixerls"
SlashCmdList["RELIXER_LS"] = Relixer_LS

SLASH_RELIXER_FROSTSHOCKMAX1 = "/relixerfrostshockmax"
SlashCmdList["RELIXER_FROSTSHOCKMAX"] = Relixer_FrostShockMax

SLASH_RELIXER_FROSTSHOCKMIN1 = "/relixerfrostshockmin"
SlashCmdList["RELIXER_FROSTSHOCKMIN"] = Relixer_FrostShockMin

SLASH_RELIXER_EARTHSHOCKMAX1 = "/relixerearthshockmax"
SlashCmdList["RELIXER_EARTHSHOCKMAX"] = Relixer_EarthShockMax

SLASH_RELIXER_EARTHSHOCKMIN1 = "/relixerearthshockmin"
SlashCmdList["RELIXER_EARTHSHOCKMIN"] = Relixer_EarthShockMin

SLASH_RELIXER_FLAMESHOCKMAX1 = "/relixerflameshockmax"
SlashCmdList["RELIXER_FLAMESHOCKMAX"] = Relixer_FlameShockMax

SLASH_RELIXER_FLAMESHOCKMIN1 = "/relixerflameshockmin"
SlashCmdList["RELIXER_FLAMESHOCKMIN"] = Relixer_FlameShockMin

SLASH_RELIXER_FIRESHOCK1 = "/relixerfireshock"
SlashCmdList["RELIXER_FIRESHOCK"] = Relixer_FireShock

SLASH_RELIXER_MB1 = "/relixermb"
SlashCmdList["RELIXER_MB"] = Relixer_MB

SLASH_RELIXER_LB1 = "/relixerlb"
SlashCmdList["RELIXER_LB"] = Relixer_LB

SLASH_RELIXER_CL1 = "/relixercl"
SlashCmdList["RELIXER_CL"] = Relixer_CL

SLASH_RELIXER_CLL1 = "/relixercll"
SlashCmdList["RELIXER_CLL"] = Relixer_CLL

SLASH_RELIXER_MONITOR1 = "/relixermonitor"
SlashCmdList["RELIXER_MONITOR"] = Relixer_ToggleRelicMonitor
