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


local function CastSwapByName(targetSpellName, targetSpellRank, itemName)
    local spellId = getSpellId(targetSpellName, targetSpellRank)
    if spellId then
        local spellReady = SpellReady(spellId)
        if spellReady then
            UseItemByName(itemName)
            CastSpell(spellId, "spell")
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