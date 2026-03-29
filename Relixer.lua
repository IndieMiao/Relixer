----- BINDINGS -----

BINDING_HEADER_RELIXER = "Relixer";

------ HELPER FUNCTIONS ------

local function getSpellId(targetSpellName, targetSpellRank)
    local lastMatch = nil
    for i = 1, 200 do
        local spellName, spellRank = GetSpellName(i, "spell")
        if spellName == targetSpellName then
            lastMatch = i -- Keep track of the latest match
            if targetSpellRank and spellRank == targetSpellRank then
                return i -- Return immediately if rank matches
            end
        end
    end
    return lastMatch -- Return the highest rank if no specific rank is requested
end



local function GetCooldown(spellId)
	if not spellId then
		return 10
	end

	local start, duration, enabled = GetSpellCooldown(spellId, "spell")
	if duration == 0 then
		return 0
	end

	return start + duration - GetTime()
end

local function SpellReady(spellId)
    local start, duration, enabled = GetSpellCooldown(spellId, "spell")
    return duration == 0
end

local function ItemLinkToName(link)
	if ( link ) then
   	return gsub(link,"^.*%[(.*)%].*$","%1");
	end
end

local function FindItem(item)
	if ( not item ) then return; end
	item = string.lower(ItemLinkToName(item));
	local link;
	for i = 1,23 do
		link = GetInventoryItemLink("player",i);
		if ( link ) then
			if ( item == string.lower(ItemLinkToName(link)) )then
				return i, nil, GetInventoryItemTexture('player', i), GetInventoryItemCount('player', i);
			end
		end
	end
	local count, bag, slot, texture;
	local totalcount = 0;
	for i = 0,NUM_BAG_FRAMES do
		for j = 1,MAX_CONTAINER_ITEMS do
			link = GetContainerItemLink(i,j);
			if ( link ) then
				if ( item == string.lower(ItemLinkToName(link))) then
					bag, slot = i, j;
					texture, count = GetContainerItemInfo(i,j);
					totalcount = totalcount + count;
				end
			end
		end
	end
	return bag, slot, texture, totalcount;
end

local function UseItemByName(item)
	local bag,slot = FindItem(item);
	if ( not bag ) then return; end;
	if ( slot ) then
		UseContainerItem(bag,slot); -- use, equip item in bag
		return bag, slot;
	else
		UseInventoryItem(bag); -- unequip from body
		return bag;
	end
end

function EquipItemByName(itemName)
    for bag = 0, 4 do  -- Loops through all bags (0 to 4 includes backpack and additional bags)
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink and string.find(itemLink, itemName) then
                UseContainerItem(bag, slot)  -- Equips the item
                return  -- Stop searching once the item is found and equipped
            end
        end
    end
end


-- Check if a specific totem is equipped in the relic slot
local function IsRelicEquipped(itemName)
    local equippedItemLink = GetInventoryItemLink("player", 18) -- Slot 18 is used for ranged/relic slot
    if equippedItemLink and string.find(equippedItemLink, itemName) then
        return true
    end
    return false
end

-- Relic slot equip cooldown (seconds the relic must be equipped before its bonus is active)
local RELIC_EQUIP_CD = 1.5

-- Pending delayed cast after relic swap
local pendingCastId = nil
local pendingCastAt  = 0

local relixerTimer = CreateFrame("Frame")
relixerTimer:SetScript("OnUpdate", function()
    if pendingCastId and GetTime() >= pendingCastAt then
        local spellId = pendingCastId
        pendingCastId = nil
        if SpellReady(spellId) and UnitCanAttack("player", "target") then
            CastSpell(spellId, "spell")
        end
    end
end)

------ RELIC MONITOR FRAME ------

local relicMonitorFrame = nil
local relicMonitorIcon = nil
local lastRelicLink = nil
local relicMonitorLocked = true

local function UpdateRelicMonitor(force)
	if not relicMonitorFrame then
		return
	end
	if not relicMonitorIcon then
		return
	end

	local relicLink = GetInventoryItemLink("player", 18)
	if not force and relicLink == lastRelicLink then
		return
	end
	lastRelicLink = relicLink

	if relicLink then
		local relicTexture = GetInventoryItemTexture("player", 18)
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
		if not relicMonitorLocked then
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

	local elapsedSinceUpdate = 0
	relicMonitorFrame:SetScript("OnUpdate", function()
		elapsedSinceUpdate = elapsedSinceUpdate + arg1
		if elapsedSinceUpdate >= 0.25 then
			elapsedSinceUpdate = 0
			UpdateRelicMonitor(false)
		end
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

function Relixer_ToggleRelicMonitorLock()
	relicMonitorLocked = not relicMonitorLocked
end

CreateRelicMonitorFrame()

local function CastSwapByName(targetSpellName, targetSpellRank, itemName)
    local spellId = getSpellId(targetSpellName, targetSpellRank)
    if not spellId then return end
    if not SpellReady(spellId) then return end

    if IsRelicEquipped(itemName) then
        -- Relic already equipped; cancel any pending delayed cast and fire immediately
        pendingCastId = nil
        CastSpell(spellId, "spell")
    else
        -- Equip the relic and schedule the spell cast after RELIC_EQUIP_CD
        -- so the relic bonus is active when the spell lands.
        -- The 1.5 s equip CD aligns with the shock/LS GCD, so by the time
        -- the pending cast fires both cooldowns have expired.
        UseItemByName(itemName)
        pendingCastId = spellId
        pendingCastAt  = GetTime() + RELIC_EQUIP_CD
    end
end


------ LS ------

function Relixer_LS()

    local lsCooldown = GetCooldown(getSpellId("Lightning Strike"))
	
	if not IsRelicEquipped("Totem of Crackling Thunder") and lsCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Lightning Strike") == 1 then
		--QueueScript('EquipItemByName("Totem of Crackling Thunder");CastSpellByName("Lightning Strike")')
		CastSwapByName("Lightning Strike", nil, "Totem of Crackling Thunder")
	else
		CastSpellByName("Lightning Strike")
    end
end

------ SHOCKS ------

function Relixer_FrostShockMax()

    local shockCooldown = GetCooldown(getSpellId("Frost Shock"))

	if not IsRelicEquipped("Totem of the Stonebreaker") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Frost Shock") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Frost Shock")')
		CastSwapByName("Frost Shock", nil, "Totem of the Stonebreaker")
	else
		CastSpellByName("Frost Shock")
    end
end


function Relixer_FrostShockMin()

    local shockCooldown = GetCooldown(getSpellId("Frost Shock"))

	if not IsRelicEquipped("Totem of the Stonebreaker") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Frost Shock") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Frost Shock(Rank 1)")')
		CastSwapByName("Frost Shock", "Rank 1", "Totem of the Stonebreaker")
	else
		CastSpellByName("Frost Shock(Rank 1)")
    end
end

function Relixer_EarthShockMax()

    local shockCooldown = GetCooldown(getSpellId("Earth Shock"))

	if not IsRelicEquipped("Totem of the Stonebreaker") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Earth Shock") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Earth Shock")')
		CastSwapByName("Earth Shock", nil, "Totem of the Stonebreaker")
	else
		CastSpellByName("Earth Shock")
    end
end

function Relixer_EarthShockMin()

    local shockCooldown = GetCooldown(getSpellId("Earth Shock"))

	if not IsRelicEquipped("Totem of the Stonebreaker") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Earth Shock") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Earth Shock(Rank 1)")')
		CastSwapByName("Earth Shock", "Rank 1", "Totem of the Stonebreaker")
	else
		CastSpellByName("Earth Shock(Rank 1)")
    end
end

function Relixer_FlameShockMax()

    local shockCooldown = GetCooldown(getSpellId("Flame Shock"))

	if not IsRelicEquipped("Totem of the Stonebreaker") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Flame Shock") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Flame Shock")')
		CastSwapByName("Flame Shock", nil, "Totem of the Stonebreaker")
	else
		CastSpellByName("Flame Shock")
    end
end

function Relixer_FlameShockMin()

    local shockCooldown = GetCooldown(getSpellId("Flame Shock"))

	if not IsRelicEquipped("Totem of the Stonebreaker") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Flame Shock") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Flame Shock(Rank 1)")')
		CastSwapByName("Flame Shock", "Rank 1", "Totem of the Stonebreaker")
	else
		CastSpellByName("Flame Shock(Rank 1)")
    end
end

function Relixer_FireShock()

    local shockCooldown = GetCooldown(getSpellId("Flame Shock"))

	if not IsRelicEquipped("Totem of Rage") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Flame Shock") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Flame Shock(Rank 1)")')
		CastSwapByName("Flame Shock", nil, "Totem of Rage")
	else
		CastSpellByName("Flame Shock")
    end
end

function Relixer_MB()

    local shockCooldown = GetCooldown(getSpellId("Molten Blast"))

	if not IsRelicEquipped("Totem of Eruption") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Flame Shock") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Flame Shock(Rank 1)")')
		CastSwapByName("Molten Blast", nil, "Totem of Eruption")
	else
		CastSpellByName("Molten Blast")
    end
end

function Relixer_LB()

    local shockCooldown = GetCooldown(getSpellId("Lightning Bolt"))

	if not IsRelicEquipped("Totem of the Storm") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Flame Shock") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Flame Shock(Rank 1)")')
		CastSwapByName("Lightning Bolt", nil, "Totem of the Storm")
	else
		CastSpellByName("Lightning Bolt")
    end
end

function Relixer_CL()

    local shockCooldown = GetCooldown(getSpellId("Chain Lightning"))

	if not IsRelicEquipped("Totem of the Storm") and shockCooldown == 0 and UnitCanAttack("player", "target")  and IsSpellInRange("Chain Lightning") == 1 then
		--QueueScript('EquipItemByName("Totem of the Stonebreaker");CastSpellByName("Flame Shock(Rank 1)")')
		CastSwapByName("Chain Lightning", nil, "Totem of the Storm")
	else
		CastSpellByName("Chain Lightning")
    end
end

function Relixer_CLL()

    local clCooldown = GetCooldown(getSpellId("Chain Lightning"))
	

	if clCooldown == 0  then

		if not IsRelicEquipped("Totem of the Storm") and UnitCanAttack("player", "target")  and IsSpellInRange("Chain Lightning") == 1 then
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

SLASH_RELIXER_MONITORLOCK1 = "/relixermonitorlock"
SlashCmdList["RELIXER_MONITORLOCK"] = Relixer_ToggleRelicMonitorLock