local HttpService = game:GetService("HttpService")

local InventoryViewModel = {}

local CATEGORY_ORDER = { "Fists", "Pets", "Honor", "Boosts" }
local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Secret", "Premium", "Unknown" }
local SIGNATURE_STATS_FIELDS = {
	"OwnedFistsJSON",
	"OwnedPremiumFistsJSON",
	"EquippedFist",
	"PetInventoryJSON",
	"EquippedPetsJSON",
	"LockedPetsJSON",
	"OwnedHonorItemsJSON",
	"EquippedHonorItem",
	"Honor",
	"Depth",
	"Rebirths",
	"ShopBoosts",
}
local EMPTY_TABLE = {}
local CONFIG_SIGNATURE_CACHE = setmetatable({}, { __mode = "k" })
local RARITY_NAMES = {
	common = "Common",
	rare = "Rare",
	epic = "Epic",
	legendary = "Legendary",
	secret = "Secret",
	premium = "Premium",
	unknown = "Unknown",
}
local CATEGORY_ALIASES = {
	all = "all",
	fist = "fists",
	fists = "fists",
	glove = "fists",
	gloves = "fists",
	pet = "pets",
	pets = "pets",
	honor = "honor",
	honour = "honor",
	boost = "boosts",
	boosts = "boosts",
}
local UNKNOWN_ACCENT = Color3.fromRGB(121, 137, 148)

local BOOST_DEFINITIONS = {
	{
		name = "CoinBoost",
		displayName = "COIN BOOST x2",
		timer = "CoinEndsAt",
		rarity = "Epic",
		art = "CoinBoost",
		icon = "Coin",
		accent = Color3.fromRGB(202, 71, 230),
		detail = "Earn 2x Coins while active.",
	},
	{
		name = "SpeedBoost",
		displayName = "SPEED BOOST",
		timer = "SpeedEndsAt",
		rarity = "Rare",
		art = "SpeedBoost",
		icon = "Train",
		accent = Color3.fromRGB(58, 201, 248),
		detail = "Move faster while active.",
	},
	{
		name = "DamageBoost",
		displayName = "DAMAGE BOOST x2",
		timer = "DamageEndsAt",
		rarity = "Epic",
		art = "DamageBoost",
		icon = "Punch",
		accent = Color3.fromRGB(239, 112, 51),
		detail = "Deal 2x wall damage while active.",
	},
	{
		name = "TrainingBoost",
		displayName = "TRAINING BOOST x2",
		timer = "TrainingEndsAt",
		rarity = "Epic",
		art = "SpeedBoost",
		icon = "Train",
		accent = Color3.fromRGB(59, 218, 150),
		detail = "Train Power 2x faster while active.",
	},
}

local function decodeTable(value)
	if type(value) == "table" then
		return value
	end
	if type(value) ~= "string" or value == "" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(value)
	end)
	return ok and type(decoded) == "table" and decoded or {}
end

local function numericEntries(value)
	local decoded = decodeTable(value)
	local entries = {}
	for index, entry in pairs(decoded) do
		if type(index) == "number" and index >= 1 and index % 1 == 0 then
			table.insert(entries, { index = index, value = entry })
		end
	end
	table.sort(entries, function(left, right)
		return left.index < right.index
	end)
	return entries
end

local function listSet(value)
	local result = {}
	for _, entry in ipairs(numericEntries(value)) do
		if type(entry.value) == "string" and entry.value ~= "" then
			result[entry.value] = true
		end
	end
	return result
end

local function listCounts(value)
	local result = {}
	for _, entry in ipairs(numericEntries(value)) do
		if type(entry.value) == "string" and entry.value ~= "" then
			result[entry.value] = (result[entry.value] or 0) + 1
		end
	end
	return result
end

local function normalizeRarity(value)
	local key = string.lower(tostring(value or ""))
	return RARITY_NAMES[key]
end

-- Canonical owned-fist label contract. This mirrors the live Shop tier
-- presentation without changing price, multiplier, ownership, or unlock data.
local FIST_TIER_RARITY = {
	[1] = "Common",
	[2] = "Rare",
	[3] = "Rare",
	[4] = "Epic",
}

local function canonicalFistRarity(definition, premium)
	local explicit = normalizeRarity(definition and definition.rarity)
	if explicit then
		return explicit
	end
	if premium or (definition and definition.robux) then
		return "Premium"
	end
	local tier = math.max(1, math.floor(tonumber(definition and definition.tier) or 1))
	return FIST_TIER_RARITY[tier] or "Legendary"
end

local function inferRarity(definition, kind, premium)
	if kind == "Fist" then
		return canonicalFistRarity(definition, premium)
	end
	local explicit = normalizeRarity(definition and definition.rarity)
	if explicit then
		return explicit
	end
	if premium or (definition and definition.robux) then
		return "Premium"
	end
	if kind == "Honor" then
		local bonus = math.max(0, tonumber(definition and definition.powerBonus) or 0)
		if bonus >= 0.25 then return "Legendary" end
		if bonus >= 0.15 then return "Epic" end
		if bonus >= 0.10 then return "Rare" end
		return "Common"
	end
	return "Unknown"
end

local function formatDecimal(value)
	local text = string.format("%.2f", tonumber(value) or 0)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

local function parsePetToken(GameConfig, value)
	local token = tostring(value or "")
	local name, stars = string.match(token, "^(.-)#(%d+)$")
	if not name or name == "" then
		name = token
		stars = 1
	end
	local maxStars = math.max(1, math.floor(tonumber(GameConfig.MaxPetStars) or 5))
	return name ~= "" and name or "Unknown Pet", math.clamp(math.floor(tonumber(stars) or 1), 1, maxStars), token
end

local function catalogEntries(catalog)
	local result = {}
	for _, entry in ipairs(numericEntries(catalog)) do
		if type(entry.value) == "table" and type(entry.value.name) == "string" and entry.value.name ~= "" then
			table.insert(result, entry.value)
		end
	end
	return result
end

local function makeDefinitionMap(baseCatalog, premiumCatalog)
	local result = {}
	for _, definition in ipairs(catalogEntries(baseCatalog)) do
		result[definition.name] = { definition = definition, premium = false }
	end
	for _, definition in ipairs(catalogEntries(premiumCatalog)) do
		result[definition.name] = { definition = definition, premium = true }
	end
	return result
end

local function fistArt(GameConfig, definition)
	if type(definition.art) == "string" and definition.art ~= "" then
		return definition.art
	end
	local art = type(GameConfig.ShopArt) == "table" and GameConfig.ShopArt or {}
	if definition.style == "Vanguard" then return art.StarterGlove or "" end
	if definition.style == "Storm" then return art.ChampionGlove or "" end
	if definition.style == "Celestial" then return art.TitanGlove or "" end
	if definition.style == "Starter" or definition.style == "Boxing" then return art.StarterGlove or "" end
	if definition.style == "Iron" then return art.ChampionGlove or "" end
	if definition.style == "Thunder" or definition.style == "Titan" then return art.TitanGlove or "" end
	local tier = math.max(1, math.floor(tonumber(definition.tier) or 1))
	if tier == 1 then return art.StarterGlove or "" end
	if tier >= 5 then return art.TitanGlove or "" end
	return art.ChampionGlove or ""
end

local function petArt(GameConfig, definition)
	if definition and type(definition.art) == "string" and definition.art ~= "" then
		return definition.art
	end
	local artPack = type(GameConfig.PetInventoryArt) == "table" and GameConfig.PetInventoryArt or {}
	local entries = type(artPack.entries) == "table" and artPack.entries or {}
	local artEntry = definition and entries[definition.artKey]
	if type(artEntry) == "table"
		and type(artEntry.assetId) == "string"
		and string.match(artEntry.assetId, "^rbxassetid://%d+$")
	then
		return artEntry.assetId
	end
	local graphics = type(GameConfig.GeneratedGraphics) == "table" and GameConfig.GeneratedGraphics or {}
	return graphics.Iteration02PetIcon or ""
end

local function honorArt(GameConfig, definition)
	if definition and type(definition.art) == "string" and definition.art ~= "" then
		return definition.art
	end
	local art = type(GameConfig.ShopArt) == "table" and GameConfig.ShopArt or {}
	return art.HonorIcon or ""
end

local function actionDescriptor(name, label, payload, enabled, accent, options)
	options = options or {}
	return {
		name = name,
		label = label,
		enabled = enabled ~= false,
		payload = payload,
		accent = accent or UNKNOWN_ACCENT,
		confirm = options.confirm == true,
		destructive = options.destructive == true,
		primary = options.primary == true,
	}
end

local function finalizeItem(item)
	item.kind = tostring(item.kind or item.category or "Item")
	item.quantity = math.max(1, math.floor(tonumber(item.quantity) or 1))
	item.equipped = item.equipped == true
	item.locked = item.locked == true
	item.accent = item.accent or UNKNOWN_ACCENT
	item.art = type(item.art) == "string" and item.art or ""
	item.icon = type(item.icon) == "string" and item.icon or ""
	item.token = type(item.token) == "string" and item.token or ""
	item.slot = item.slot or false
	item.detail = tostring(item.detail or "")
	item.description = item.detail
	item.actions = type(item.actions) == "table" and item.actions or {}
	item.viewOnly = item.viewOnly == true
	if item.primaryAction then
		item.primaryAction.primary = true
		item.payload = item.primaryAction.payload
	end
	return item
end

local function addFists(items, GameConfig, stats)
	local ownedBase = listSet(stats.OwnedFistsJSON)
	local ownedPremium = listSet(stats.OwnedPremiumFistsJSON)
	local equippedName = tostring(stats.EquippedFist or "")

	local function addCatalog(catalog, owned, premium)
		for _, definition in ipairs(catalogEntries(catalog)) do
			if owned[definition.name] then
				local equipped = equippedName == definition.name
				local accent = definition.accent or definition.color or UNKNOWN_ACCENT
				local primary = actionDescriptor(
					"EquipFist",
					equipped and "EQUIPPED" or "EQUIP",
					{ action = "EquipFist", target = definition.name },
					not equipped,
					accent,
					{ primary = true }
				)
				local tier = math.max(1, math.floor(tonumber(definition.tier) or 1))
				local item = finalizeItem({
					key = "fist:" .. definition.name,
					category = "Fists",
					kind = "Fist",
					name = definition.name,
					displayName = definition.displayName or definition.name,
					rarity = inferRarity(definition, "Fist", premium),
					accent = accent,
					art = fistArt(GameConfig, definition),
					icon = definition.icon or "StarterFist",
					quantity = 1,
					equipped = equipped,
					locked = false,
					detail = ("Tier %d | x%s Power"):format(tier, formatDecimal(definition.mult or 1)),
					actions = { primary },
					primaryAction = primary,
				})
				table.insert(items, item)
			end
		end
	end

	addCatalog(GameConfig.Fists, ownedBase, false)
	addCatalog(GameConfig.PremiumFists, ownedPremium, true)
end

local function addPets(items, GameConfig, stats)
	local inventory = numericEntries(stats.PetInventoryJSON)
	local inventoryCounts = listCounts(stats.PetInventoryJSON)
	local equippedCounts = listCounts(stats.EquippedPetsJSON)
	local occurrences = {}
	local locked = listSet(stats.LockedPetsJSON)
	local definitions = makeDefinitionMap(GameConfig.Pets, GameConfig.PremiumPets)
	local equippedCount = 0
	local unlockedCounts = {}
	for _, entry in ipairs(inventory) do
		local token = tostring(entry.value or "")
		local slotToken = "slot:" .. tostring(entry.index)
		if locked[token] ~= true and locked[slotToken] ~= true then
			unlockedCounts[token] = (unlockedCounts[token] or 0) + 1
		end
	end

	for _, entry in ipairs(inventory) do
		local petName, stars, token = parsePetToken(GameConfig, entry.value)
		occurrences[token] = (occurrences[token] or 0) + 1
		local occurrence = occurrences[token]
		local tokenEquippedCount = math.min(equippedCounts[token] or 0, inventoryCounts[token] or 0)
		local catalogEntry = definitions[petName]
		local definition = catalogEntry and catalogEntry.definition or nil
		local slotToken = "slot:" .. tostring(entry.index)
		local isLocked = locked[token] == true or locked[slotToken] == true
		local isEquipped = occurrence <= tokenEquippedCount
		if isEquipped then
			equippedCount = equippedCount + 1
		end
		local accent = definition and (definition.accent or definition.color) or UNKNOWN_ACCENT
		local primaryName = isEquipped and "UnequipPet" or "EquipPet"
		local primaryEnabled = (isEquipped and occurrence == tokenEquippedCount)
			or (not isEquipped and occurrence == tokenEquippedCount + 1 and definition ~= nil)
		local primary = actionDescriptor(
			primaryName,
			isEquipped and "UNEQUIP" or "EQUIP",
			{ action = primaryName, target = token, index = entry.index },
			primaryEnabled,
			accent,
			{ primary = true }
		)
		local lockAction = actionDescriptor(
			"LockPet",
			isLocked and "UNLOCK" or "LOCK",
			{ action = "LockPet", target = token, value = not isLocked, index = entry.index },
			true,
			accent
		)
		local deleteAction = actionDescriptor(
			"DeletePet",
			"DELETE",
			{ action = "DeletePet", target = token, index = entry.index },
			not isLocked,
			accent,
			{ confirm = true, destructive = true }
		)
		local maxStars = math.max(1, math.floor(tonumber(GameConfig.MaxPetStars) or 5))
		local fusionRequired = stars < maxStars
			and math.max(2, math.floor(tonumber(GameConfig.PetFusionRequirement(stars)) or (stars + 1)))
			or 0
		local fusionOwned = unlockedCounts[token] or 0
		local fusionEnabled = definition ~= nil
			and stars < maxStars
			and fusionOwned >= fusionRequired
		local fusionAction = actionDescriptor(
			"FusePet",
			stars >= maxStars and "MAX STAR" or "FUSE",
			{ action = "FusePet", target = token },
			fusionEnabled,
			accent
		)
		local multiplier = 0
		if definition then
			multiplier = (tonumber(definition.mult) or 0) * (1 + (stars - 1) * 0.75)
		end
		local fusionDetail = stars >= maxStars
			and "MAX STAR"
			or ("FUSE %d/%d UNLOCKED"):format(fusionOwned, fusionRequired)
		local detail = definition
			and ("%d Star | +%s%% Power | %s"):format(stars, formatDecimal(multiplier * 100), fusionDetail)
			or ("%d Star | Unknown saved pet"):format(stars)
		local item = finalizeItem({
			key = "pet:slot:" .. tostring(entry.index),
			category = "Pets",
			kind = "Pet",
			name = petName,
			displayName = definition and (definition.displayName or definition.name) or petName,
			rarity = definition and inferRarity(definition, "Pet", catalogEntry.premium) or "Unknown",
			accent = accent,
			art = petArt(GameConfig, definition),
			artKey = definition and definition.artKey or "",
			previewPet = definition and definition.name or "",
			icon = definition and definition.icon or "Pet",
			quantity = 1,
			equipped = isEquipped,
			locked = isLocked,
			slot = entry.index,
			token = token,
			detail = detail,
			fusionOwned = fusionOwned,
			fusionRequired = fusionRequired,
			fusionNextStars = stars < maxStars and (stars + 1) or stars,
			fusionEnabled = fusionEnabled,
			actions = { primary, fusionAction, lockAction, deleteAction },
			primaryAction = primary,
		})
		table.insert(items, item)
	end

	return #inventory, equippedCount
end

local function addHonor(items, GameConfig, stats)
	local owned = listSet(stats.OwnedHonorItemsJSON)
	local equippedName = tostring(stats.EquippedHonorItem or "")
	local honorBalance = math.max(0, math.floor(tonumber(stats.Honor) or 0))
	local depth = math.max(0, math.floor(tonumber(stats.Depth) or 0))
	local rebirths = math.max(0, math.floor(tonumber(stats.Rebirths) or 0))
	for _, definition in ipairs(catalogEntries(GameConfig.HonorItems)) do
		local isOwned = owned[definition.id] == true or owned[definition.name] == true
		local equipped = equippedName == definition.id or equippedName == definition.name
		local requiredDepth = math.max(0, math.floor(tonumber(definition.requiredDepth) or 0))
		local requiredRebirths = math.max(0, math.floor(tonumber(definition.requiredRebirths) or 0))
		local unlocked = type(GameConfig.HonorItemUnlocked) == "function"
			and GameConfig.HonorItemUnlocked(definition, depth, rebirths)
			or (depth >= requiredDepth and rebirths >= requiredRebirths)
		local cost = math.max(0, math.floor(tonumber(definition.cost) or 0))
		local affordable = honorBalance >= cost
		local missingHonor = math.max(0, cost - honorBalance)
		local state = equipped and "Equipped"
			or isOwned and "Owned"
			or not unlocked and "Locked"
			or not affordable and "Insufficient"
			or "Affordable"
		local actionLabel = equipped and "EQUIPPED"
			or isOwned and "EQUIP"
			or not unlocked and "LOCKED"
			or not affordable and ("NEED %d"):format(missingHonor)
			or ("UNLOCK %d"):format(cost)
		local actionEnabled = not equipped and (isOwned or (unlocked and affordable))
		local accent = definition.accent or definition.color or UNKNOWN_ACCENT
		local primary = actionDescriptor(
			"BuyHonorItem",
			actionLabel,
			{ action = "BuyHonorItem", target = definition.id },
			actionEnabled,
			accent,
			{ primary = true }
		)
		local requirement = ("Depth %d"):format(requiredDepth)
		if requiredRebirths > 0 then
			requirement ..= (" | Rebirth %d"):format(requiredRebirths)
		end
		local item = finalizeItem({
			key = "honor:" .. definition.id,
			category = "Honor",
			kind = "Honor",
			name = definition.name,
			displayName = definition.displayName or definition.name,
			rarity = inferRarity(definition, "Honor", false),
			accent = accent,
			art = honorArt(GameConfig, definition),
			icon = definition.icon or "Success",
			quantity = 1,
			owned = isOwned,
			equipped = equipped,
			locked = not isOwned and not unlocked,
			unlocked = unlocked,
			affordable = affordable,
			state = state,
			cost = cost,
			missingHonor = missingHonor,
			requiredDepth = requiredDepth,
			requiredRebirths = requiredRebirths,
			detail = ("+%d%% total Power | %d Honor | %s"):format(
				math.floor((tonumber(definition.powerBonus) or 0) * 100 + 0.5),
				cost,
				requirement
			),
			actions = { primary },
			primaryAction = primary,
		})
		table.insert(items, item)
	end
end

local function addActiveBoosts(items, GameConfig, stats, now)
	local timers = decodeTable(stats.ShopBoosts)
	local art = type(GameConfig.ShopArt) == "table" and GameConfig.ShopArt or {}
	for _, definition in ipairs(BOOST_DEFINITIONS) do
		local endsAt = tonumber(timers[definition.timer]) or 0
		if endsAt > now then
			local remaining = math.max(0, math.ceil(endsAt - now))
			local item = finalizeItem({
				key = "boost:" .. definition.name,
				category = "Boosts",
				kind = "Boost",
				name = definition.name,
				displayName = definition.displayName,
				rarity = definition.rarity,
				accent = definition.accent,
				art = art[definition.art] or "",
				icon = definition.icon,
				quantity = 1,
				equipped = false,
				locked = false,
				detail = ("%s | %d:%02d remaining"):format(definition.detail, math.floor(remaining / 60), remaining % 60),
				actions = {},
				viewOnly = true,
				endsAt = endsAt,
				remainingSeconds = remaining,
			})
			table.insert(items, item)
		end
	end
end

local function deriveFilters(items)
	local raritiesPresent = {}
	for _, item in ipairs(items) do
		raritiesPresent[item.rarity] = true
	end

	local categories = { "All" }
	for _, category in ipairs(CATEGORY_ORDER) do
		table.insert(categories, category)
	end

	local rarities = { "All" }
	for _, rarity in ipairs(RARITY_ORDER) do
		if rarity ~= "Unknown" or raritiesPresent.Unknown then
			table.insert(rarities, rarity)
		end
	end
	return categories, rarities
end

function InventoryViewModel.Build(GameConfig, stats, now)
	GameConfig = type(GameConfig) == "table" and GameConfig or {}
	stats = type(stats) == "table" and stats or {}
	now = tonumber(now) or 0

	local items = {}
	addFists(items, GameConfig, stats)
	local petUsed, equippedPets = addPets(items, GameConfig, stats)
	addHonor(items, GameConfig, stats)
	addActiveBoosts(items, GameConfig, stats, now)
	local categories, rarities = deriveFilters(items)
	local petCapacity = math.max(0, math.floor(tonumber(GameConfig.MaxPetInventory) or 0))
	local maxEquippedPets = math.max(0, math.floor(tonumber(GameConfig.MaxEquippedPets) or 0))

	return {
		items = items,
		categories = categories,
		rarities = rarities,
		itemCount = #items,
		petUsed = petUsed,
		petCapacity = petCapacity,
		equippedPets = equippedPets,
		maxEquippedPets = maxEquippedPets,
		capacity = {
			used = petUsed,
			total = petCapacity,
			equipped = equippedPets,
			maxEquipped = maxEquippedPets,
		},
	}
end

local function normalizedFilterCategory(value)
	local lowered = string.lower(tostring(value or ""))
	return CATEGORY_ALIASES[lowered] or lowered
end

function InventoryViewModel.Filter(snapshot, category, search, rarity)
	local result = {}
	if type(snapshot) ~= "table" or type(snapshot.items) ~= "table" then
		return result
	end
	local wantedCategory = normalizedFilterCategory(category)
	local wantedRarity = string.lower(tostring(rarity or ""))
	local query = string.lower(tostring(search or ""))

	for _, item in ipairs(snapshot.items) do
		local categoryMatches = wantedCategory == "" or wantedCategory == "all"
			or string.lower(tostring(item.category or "")) == wantedCategory
		local rarityMatches = wantedRarity == "" or wantedRarity == "all"
			or string.lower(tostring(item.rarity or "")) == wantedRarity
		local searchMatches = query == ""
		if not searchMatches then
			local haystack = table.concat({
				tostring(item.key or ""),
				tostring(item.category or ""),
				tostring(item.name or ""),
				tostring(item.displayName or ""),
				tostring(item.rarity or ""),
				tostring(item.token or ""),
				tostring(item.detail or ""),
			}, "\n")
			searchMatches = string.find(string.lower(haystack), query, 1, true) ~= nil
		end
		if categoryMatches and rarityMatches and searchMatches then
			table.insert(result, item)
		end
	end
	return result
end

function InventoryViewModel.Find(snapshot, key)
	if type(snapshot) ~= "table" or type(snapshot.items) ~= "table" then
		return nil
	end
	for _, item in ipairs(snapshot.items) do
		if item.key == key then
			return item
		end
	end
	return nil
end

local function canonical(value, seen)
	local valueType = typeof(value)
	if valueType == "nil" then return "nil" end
	if valueType == "boolean" then return value and "true" or "false" end
	if valueType == "number" then
		if value ~= value then return "number:nan" end
		if value == math.huge then return "number:inf" end
		if value == -math.huge then return "number:-inf" end
		return "number:" .. string.format("%.17g", value)
	end
	if valueType == "string" then return "string:" .. string.format("%q", value) end
	if valueType ~= "table" then return valueType .. ":" .. tostring(value) end

	seen = seen or {}
	if seen[value] then return "cycle" end
	seen[value] = true
	local keyed = {}
	for key in pairs(value) do
		table.insert(keyed, { key = key, sort = canonical(key, {}) })
	end
	table.sort(keyed, function(left, right)
		return left.sort < right.sort
	end)
	local parts = { "{" }
	for _, entry in ipairs(keyed) do
		table.insert(parts, entry.sort)
		table.insert(parts, "=")
		table.insert(parts, canonical(value[entry.key], seen))
		table.insert(parts, ";")
	end
	table.insert(parts, "}")
	seen[value] = nil
	return table.concat(parts)
end

local function signatureValueEqual(left, right)
	local valueType = typeof(left)
	if valueType ~= typeof(right) then
		return false
	end
	if valueType == "number" then
		if left ~= left then
			return right ~= right
		end
		if left == 0 and right == 0 then
			return 1 / left == 1 / right
		end
	end
	return left == right
end

local function cloneAcyclic(value, visiting)
	if typeof(value) ~= "table" then
		return value, true
	end
	visiting = visiting or {}
	if visiting[value] then
		return nil, false
	end
	visiting[value] = true
	local copy = {}
	for key, child in pairs(value) do
		if typeof(key) == "table" then
			visiting[value] = nil
			return nil, false
		end
		local cloned, acyclic = cloneAcyclic(child, visiting)
		if not acyclic then
			visiting[value] = nil
			return nil, false
		end
		copy[key] = cloned
	end
	visiting[value] = nil
	return copy, true
end

local function deepEqualAcyclic(left, right, depth)
	local valueType = typeof(left)
	if valueType ~= typeof(right) then
		return false
	end
	if valueType ~= "table" then
		return signatureValueEqual(left, right)
	end
	if depth > 64 then
		return false
	end

	local leftCount = 0
	for key, value in pairs(left) do
		if typeof(key) == "table" then
			return false
		end
		leftCount = leftCount + 1
		local other = right[key]
		if other == nil or not deepEqualAcyclic(value, other, depth + 1) then
			return false
		end
	end
	local rightCount = 0
	for _ in pairs(right) do
		rightCount = rightCount + 1
	end
	return leftCount == rightCount
end

local function selectedConfig(GameConfig)
	local graphics = type(GameConfig.GeneratedGraphics) == "table" and GameConfig.GeneratedGraphics or EMPTY_TABLE
	return {
		DataVersion = GameConfig.DataVersion,
		MaxPetInventory = GameConfig.MaxPetInventory,
		MaxEquippedPets = GameConfig.MaxEquippedPets,
		MaxPetStars = GameConfig.MaxPetStars,
		Fists = GameConfig.Fists,
		PremiumFists = GameConfig.PremiumFists,
		Pets = GameConfig.Pets,
		PremiumPets = GameConfig.PremiumPets,
		HonorItems = GameConfig.HonorItems,
		ShopArt = GameConfig.ShopArt,
		PetArt = graphics.Iteration02PetIcon,
	}
end

local function configEntryMatches(entry, GameConfig)
	local graphics = type(GameConfig.GeneratedGraphics) == "table" and GameConfig.GeneratedGraphics or EMPTY_TABLE
	if not entry
		or not signatureValueEqual(entry.DataVersion, GameConfig.DataVersion)
		or not signatureValueEqual(entry.MaxPetInventory, GameConfig.MaxPetInventory)
		or not signatureValueEqual(entry.MaxEquippedPets, GameConfig.MaxEquippedPets)
		or not signatureValueEqual(entry.MaxPetStars, GameConfig.MaxPetStars)
		or not signatureValueEqual(entry.PetArt, graphics.Iteration02PetIcon)
		or entry.Fists ~= GameConfig.Fists
		or entry.PremiumFists ~= GameConfig.PremiumFists
		or entry.Pets ~= GameConfig.Pets
		or entry.PremiumPets ~= GameConfig.PremiumPets
		or entry.HonorItems ~= GameConfig.HonorItems
		or entry.ShopArt ~= GameConfig.ShopArt
	then
		return false
	end
	return true
end

local function configSignatureEntry(GameConfig)
	local entry = CONFIG_SIGNATURE_CACHE[GameConfig]
	if configEntryMatches(entry, GameConfig) then
		return entry
	end

	local current = selectedConfig(GameConfig)
	entry = {
		canonical = canonical(current),
		DataVersion = current.DataVersion,
		MaxPetInventory = current.MaxPetInventory,
		MaxEquippedPets = current.MaxEquippedPets,
		MaxPetStars = current.MaxPetStars,
		PetArt = current.PetArt,
		Fists = current.Fists,
		PremiumFists = current.PremiumFists,
		Pets = current.Pets,
		PremiumPets = current.PremiumPets,
		HonorItems = current.HonorItems,
		ShopArt = current.ShopArt,
	}
	CONFIG_SIGNATURE_CACHE[GameConfig] = entry
	return entry
end

local function encodeSignatureValue(value)
	local valueType = typeof(value)
	local payload
	if valueType == "nil" then
		payload = ""
	elseif valueType == "string" then
		payload = value
	elseif valueType == "boolean" then
		payload = value and "true" or "false"
	elseif valueType == "number" or valueType == "table" then
		payload = canonical(value)
	else
		payload = tostring(value)
	end
	return valueType .. "#" .. tostring(#payload) .. ":" .. payload
end

local function appendSignatureFrame(parts, name, payload)
	parts[#parts + 1] = "|"
	parts[#parts + 1] = name
	parts[#parts + 1] = "#"
	parts[#parts + 1] = tostring(#payload)
	parts[#parts + 1] = ":"
	parts[#parts + 1] = payload
end

local function snapshotStatsInputs(stats)
	local snapshot = {}
	for index, field in ipairs(SIGNATURE_STATS_FIELDS) do
		local value = stats[field]
		if typeof(value) == "table" then
			local cloned, cacheable = cloneAcyclic(value)
			if not cacheable then
				return nil
			end
			snapshot[index] = { valueType = "table", value = cloned }
		else
			snapshot[index] = { valueType = typeof(value), value = value }
		end
	end
	return snapshot
end

local function statsInputsMatch(snapshot, stats)
	if not snapshot then
		return false
	end
	for index, field in ipairs(SIGNATURE_STATS_FIELDS) do
		local expected = snapshot[index]
		local current = stats[field]
		if not expected or expected.valueType ~= typeof(current) then
			return false
		end
		if expected.valueType == "table" then
			if not deepEqualAcyclic(current, expected.value, 0) then
				return false
			end
		elseif not signatureValueEqual(current, expected.value) then
			return false
		end
	end
	return true
end

-- Current time is intentionally excluded: while visible, consumers should derive the
-- countdown from each boost's endsAt and rebuild at expiry (or once per visible second).
function InventoryViewModel.Signature(GameConfig, stats)
	GameConfig = type(GameConfig) == "table" and GameConfig or EMPTY_TABLE
	stats = type(stats) == "table" and stats or EMPTY_TABLE

	local configEntry = configSignatureEntry(GameConfig)
	if configEntry.lastSignature and statsInputsMatch(configEntry.lastStats, stats) then
		return configEntry.lastSignature
	end

	local parts = { "inventory-v2" }
	appendSignatureFrame(parts, "config", configEntry.canonical)
	for _, field in ipairs(SIGNATURE_STATS_FIELDS) do
		appendSignatureFrame(parts, field, encodeSignatureValue(stats[field]))
	end
	local signature = table.concat(parts)
	configEntry.lastStats = snapshotStatsInputs(stats)
	configEntry.lastSignature = configEntry.lastStats and signature or nil
	return signature
end

-- GameConfig.lua constructs its catalog once and runtime code treats it as immutable.
-- Replacing a relevant table or scalar invalidates automatically. A Studio test or
-- future caller that mutates a relevant table in place must call this hook.
function InventoryViewModel.InvalidateSignatureCache(GameConfig)
	if type(GameConfig) == "table" then
		CONFIG_SIGNATURE_CACHE[GameConfig] = nil
		return
	end
	table.clear(CONFIG_SIGNATURE_CACHE)
end

function InventoryViewModel.GetCanonicalFistRarity(definition, premium)
	return canonicalFistRarity(definition, premium == true)
end

return InventoryViewModel
