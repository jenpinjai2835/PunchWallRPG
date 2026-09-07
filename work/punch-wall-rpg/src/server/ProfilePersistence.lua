local ProfilePersistence = {}

ProfilePersistence.ContractVersion = "2.3.0"
ProfilePersistence.MaxReceiptLedgerEntries = 200
ProfilePersistence.MaxSeenReceiptIds = 2048
ProfilePersistence.MaxAuthoritativeNumber = 9007199254740991
ProfilePersistence.MaxJsonBytes = 65536
ProfilePersistence.MaxJsonNodes = 4096
ProfilePersistence.MaxJsonDepth = 32
ProfilePersistence.MaxJsonListEntries = 256
ProfilePersistence.MaxJsonStringBytes = 128
ProfilePersistence.MinSessionLeaseSeconds = 15
ProfilePersistence.DefaultSessionLeaseSeconds = 120
ProfilePersistence.MaxSessionLeaseSeconds = 300
ProfilePersistence.MaxSessionTokenBytes = 128

ProfilePersistence.BoostExpiryFields = {
	"CoinBoostExpiresAt",
	"DamageBoostExpiresAt",
	"SpeedBoostExpiresAt",
	"TrainingBoostExpiresAt",
}

local BOOST_EXPIRY_FIELD_SET = {}
for _, field in ipairs(ProfilePersistence.BoostExpiryFields) do
	BOOST_EXPIRY_FIELD_SET[field] = true
end

ProfilePersistence.NumberFieldSchema = {
	Power = { default = 15, min = 0, integer = true },
	Coins = { default = 0, min = 0, integer = true },
	Honor = { default = 0, min = 0, integer = true },
	Depth = { default = 0, min = 0, integer = true },
	Score = { default = 0, min = 0, integer = true },
	WallLevel = { default = 1, min = 1, integer = true },
	WallXP = { default = 0, min = 0, integer = true },
	Rebirths = { default = 0, min = 0, integer = true },
	FistMastery = { default = 1, min = 1, integer = true },
	BreakSpeed = { default = 1, min = 0 },
	CritChance = { default = 5, min = 0, max = 100 },
	Luck = { default = 1, min = 0 },
	FistMultiplier = { default = 1, min = 0 },
	PetMultiplier = { default = 0, min = 0 },
	TutorialStep = { default = 1, min = 1, integer = true },
	TutorialVersion = { default = 2, min = 0, integer = true },
	TutorialCompleted = { default = 0, min = 0, max = 1, integer = true },
	DailyBreaks = { default = 0, min = 0, integer = true },
	DailyQuestClaimed = { default = 0, min = 0, max = 1, integer = true },
	PlaytimeSeconds = { default = 0, min = 0, integer = true },
	PlaytimeClaimed = { default = 0, min = 0, integer = true },
	HonorPowerBonus = { default = 0, min = 0, max = 0.12 },
	HonorMilestoneMask = { default = 0, min = 0, integer = true },
	HonorRebirthMilestoneMask = { default = 0, min = 0, integer = true },
	HonorClearsToday = { default = 0, min = 0, max = 3, integer = true },
	LastHonorClearAt = { default = 0, min = 0, integer = true },
	LastSpinAt = { default = 0, min = 0, integer = true },
	SpinCredits = { default = 0, min = 0, integer = true },
	TrainingActive = { default = 0, min = 0, max = 1, integer = true },
	TrainingUpdatedAt = { default = 0, min = 0, integer = true },
	LastHonorCycle = { default = -1, min = -1, integer = true },
	PetDropPity = { default = 0, min = 0, integer = true },
	CoinBoostExpiresAt = { default = 0, min = 0 },
	DamageBoostExpiresAt = { default = 0, min = 0 },
	SpeedBoostExpiresAt = { default = 0, min = 0 },
	TrainingBoostExpiresAt = { default = 0, min = 0 },
}

ProfilePersistence.TextFieldSchema = {
	EquippedFist = { default = "Starter Glove", maxBytes = 128 },
	Pet = { default = "None", maxBytes = 128 },
	TrainingStationId = { default = "rookie_bag", maxBytes = 64 },
	OwnedFistsJSON = {
		default = "[\"Starter Glove\"]",
		maxBytes = ProfilePersistence.MaxJsonBytes,
		jsonRoot = "array",
	},
	OwnedPremiumFistsJSON = {
		default = "[]",
		maxBytes = ProfilePersistence.MaxJsonBytes,
		jsonRoot = "array",
	},
	OwnedPremiumPetsJSON = {
		default = "[]",
		maxBytes = ProfilePersistence.MaxJsonBytes,
		jsonRoot = "array",
	},
	OwnedHonorItemsJSON = {
		default = "[]",
		maxBytes = ProfilePersistence.MaxJsonBytes,
		jsonRoot = "array",
	},
	EquippedHonorItem = { default = "None", maxBytes = 128 },
	HonorClearDate = { default = "", maxBytes = 32 },
	LastHonorClearId = { default = "", maxBytes = 256 },
	PetInventoryJSON = {
		default = "[]",
		maxBytes = ProfilePersistence.MaxJsonBytes,
		jsonRoot = "array",
	},
	EquippedPetsJSON = {
		default = "[]",
		maxBytes = ProfilePersistence.MaxJsonBytes,
		jsonRoot = "array",
	},
	DiscoveredPetsJSON = {
		default = "[]",
		maxBytes = ProfilePersistence.MaxJsonBytes,
		jsonRoot = "array",
	},
	LockedPetsJSON = {
		default = "[]",
		maxBytes = ProfilePersistence.MaxJsonBytes,
		jsonRoot = "array",
	},
	LastDailyDate = { default = "", maxBytes = 32 },
	DailyQuestDate = { default = "", maxBytes = 32 },
	SettingsJSON = {
		default = "{\"motion\":true,\"sound\":true,\"uiScale\":1}",
		maxBytes = 4096,
		jsonRoot = "object",
	},
}

local JSON_STRING_ARRAY_FIELDS = {
	"OwnedFistsJSON",
	"OwnedPremiumFistsJSON",
	"OwnedPremiumPetsJSON",
	"OwnedHonorItemsJSON",
	"PetInventoryJSON",
	"EquippedPetsJSON",
	"DiscoveredPetsJSON",
	"LockedPetsJSON",
}
for _, field in ipairs(JSON_STRING_ARRAY_FIELDS) do
	local schema = ProfilePersistence.TextFieldSchema[field]
	schema.jsonShape = "stringArray"
	schema.maxItems = ProfilePersistence.MaxJsonListEntries
	schema.maxElementBytes = ProfilePersistence.MaxJsonStringBytes
end
ProfilePersistence.TextFieldSchema.SettingsJSON.jsonShape = "settings"

local RESERVED_PROFILE_FIELDS = {
	DataVersion = true,
	ProcessedReceipts = true,
	ProfileRevision = true,
	SessionLease = true,
}

local KNOWN_PROFILE_FIELDS = {}
for field in pairs(RESERVED_PROFILE_FIELDS) do
	KNOWN_PROFILE_FIELDS[field] = true
end
for field in pairs(ProfilePersistence.NumberFieldSchema) do
	KNOWN_PROFILE_FIELDS[field] = true
end
for field in pairs(ProfilePersistence.TextFieldSchema) do
	KNOWN_PROFILE_FIELDS[field] = true
end

local RECEIPT_LEDGER_FIELDS = { "Order", "Entries", "Seen" }

local function shallowCopy(source)
	local result = {}
	if type(source) == "table" then
		for key, value in pairs(source) do
			result[key] = value
		end
	end
	return result
end

local function canonicalProfileCopy(rawProfile, sourceVersion, currentVersion)
	local profile = {}
	for key, value in pairs(rawProfile) do
		if KNOWN_PROFILE_FIELDS[key] then
			profile[key] = value
		elseif sourceVersion >= currentVersion then
			return nil, "unknown_profile_field"
		end
	end
	return profile
end

local function finiteNumber(value, fallback)
	value = tonumber(value)
	if not value or value ~= value or value == math.huge or value == -math.huge then
		return fallback or 0
	end
	return value
end

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function positiveInteger(value)
	local normalized = finiteNumber(value, -1)
	if normalized < 1 or normalized % 1 ~= 0 then
		return nil
	end
	return normalized
end

local function strictNonNegativeInteger(value)
	if not isFiniteNumber(value) or value < 0 or value % 1 ~= 0 then
		return nil
	end
	if value > ProfilePersistence.MaxAuthoritativeNumber then
		return nil
	end
	return value
end

local function validateJsonDocument(
	source,
	expectedRoot,
	jsonShape,
	maxItems,
	maxElementBytes
)
	if type(source) ~= "string" then
		return false, "not_string"
	end
	local length = #source
	if length > ProfilePersistence.MaxJsonBytes then
		return false, "too_large"
	end

	local index = 1
	local nodes = 0

	local function skipWhitespace()
		while index <= length do
			local byte = string.byte(source, index)
			if byte ~= 0x20 and byte ~= 0x09 and byte ~= 0x0A and byte ~= 0x0D then
				break
			end
			index += 1
		end
	end

	local function unicodeScalar(codepoint)
		if codepoint < 0 or codepoint > 0x10FFFF then
			return nil
		end
		if codepoint >= 0xD800 and codepoint <= 0xDFFF then
			return nil
		end
		local ok, encoded = pcall(utf8.char, codepoint)
		return ok and encoded or nil
	end

	local function parseHex4(startIndex)
		local finishIndex = startIndex + 3
		if finishIndex > length then
			return nil
		end
		local raw = string.sub(source, startIndex, finishIndex)
		if not string.match(raw, "^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
			return nil
		end
		return tonumber(raw, 16)
	end

	local function parseString()
		if string.byte(source, index) ~= 0x22 then
			return false
		end
		index += 1
		local chunks = {}
		while index <= length do
			local byte = string.byte(source, index)
			if byte == 0x22 then
				index += 1
				local value = table.concat(chunks)
				if utf8.len(value) == nil then
					return false
				end
				return true, value
			end
			if byte < 0x20 then
				return false
			end
			if byte == 0x5C then
				index += 1
				if index > length then
					return false
				end
				local escaped = string.byte(source, index)
				local simpleEscapes = {
					[0x22] = "\"",
					[0x5C] = "\\",
					[0x2F] = "/",
					[0x62] = "\b",
					[0x66] = "\f",
					[0x6E] = "\n",
					[0x72] = "\r",
					[0x74] = "\t",
				}
				if escaped == 0x75 then
					local codepoint = parseHex4(index + 1)
					if not codepoint then
						return false
					end
					index += 5
					if codepoint >= 0xD800 and codepoint <= 0xDBFF then
						if string.byte(source, index) ~= 0x5C
							or string.byte(source, index + 1) ~= 0x75
						then
							return false
						end
						local lowSurrogate = parseHex4(index + 2)
						if not lowSurrogate
							or lowSurrogate < 0xDC00
							or lowSurrogate > 0xDFFF
						then
							return false
						end
						codepoint = 0x10000
							+ (codepoint - 0xD800) * 0x400
							+ (lowSurrogate - 0xDC00)
						index += 6
					end
					local encoded = unicodeScalar(codepoint)
					if not encoded then
						return false
					end
					table.insert(chunks, encoded)
				else
					local decoded = simpleEscapes[escaped]
					if not decoded then
						return false
					end
					table.insert(chunks, decoded)
					index += 1
				end
			else
				table.insert(chunks, string.char(byte))
				index += 1
			end
		end
		return false
	end

	local function parseNumber()
		local startIndex = index
		if string.byte(source, index) == 0x2D then
			index += 1
		end
		local first = string.byte(source, index)
		if first == 0x30 then
			index += 1
			local nextByte = string.byte(source, index)
			if nextByte and nextByte >= 0x30 and nextByte <= 0x39 then
				return false
			end
		elseif first and first >= 0x31 and first <= 0x39 then
			repeat
				index += 1
				first = string.byte(source, index)
			until not first or first < 0x30 or first > 0x39
		else
			return false
		end
		if string.byte(source, index) == 0x2E then
			index += 1
			local fractionStart = index
			while true do
				local byte = string.byte(source, index)
				if not byte or byte < 0x30 or byte > 0x39 then
					break
				end
				index += 1
			end
			if index == fractionStart then
				return false
			end
		end
		local exponent = string.byte(source, index)
		if exponent == 0x45 or exponent == 0x65 then
			index += 1
			local sign = string.byte(source, index)
			if sign == 0x2B or sign == 0x2D then
				index += 1
			end
			local exponentStart = index
			while true do
				local byte = string.byte(source, index)
				if not byte or byte < 0x30 or byte > 0x39 then
					break
				end
				index += 1
			end
			if index == exponentStart then
				return false
			end
		end
		local value = tonumber(string.sub(source, startIndex, index - 1))
		if not isFiniteNumber(value) then
			return false
		end
		return true, value
	end

	local parseValue

	local function parseArray(depth)
		index += 1
		skipWhitespace()
		local values = {}
		if string.byte(source, index) == 0x5D then
			index += 1
			return true, values
		end
		while true do
			local ok, kind, value = parseValue(depth + 1)
			if not ok then
				return false
			end
			table.insert(values, {
				kind = kind,
				value = value,
			})
			skipWhitespace()
			local byte = string.byte(source, index)
			if byte == 0x5D then
				index += 1
				return true, values
			end
			if byte ~= 0x2C then
				return false
			end
			index += 1
			skipWhitespace()
		end
	end

	local function parseObject(depth)
		index += 1
		skipWhitespace()
		local values = {}
		local seenKeys = {}
		if string.byte(source, index) == 0x7D then
			index += 1
			return true, values
		end
		while true do
			local keyOk, key = parseString()
			if not keyOk or seenKeys[key] then
				return false
			end
			seenKeys[key] = true
			skipWhitespace()
			if string.byte(source, index) ~= 0x3A then
				return false
			end
			index += 1
			skipWhitespace()
			local valueOk, kind, value = parseValue(depth + 1)
			if not valueOk then
				return false
			end
			values[key] = {
				kind = kind,
				value = value,
			}
			skipWhitespace()
			local byte = string.byte(source, index)
			if byte == 0x7D then
				index += 1
				return true, values
			end
			if byte ~= 0x2C then
				return false
			end
			index += 1
			skipWhitespace()
		end
	end

	parseValue = function(depth)
		if depth > ProfilePersistence.MaxJsonDepth then
			return false
		end
		nodes += 1
		if nodes > ProfilePersistence.MaxJsonNodes then
			return false
		end
		skipWhitespace()
		local byte = string.byte(source, index)
		if byte == 0x22 then
			local ok, value = parseString()
			return ok, "string", value
		elseif byte == 0x5B then
			local ok, value = parseArray(depth)
			return ok, "array", value
		elseif byte == 0x7B then
			local ok, value = parseObject(depth)
			return ok, "object", value
		elseif byte == 0x74 and string.sub(source, index, index + 3) == "true" then
			index += 4
			return true, "boolean", true
		elseif byte == 0x66 and string.sub(source, index, index + 4) == "false" then
			index += 5
			return true, "boolean", false
		elseif byte == 0x6E and string.sub(source, index, index + 3) == "null" then
			index += 4
			return true, "null", nil
		elseif byte == 0x2D or (byte and byte >= 0x30 and byte <= 0x39) then
			local ok, value = parseNumber()
			return ok, "number", value
		end
		return false
	end

	skipWhitespace()
	local valid, rootKind, rootValue = parseValue(0)
	if not valid then
		return false, "malformed"
	end
	skipWhitespace()
	if index <= length then
		return false, "trailing_data"
	end
	if expectedRoot and rootKind ~= expectedRoot then
		return false, "wrong_root"
	end

	if jsonShape == "stringArray" then
		if #rootValue > (maxItems or ProfilePersistence.MaxJsonListEntries) then
			return false, "too_many_items"
		end
		for _, element in ipairs(rootValue) do
			if element.kind ~= "string" then
				return false, "array_element_not_string"
			end
			if #element.value
				> (maxElementBytes or ProfilePersistence.MaxJsonStringBytes)
			then
				return false, "array_element_too_large"
			end
		end
	elseif jsonShape == "settings" then
		local knownSettings = {
			motion = true,
			sound = true,
			uiScale = true,
		}
		for key in pairs(rootValue) do
			if not knownSettings[key] then
				return false, "settings_unknown_key"
			end
		end
		local motion = rootValue.motion
		local sound = rootValue.sound
		local uiScale = rootValue.uiScale
		if not motion or motion.kind ~= "boolean" then
			return false, "settings_invalid_motion"
		end
		if not sound or sound.kind ~= "boolean" then
			return false, "settings_invalid_sound"
		end
		if not uiScale
			or uiScale.kind ~= "number"
			or not isFiniteNumber(uiScale.value)
			or uiScale.value < 0.8
			or uiScale.value > 1.2
		then
			return false, "settings_invalid_ui_scale"
		end
	end
	return true
end

local function validateAuthoritativeFields(profile)
	for field, schema in pairs(ProfilePersistence.NumberFieldSchema) do
		local value = profile[field]
		if value == nil then
			profile[field] = schema.default
		elseif type(value) ~= "number" then
			return nil, "profile_" .. field .. "_not_number"
		elseif not isFiniteNumber(value) then
			return nil, "profile_" .. field .. "_nonfinite"
		elseif schema.integer and value % 1 ~= 0 then
			return nil, "profile_" .. field .. "_not_integer"
		elseif value < schema.min
			or value > (schema.max or ProfilePersistence.MaxAuthoritativeNumber)
		then
			return nil, "profile_" .. field .. "_out_of_range"
		end
	end
	for field, schema in pairs(ProfilePersistence.TextFieldSchema) do
		local value = profile[field]
		if value == nil then
			profile[field] = schema.default
		elseif type(value) ~= "string" then
			return nil, "profile_" .. field .. "_not_string"
		elseif #value > schema.maxBytes then
			return nil, "profile_" .. field .. "_too_large"
		elseif schema.jsonRoot then
			local validJson, jsonError = validateJsonDocument(
				value,
				schema.jsonRoot,
				schema.jsonShape,
				schema.maxItems,
				schema.maxElementBytes
			)
			if not validJson then
				return nil, "profile_" .. field .. "_json_" .. tostring(jsonError)
			end
		end
	end
	return profile
end

function ProfilePersistence.NormalizePurchaseId(value)
	local valueType = type(value)
	if valueType ~= "string" and valueType ~= "number" then
		return nil
	end
	if valueType == "number" and (value ~= value or value == math.huge or value == -math.huge) then
		return nil
	end
	local purchaseId = tostring(value)
	if purchaseId == "" or #purchaseId > 128 then
		return nil
	end
	return purchaseId
end

local function sanitizeReceiptEntry(purchaseId, source)
	if source ~= nil and type(source) ~= "table" then
		return nil, "receipt_entry_not_table"
	end
	source = source or {}
	if source.PurchaseId ~= nil
		and ProfilePersistence.NormalizePurchaseId(source.PurchaseId) ~= purchaseId
	then
		return nil, "receipt_entry_purchase_id_mismatch"
	end
	local productId = source.ProductId == nil and 0
		or strictNonNegativeInteger(source.ProductId)
	if productId == nil then
		return nil, "receipt_entry_invalid_product_id"
	end
	local processedAt = source.ProcessedAt == nil and 0 or source.ProcessedAt
	if not isFiniteNumber(processedAt)
		or processedAt < 0
		or processedAt > ProfilePersistence.MaxAuthoritativeNumber
	then
		return nil, "receipt_entry_invalid_processed_at"
	end
	local grantToken = source.GrantToken == nil and "" or source.GrantToken
	if type(grantToken) ~= "string" then
		return nil, "receipt_entry_invalid_grant_token"
	end
	if #grantToken > 160 then
		return nil, "receipt_entry_grant_token_too_large"
	end
	local entry = {
		PurchaseId = purchaseId,
		ProductId = productId,
		ProcessedAt = processedAt,
		GrantToken = grantToken,
	}
	if source.Coins ~= nil then
		entry.Coins = strictNonNegativeInteger(source.Coins)
		if entry.Coins == nil then
			return nil, "receipt_entry_invalid_coins"
		end
	end
	if source.Spins ~= nil then
		entry.Spins = strictNonNegativeInteger(source.Spins)
		if entry.Spins == nil then
			return nil, "receipt_entry_invalid_spins"
		end
	end
	if source.Honor ~= nil then
		entry.Honor = strictNonNegativeInteger(source.Honor)
		if entry.Honor == nil then
			return nil, "receipt_entry_invalid_honor"
		end
	end
	if source.Boost ~= nil then
		if type(source.Boost) ~= "string" or not BOOST_EXPIRY_FIELD_SET[source.Boost] then
			return nil, "receipt_entry_invalid_boost"
		end
		local boostExpiresAt = source.BoostExpiresAt == nil and 0 or source.BoostExpiresAt
		if not isFiniteNumber(boostExpiresAt)
			or boostExpiresAt < 0
			or boostExpiresAt > ProfilePersistence.MaxAuthoritativeNumber
		then
			return nil, "receipt_entry_invalid_boost_expiry"
		end
		entry.Boost = source.Boost
		entry.BoostExpiresAt = boostExpiresAt
	elseif source.BoostExpiresAt ~= nil then
		return nil, "receipt_entry_boost_expiry_without_boost"
	end
	return entry
end

function ProfilePersistence.NormalizeReceiptLedger(rawLedger, maxEntries, maxSeenReceiptIds)
	maxEntries = math.clamp(
		math.floor(tonumber(maxEntries) or ProfilePersistence.MaxReceiptLedgerEntries),
		1,
		ProfilePersistence.MaxReceiptLedgerEntries
	)
	maxSeenReceiptIds = math.clamp(
		math.max(
		maxEntries,
		math.floor(tonumber(maxSeenReceiptIds) or ProfilePersistence.MaxSeenReceiptIds)
		),
		maxEntries,
		ProfilePersistence.MaxSeenReceiptIds
	)
	local ledger = {
		Order = {},
		Entries = {},
		Seen = {},
	}
	if rawLedger == nil then
		return ledger
	end
	if type(rawLedger) ~= "table" then
		return nil, "receipt_ledger_not_table"
	end
	for _, field in ipairs(RECEIPT_LEDGER_FIELDS) do
		if rawLedger[field] ~= nil and type(rawLedger[field]) ~= "table" then
			return nil, "receipt_ledger_" .. string.lower(field) .. "_not_table"
		end
	end

	local seenCount = 0
	local function remember(rawPurchaseId, rawProductId)
		local purchaseId = ProfilePersistence.NormalizePurchaseId(rawPurchaseId)
		if not purchaseId then
			return false, "receipt_seen_invalid_purchase_id"
		end
		local productId = rawProductId == nil and 0
			or strictNonNegativeInteger(rawProductId)
		if productId == nil then
			return false, "receipt_seen_invalid_product_id"
		end
		local existingProductId = ledger.Seen[purchaseId]
		if existingProductId ~= nil then
			if existingProductId == 0 and productId > 0 then
				ledger.Seen[purchaseId] = productId
			elseif productId > 0
				and existingProductId > 0
				and existingProductId ~= productId
			then
				return false, "receipt_seen_product_mismatch"
			end
			return true
		end
		if seenCount >= maxSeenReceiptIds then
			return false, "receipt_seen_guard_exceeded"
		end
		ledger.Seen[purchaseId] = productId
		seenCount += 1
		return true
	end

	local rawSeen = type(rawLedger.Seen) == "table" and rawLedger.Seen or {}
	local arrayIndices = {}
	local mappedSeen = {}
	for rawPurchaseId, rawProductId in pairs(rawSeen) do
		if type(rawPurchaseId) == "number"
			and rawPurchaseId >= 1
			and rawPurchaseId % 1 == 0
		then
			table.insert(arrayIndices, rawPurchaseId)
		else
			local purchaseId = ProfilePersistence.NormalizePurchaseId(rawPurchaseId)
			local productId = strictNonNegativeInteger(rawProductId)
			if not purchaseId then
				return nil, "receipt_seen_invalid_purchase_id"
			end
			if productId == nil then
				return nil, "receipt_seen_invalid_product_id"
			end
			table.insert(mappedSeen, {
				purchaseId = purchaseId,
				productId = productId,
			})
		end
	end
	table.sort(arrayIndices)
	for _, arrayIndex in ipairs(arrayIndices) do
		local remembered, rememberError = remember(rawSeen[arrayIndex], 0)
		if not remembered then
			return nil, rememberError
		end
	end
	table.sort(mappedSeen, function(left, right)
		return left.purchaseId < right.purchaseId
	end)
	for _, mapped in ipairs(mappedSeen) do
		local remembered, rememberError = remember(mapped.purchaseId, mapped.productId)
		if not remembered then
			return nil, rememberError
		end
	end

	local structured = type(rawLedger.Order) == "table"
		or type(rawLedger.Entries) == "table"
		or type(rawLedger.Seen) == "table"
	local sourceOrder = structured and rawLedger.Order or rawLedger
	local sourceEntries = structured and rawLedger.Entries or rawLedger
	sourceOrder = type(sourceOrder) == "table" and sourceOrder or {}
	sourceEntries = type(sourceEntries) == "table" and sourceEntries or {}
	local seen = {}

	local function append(rawPurchaseId)
		local purchaseId = ProfilePersistence.NormalizePurchaseId(rawPurchaseId)
		if not purchaseId then
			return false, "receipt_order_invalid_purchase_id"
		end
		if seen[purchaseId] then
			return
		end
		local sourceEntry = sourceEntries[purchaseId]
		if sourceEntry == nil then
			sourceEntry = sourceEntries[rawPurchaseId]
		end
		if sourceEntry == nil and structured then
			return
		end
		local sanitizedEntry, entryError = sanitizeReceiptEntry(purchaseId, sourceEntry)
		if not sanitizedEntry then
			return false, entryError
		end
		local remembered, rememberError = remember(purchaseId, sanitizedEntry.ProductId)
		if not remembered then
			return false, rememberError
		end
		seen[purchaseId] = true
		table.insert(ledger.Order, purchaseId)
		ledger.Entries[purchaseId] = sanitizedEntry
		return true
	end

	for _, rawPurchaseId in ipairs(sourceOrder) do
		local appended, appendError = append(rawPurchaseId)
		if appended == false then
			return nil, appendError
		end
	end

	local extraIds = {}
	for rawPurchaseId in pairs(sourceEntries) do
		local purchaseId = ProfilePersistence.NormalizePurchaseId(rawPurchaseId)
		if not purchaseId then
			return nil, "receipt_entries_invalid_purchase_id"
		end
		if not seen[purchaseId] then
			table.insert(extraIds, purchaseId)
		end
	end
	table.sort(extraIds)
	for _, purchaseId in ipairs(extraIds) do
		local appended, appendError = append(purchaseId)
		if appended == false then
			return nil, appendError
		end
	end

	while #ledger.Order > maxEntries do
		local compactedPurchaseId = table.remove(ledger.Order, 1)
		ledger.Entries[compactedPurchaseId] = nil
	end
	return ledger
end

function ProfilePersistence.NormalizeSessionToken(value)
	if type(value) ~= "string"
		or value == ""
		or #value > ProfilePersistence.MaxSessionTokenBytes
	then
		return nil
	end
	return value
end

local function normalizeLeaseTime(value, errorName)
	if not isFiniteNumber(value)
		or value < 0
		or value > ProfilePersistence.MaxAuthoritativeNumber
	then
		return nil, errorName
	end
	return value
end

local function normalizeLeaseDuration(value)
	if value == nil then
		return ProfilePersistence.DefaultSessionLeaseSeconds
	end
	if not isFiniteNumber(value) or value <= 0 then
		return nil, "invalid_lease_duration"
	end
	return math.clamp(
		value,
		ProfilePersistence.MinSessionLeaseSeconds,
		ProfilePersistence.MaxSessionLeaseSeconds
	)
end

local function normalizeLeaseMetadata(profile)
	local revision = profile.ProfileRevision
	if revision == nil then
		revision = 0
	else
		revision = strictNonNegativeInteger(revision)
		if revision == nil then
			return nil, "invalid_profile_revision"
		end
	end
	profile.ProfileRevision = revision

	local lease = profile.SessionLease
	if lease == nil then
		return profile
	end
	if type(lease) ~= "table" then
		return nil, "invalid_session_lease"
	end
	local token = ProfilePersistence.NormalizeSessionToken(lease.Token)
	if not token then
		return nil, "invalid_session_lease_token"
	end
	local leaseRevision = strictNonNegativeInteger(lease.Revision)
	if not leaseRevision or leaseRevision < 1 or leaseRevision ~= revision then
		return nil, "invalid_session_lease_revision"
	end
	local expiresAt, expiryError = normalizeLeaseTime(
		lease.ExpiresAt,
		"invalid_session_lease_expiry"
	)
	if not expiresAt then
		return nil, expiryError
	end
	profile.SessionLease = {
		Token = token,
		Revision = leaseRevision,
		ExpiresAt = expiresAt,
	}
	return profile
end

local function normalizeFence(fence)
	if type(fence) ~= "table" then
		return nil, "invalid_session_fence"
	end
	local token = ProfilePersistence.NormalizeSessionToken(fence.Token)
	local revision = strictNonNegativeInteger(fence.Revision)
	if not token or not revision or revision < 1 then
		return nil, "invalid_session_fence"
	end
	return {
		Token = token,
		Revision = revision,
	}
end

local function validateSessionFence(profile, fence, now, requireActive)
	if type(profile) ~= "table" then
		return false, "profile_not_table"
	end
	local checkedProfile, profileError = normalizeLeaseMetadata(shallowCopy(profile))
	if not checkedProfile then
		return false, profileError
	end
	local normalizedFence, fenceError = normalizeFence(fence)
	if not normalizedFence then
		return false, fenceError
	end
	local checkedNow, nowError = normalizeLeaseTime(now, "invalid_lease_time")
	if not checkedNow then
		return false, nowError
	end
	local revision = checkedProfile.ProfileRevision
	local lease = checkedProfile.SessionLease
	if revision == nil or type(lease) ~= "table" then
		return false, "session_lease_not_held"
	end
	if revision ~= normalizedFence.Revision
		or lease.Revision ~= normalizedFence.Revision
		or lease.Token ~= normalizedFence.Token
	then
		return false, "stale_session_fence"
	end
	if not isFiniteNumber(lease.ExpiresAt) or lease.ExpiresAt < 0 then
		return false, "invalid_session_lease_expiry"
	end
	if requireActive ~= false and lease.ExpiresAt <= checkedNow then
		return false, "session_lease_expired"
	end
	return true
end

function ProfilePersistence.ValidateSessionFence(profile, fence, now)
	return validateSessionFence(profile, fence, now, true)
end

function ProfilePersistence.Migrate(rawProfile, currentVersion, maxEntries)
	if type(rawProfile) ~= "table" then
		return nil, "profile_not_table"
	end
	currentVersion = positiveInteger(currentVersion) or 1
	local sourceVersion = rawProfile.DataVersion == nil and 1
		or strictNonNegativeInteger(rawProfile.DataVersion)
	if not sourceVersion or sourceVersion < 1 then
		return nil, "invalid_data_version"
	end
	if sourceVersion > currentVersion then
		return nil, "future_data_version"
	end

	local profile, canonicalError = canonicalProfileCopy(
		rawProfile,
		sourceVersion,
		currentVersion
	)
	if not profile then
		return nil, canonicalError
	end
	-- HonorPowerBonus is derived from the equipped catalog entry. Versions before
	-- v7 legitimately persisted values up to 0.25, so clear that stale cache
	-- before applying the tighter v7 authoritative schema. Bootstrap re-derives
	-- the exact current value after canonicalizing ownership and equipment.
	if currentVersion >= 7 and sourceVersion < 7 then
		profile.HonorPowerBonus = 0
	end
	-- v8 replaces the long legacy onboarding with a short punch -> shop -> fist
	-- journey. Only the old terminal step counts as completed; unfinished legacy
	-- players restart the new tutorial, while veterans never see it again.
	if currentVersion >= 8 and sourceVersion < 8 then
		local legacyStep = tonumber(profile.TutorialStep) or 1
		local legacyCompleted = legacyStep >= 8
		profile.TutorialVersion = 2
		profile.TutorialCompleted = legacyCompleted and 1 or 0
		profile.TutorialStep = legacyCompleted and 4 or 1
	end
	-- DataVersion 3 stored fractional FistMastery progress (for example 6.25),
	-- while the current authoritative stat is an integer counter. Preserve every
	-- completed mastery level without inventing progress. Invalid types, nonfinite
	-- values, and values below the historical minimum still fail schema validation.
	if sourceVersion < currentVersion
		and type(profile.FistMastery) == "number"
		and profile.FistMastery == profile.FistMastery
		and profile.FistMastery ~= math.huge
		and profile.FistMastery ~= -math.huge
		and profile.FistMastery >= 1
	then
		profile.FistMastery = math.floor(profile.FistMastery)
	end
	local validatedProfile, schemaError = validateAuthoritativeFields(profile)
	if not validatedProfile then
		return nil, schemaError
	end
	local normalizedLedger, ledgerError = ProfilePersistence.NormalizeReceiptLedger(
		profile.ProcessedReceipts,
		maxEntries,
		ProfilePersistence.MaxSeenReceiptIds
	)
	if not normalizedLedger then
		return nil, ledgerError
	end
	profile.ProcessedReceipts = normalizedLedger
	local leaseProfile, leaseError = normalizeLeaseMetadata(profile)
	if not leaseProfile then
		return nil, leaseError
	end
	profile.DataVersion = currentVersion
	return profile, sourceVersion == currentVersion and "Current" or "Migrated"
end

function ProfilePersistence.NewProfile(currentVersion, maxEntries)
	return ProfilePersistence.Migrate({}, currentVersion, maxEntries)
end

function ProfilePersistence.AcquireSessionLease(
	previousProfile,
	sessionToken,
	now,
	leaseSeconds,
	currentVersion,
	maxEntries
)
	local token = ProfilePersistence.NormalizeSessionToken(sessionToken)
	if not token then
		return nil, nil, false, "invalid_session_token"
	end
	local checkedNow, nowError = normalizeLeaseTime(now, "invalid_lease_time")
	if not checkedNow then
		return nil, nil, false, nowError
	end
	local duration, durationError = normalizeLeaseDuration(leaseSeconds)
	if not duration then
		return nil, nil, false, durationError
	end
	if checkedNow > ProfilePersistence.MaxAuthoritativeNumber - duration then
		return nil, nil, false, "lease_expiry_out_of_range"
	end
	local profile, migrationState = ProfilePersistence.Migrate(
		previousProfile or {},
		currentVersion,
		maxEntries
	)
	if not profile then
		return nil, nil, false, migrationState
	end

	local existingLease = profile.SessionLease
	if existingLease
		and existingLease.ExpiresAt > checkedNow
		and existingLease.Token ~= token
	then
		return nil, nil, false, "session_lease_held"
	end

	local revision = profile.ProfileRevision
	local leaseState = "Acquired"
	if existingLease
		and existingLease.ExpiresAt > checkedNow
		and existingLease.Token == token
	then
		revision = existingLease.Revision
		leaseState = "Renewed"
	else
		if revision >= ProfilePersistence.MaxAuthoritativeNumber then
			return nil, nil, false, "profile_revision_exhausted"
		end
		revision += 1
	end
	profile.ProfileRevision = revision
	local expiresAt = checkedNow + duration
	if leaseState == "Renewed" then
		expiresAt = math.max(expiresAt, existingLease.ExpiresAt)
	end
	profile.SessionLease = {
		Token = token,
		Revision = revision,
		ExpiresAt = expiresAt,
	}
	return profile, {
		Token = token,
		Revision = revision,
	}, true, leaseState
end

function ProfilePersistence.RenewSessionLease(
	previousProfile,
	fence,
	now,
	leaseSeconds,
	currentVersion,
	maxEntries
)
	local checkedNow, nowError = normalizeLeaseTime(now, "invalid_lease_time")
	if not checkedNow then
		return nil, nil, false, nowError
	end
	local duration, durationError = normalizeLeaseDuration(leaseSeconds)
	if not duration then
		return nil, nil, false, durationError
	end
	if checkedNow > ProfilePersistence.MaxAuthoritativeNumber - duration then
		return nil, nil, false, "lease_expiry_out_of_range"
	end
	local profile, migrationState = ProfilePersistence.Migrate(
		previousProfile,
		currentVersion,
		maxEntries
	)
	if not profile then
		return nil, nil, false, migrationState
	end
	local ownsLease, fenceError = validateSessionFence(profile, fence, checkedNow, true)
	if not ownsLease then
		return nil, nil, false, fenceError
	end
	local normalizedFence = normalizeFence(fence)
	profile.SessionLease = {
		Token = normalizedFence.Token,
		Revision = normalizedFence.Revision,
		ExpiresAt = math.max(
			profile.SessionLease.ExpiresAt,
			checkedNow + duration
		),
	}
	return profile, normalizedFence, true, "Renewed"
end

function ProfilePersistence.ReleaseSessionLease(
	previousProfile,
	fence,
	now,
	currentVersion,
	maxEntries
)
	local checkedNow, nowError = normalizeLeaseTime(now, "invalid_lease_time")
	if not checkedNow then
		return nil, false, nowError
	end
	local profile, migrationState = ProfilePersistence.Migrate(
		previousProfile,
		currentVersion,
		maxEntries
	)
	if not profile then
		return nil, false, migrationState
	end
	local ownsLease, fenceError = validateSessionFence(profile, fence, checkedNow, false)
	if not ownsLease then
		return nil, false, fenceError
	end
	profile.SessionLease = nil
	return profile, true, nil
end

local function validateSnapshotTopLevel(snapshot, currentVersion)
	for key in pairs(snapshot) do
		if not KNOWN_PROFILE_FIELDS[key] then
			return false, "snapshot_unknown_field"
		end
	end
	if snapshot.DataVersion ~= nil then
		local snapshotVersion = strictNonNegativeInteger(snapshot.DataVersion)
		if not snapshotVersion or snapshotVersion ~= currentVersion then
			return false, "snapshot_data_version_mismatch"
		end
	end
	return true
end

function ProfilePersistence.MergeSnapshot(previousProfile, snapshot, currentVersion, maxEntries)
	if previousProfile ~= nil and type(previousProfile) ~= "table" then
		return nil, "stored_profile_not_table"
	end
	if type(snapshot) ~= "table" then
		return nil, "snapshot_not_table"
	end
	local normalizedCurrentVersion = positiveInteger(currentVersion) or 1
	local validSnapshot, snapshotError = validateSnapshotTopLevel(
		snapshot,
		normalizedCurrentVersion
	)
	if not validSnapshot then
		return nil, snapshotError
	end
	local profile, migrateState = ProfilePersistence.Migrate(
		previousProfile or {},
		normalizedCurrentVersion,
		maxEntries
	)
	if not profile then
		return nil, migrateState
	end
	for key, value in pairs(snapshot) do
		if not RESERVED_PROFILE_FIELDS[key] then
			profile[key] = value
		end
	end
	local validatedProfile, schemaError = validateAuthoritativeFields(profile)
	if not validatedProfile then
		return nil, schemaError
	end
	profile.DataVersion = normalizedCurrentVersion
	return profile, migrateState
end

function ProfilePersistence.MergeSnapshotFenced(
	previousProfile,
	snapshot,
	fence,
	now,
	currentVersion,
	maxEntries
)
	local profile, migrationState = ProfilePersistence.Migrate(
		previousProfile,
		currentVersion,
		maxEntries
	)
	if not profile then
		return nil, migrationState
	end
	local ownsLease, fenceError = validateSessionFence(profile, fence, now, true)
	if not ownsLease then
		return nil, fenceError
	end
	return ProfilePersistence.MergeSnapshot(
		profile,
		snapshot,
		currentVersion,
		maxEntries
	)
end

function ProfilePersistence.GetReceiptEntry(profile, rawPurchaseId, maxEntries)
	if type(profile) ~= "table" then
		return nil
	end
	local purchaseId = ProfilePersistence.NormalizePurchaseId(rawPurchaseId)
	if not purchaseId then
		return nil
	end
	local ledger = ProfilePersistence.NormalizeReceiptLedger(profile.ProcessedReceipts, maxEntries)
	if not ledger then
		return nil
	end
	return ledger.Entries[purchaseId]
end

function ProfilePersistence.GetSeenReceiptProductId(profile, rawPurchaseId, maxEntries)
	if type(profile) ~= "table" then
		return nil
	end
	local purchaseId = ProfilePersistence.NormalizePurchaseId(rawPurchaseId)
	if not purchaseId then
		return nil
	end
	local ledger = ProfilePersistence.NormalizeReceiptLedger(profile.ProcessedReceipts, maxEntries)
	if not ledger then
		return nil
	end
	return ledger.Seen[purchaseId]
end

function ProfilePersistence.ReceiptIdSet(profile, maxEntries)
	local result = {}
	if type(profile) ~= "table" then
		return result
	end
	local ledger = ProfilePersistence.NormalizeReceiptLedger(profile.ProcessedReceipts, maxEntries)
	if not ledger then
		return result
	end
	for purchaseId in pairs(ledger.Seen) do
		result[purchaseId] = true
	end
	return result
end

function ProfilePersistence.ApplyReceipt(
	profile,
	rawPurchaseId,
	productId,
	product,
	grantToken,
	processedAt,
	maxEntries
)
	if type(profile) ~= "table" or type(product) ~= "table" then
		return nil, nil, false, "invalid_receipt_input"
	end
	for key in pairs(profile) do
		if not KNOWN_PROFILE_FIELDS[key] then
			return nil, nil, false, "receipt_profile_unknown_field"
		end
	end
	local purchaseId = ProfilePersistence.NormalizePurchaseId(rawPurchaseId)
	if not purchaseId then
		return nil, nil, false, "invalid_purchase_id"
	end
	productId = strictNonNegativeInteger(productId)
	if not productId or productId <= 0 then
		return nil, nil, false, "invalid_product_id"
	end
	if type(grantToken) ~= "string" or grantToken == "" or #grantToken > 160 then
		return nil, nil, false, "invalid_grant_token"
	end
	if not isFiniteNumber(processedAt)
		or processedAt < 0
		or processedAt > ProfilePersistence.MaxAuthoritativeNumber
	then
		return nil, nil, false, "invalid_processed_at"
	end
	if product.coins == nil and product.spins == nil and product.boost == nil and product.honor == nil then
		return nil, nil, false, "empty_product_grant"
	end
	local grantKindCount = (product.coins ~= nil and 1 or 0)
		+ (product.spins ~= nil and 1 or 0)
		+ (product.boost ~= nil and 1 or 0)
		+ (product.honor ~= nil and 1 or 0)
	if grantKindCount ~= 1 then
		return nil, nil, false, "product_grant_kind_count_invalid"
	end
	if product.boost ~= nil
		and (type(product.boost) ~= "string" or not BOOST_EXPIRY_FIELD_SET[product.boost])
	then
		return nil, nil, false, "invalid_boost_field"
	end
	local boostSeconds
	if product.boost ~= nil then
		boostSeconds = product.seconds
		if not isFiniteNumber(boostSeconds)
			or boostSeconds <= 0
			or boostSeconds > ProfilePersistence.MaxAuthoritativeNumber
		then
			return nil, nil, false, "invalid_boost_duration"
		end
	end
	local coinGrant
	if product.coins ~= nil then
		coinGrant = strictNonNegativeInteger(product.coins)
		if not coinGrant or coinGrant <= 0 then
			return nil, nil, false, "invalid_coin_grant"
		end
	end
	local spinGrant
	if product.spins ~= nil then
		spinGrant = strictNonNegativeInteger(product.spins)
		if not spinGrant or spinGrant <= 0 then
			return nil, nil, false, "invalid_spin_grant"
		end
	end
	local honorGrant
	if product.honor ~= nil then
		honorGrant = strictNonNegativeInteger(product.honor)
		if not honorGrant or honorGrant <= 0 then
			return nil, nil, false, "invalid_honor_grant"
		end
	end

	local ledger, ledgerError = ProfilePersistence.NormalizeReceiptLedger(profile.ProcessedReceipts, maxEntries)
	if not ledger then
		return nil, nil, false, ledgerError
	end
	local seenProductId = ledger.Seen[purchaseId]
	local existing = ledger.Entries[purchaseId]
	if seenProductId ~= nil then
		if seenProductId > 0 and seenProductId ~= productId then
			return nil, existing, false, "receipt_product_mismatch"
		end
		profile.ProcessedReceipts = ledger
		return profile, existing or {
			PurchaseId = purchaseId,
			ProductId = seenProductId > 0 and seenProductId or productId,
			Compacted = true,
		}, false, nil
	end

	local seenCount = 0
	for _ in pairs(ledger.Seen) do
		seenCount += 1
	end
	if seenCount >= ProfilePersistence.MaxSeenReceiptIds then
		return nil, nil, false, "receipt_seen_guard_reached"
	end

	local entry = {
		PurchaseId = purchaseId,
		ProductId = productId,
		ProcessedAt = processedAt,
		GrantToken = grantToken,
	}
	if coinGrant then
		if not isFiniteNumber(profile.Coins)
			or profile.Coins < 0
			or profile.Coins > ProfilePersistence.MaxAuthoritativeNumber - coinGrant
		then
			return nil, nil, false, "invalid_coin_balance"
		end
		profile.Coins += coinGrant
		entry.Coins = coinGrant
	end
	if spinGrant then
		if not isFiniteNumber(profile.SpinCredits)
			or profile.SpinCredits < 0
			or profile.SpinCredits > ProfilePersistence.MaxAuthoritativeNumber - spinGrant
		then
			return nil, nil, false, "invalid_spin_balance"
		end
		profile.SpinCredits += spinGrant
		entry.Spins = spinGrant
	end
	if honorGrant then
		if not isFiniteNumber(profile.Honor)
			or profile.Honor < 0
			or profile.Honor > ProfilePersistence.MaxAuthoritativeNumber - honorGrant
		then
			return nil, nil, false, "invalid_honor_balance"
		end
		profile.Honor += honorGrant
		entry.Honor = honorGrant
	end
	if product.boost then
		local currentExpiry = profile[product.boost]
		if not isFiniteNumber(currentExpiry)
			or currentExpiry < 0
			or currentExpiry > ProfilePersistence.MaxAuthoritativeNumber
		then
			return nil, nil, false, "invalid_boost_balance"
		end
		local expiryBase = math.max(currentExpiry, entry.ProcessedAt)
		if expiryBase > ProfilePersistence.MaxAuthoritativeNumber - boostSeconds then
			return nil, nil, false, "boost_expiry_out_of_range"
		end
		local expiresAt = expiryBase + boostSeconds
		profile[product.boost] = expiresAt
		entry.Boost = product.boost
		entry.BoostExpiresAt = expiresAt
	end

	table.insert(ledger.Order, purchaseId)
	ledger.Entries[purchaseId] = entry
	ledger.Seen[purchaseId] = productId
	local receiptEntryLimit = math.clamp(
		math.floor(tonumber(maxEntries) or ProfilePersistence.MaxReceiptLedgerEntries),
		1,
		ProfilePersistence.MaxReceiptLedgerEntries
	)
	while #ledger.Order > receiptEntryLimit do
		local compactedPurchaseId = table.remove(ledger.Order, 1)
		ledger.Entries[compactedPurchaseId] = nil
	end
	profile.ProcessedReceipts = ledger
	return profile, entry, true, nil
end

function ProfilePersistence.ApplyReceiptEntryToSnapshot(snapshot, entry)
	if type(snapshot) ~= "table" or type(entry) ~= "table" then
		return false
	end
	local purchaseId = ProfilePersistence.NormalizePurchaseId(entry.PurchaseId)
	if not purchaseId then
		return false
	end
	local sanitizedEntry = sanitizeReceiptEntry(purchaseId, entry)
	if not sanitizedEntry then
		return false
	end
	if sanitizedEntry.Coins ~= nil then
		if not isFiniteNumber(snapshot.Coins)
			or snapshot.Coins < 0
			or snapshot.Coins > ProfilePersistence.MaxAuthoritativeNumber - sanitizedEntry.Coins
		then
			return false
		end
		snapshot.Coins += sanitizedEntry.Coins
	end
	if sanitizedEntry.Spins ~= nil then
		if not isFiniteNumber(snapshot.SpinCredits)
			or snapshot.SpinCredits < 0
			or snapshot.SpinCredits > ProfilePersistence.MaxAuthoritativeNumber - sanitizedEntry.Spins
		then
			return false
		end
		snapshot.SpinCredits += sanitizedEntry.Spins
	end
	if sanitizedEntry.Honor ~= nil then
		if not isFiniteNumber(snapshot.Honor)
			or snapshot.Honor < 0
			or snapshot.Honor > ProfilePersistence.MaxAuthoritativeNumber - sanitizedEntry.Honor
		then
			return false
		end
		snapshot.Honor += sanitizedEntry.Honor
	end
	if sanitizedEntry.Boost then
		local snapshotExpiry = snapshot[sanitizedEntry.Boost]
		if not isFiniteNumber(snapshotExpiry)
			or snapshotExpiry < 0
			or snapshotExpiry > ProfilePersistence.MaxAuthoritativeNumber
		then
			return false
		end
		snapshot[sanitizedEntry.Boost] = math.max(
			snapshotExpiry,
			sanitizedEntry.BoostExpiresAt
		)
	end
	return true
end

function ProfilePersistence.ReceiptEntryHasGrantMetadata(entry)
	return type(entry) == "table"
		and (entry.Coins ~= nil or entry.Spins ~= nil or entry.Honor ~= nil or entry.Boost ~= nil)
end

function ProfilePersistence.CommitReceipt(
	previousProfile,
	snapshot,
	snapshotIncludesReceipt,
	rawPurchaseId,
	productId,
	product,
	grantToken,
	processedAt,
	currentVersion,
	maxEntries
)
	if type(snapshot) ~= "table" then
		return nil, nil, false, "snapshot_not_table"
	end
	local purchaseId = ProfilePersistence.NormalizePurchaseId(rawPurchaseId)
	if not purchaseId then
		return nil, nil, false, "invalid_purchase_id"
	end
	local normalizedProductId = strictNonNegativeInteger(productId)
	if not normalizedProductId or normalizedProductId <= 0 then
		return nil, nil, false, "invalid_product_id"
	end

	local effectiveSnapshot = shallowCopy(snapshot)
	local previousEntry = ProfilePersistence.GetReceiptEntry(previousProfile, purchaseId, maxEntries)
	local previousSeenProductId = ProfilePersistence.GetSeenReceiptProductId(
		previousProfile,
		purchaseId,
		maxEntries
	)
	if previousSeenProductId ~= nil
		and previousSeenProductId > 0
		and previousSeenProductId ~= normalizedProductId
	then
		return nil, previousEntry, false, "receipt_product_mismatch"
	end
	if previousSeenProductId ~= nil
		and not ProfilePersistence.ReceiptEntryHasGrantMetadata(previousEntry)
		and snapshotIncludesReceipt ~= true
	then
		local canonical, migrationError = ProfilePersistence.Migrate(
			previousProfile,
			currentVersion,
			maxEntries
		)
		if not canonical then
			return nil, nil, false, migrationError
		end
		return canonical, {
			PurchaseId = purchaseId,
			ProductId = previousSeenProductId > 0 and previousSeenProductId
				or normalizedProductId,
			Compacted = true,
		}, false, "receipt_metadata_compacted"
	end
	if previousEntry and snapshotIncludesReceipt ~= true then
		if not ProfilePersistence.ApplyReceiptEntryToSnapshot(effectiveSnapshot, previousEntry) then
			return nil, nil, false, "receipt_snapshot_reconcile_failed"
		end
	end
	local canonical, mergeError = ProfilePersistence.MergeSnapshot(
		previousProfile,
		effectiveSnapshot,
		currentVersion,
		maxEntries
	)
	if not canonical then
		return nil, nil, false, mergeError
	end
	return ProfilePersistence.ApplyReceipt(
		canonical,
		purchaseId,
		normalizedProductId,
		product,
		grantToken,
		processedAt,
		maxEntries
	)
end

function ProfilePersistence.CommitReceiptFenced(
	previousProfile,
	snapshot,
	snapshotIncludesReceipt,
	rawPurchaseId,
	productId,
	product,
	grantToken,
	processedAt,
	fence,
	now,
	currentVersion,
	maxEntries
)
	local profile, migrationState = ProfilePersistence.Migrate(
		previousProfile,
		currentVersion,
		maxEntries
	)
	if not profile then
		return nil, nil, false, migrationState
	end
	local ownsLease, fenceError = validateSessionFence(profile, fence, now, true)
	if not ownsLease then
		return nil, nil, false, fenceError
	end
	return ProfilePersistence.CommitReceipt(
		profile,
		snapshot,
		snapshotIncludesReceipt,
		rawPurchaseId,
		productId,
		product,
		grantToken,
		processedAt,
		currentVersion,
		maxEntries
	)
end

function ProfilePersistence.RunContractSelfTest(currentVersion)
	currentVersion = math.max(6, positiveInteger(currentVersion) or 6)
	local migrated, migrateState = ProfilePersistence.Migrate({
		DataVersion = currentVersion - 1,
		Coins = 10,
		CoinBoostExpiresAt = 1234.5,
		HonorPowerBonus = currentVersion >= 8 and 0.12 or 0.25,
		LegacyOnlyPayload = {
			hidden = string.rep("x", 1024),
		},
	}, currentVersion)
	assert(migrated and migrateState == "Migrated", "migration contract failed")
	assert(migrated.CoinBoostExpiresAt == 1234.5, "boost migration contract failed")
	if currentVersion == 7 then
		assert(migrated.HonorPowerBonus == 0, "legacy Honor bonus was not cleared before v7 validation")
	elseif currentVersion >= 8 then
		assert(migrated.HonorPowerBonus == 0.12, "valid v7 Honor bonus was not retained during v8 migration")
		local legacyTutorialComplete, legacyTutorialCompleteState = ProfilePersistence.Migrate({
			DataVersion = 7,
			TutorialStep = 8,
		}, currentVersion)
		assert(
			legacyTutorialComplete
				and legacyTutorialCompleteState == "Migrated"
				and legacyTutorialComplete.TutorialVersion == 2
				and legacyTutorialComplete.TutorialStep == 4
				and legacyTutorialComplete.TutorialCompleted == 1,
			"completed legacy tutorial was not preserved during v8 migration"
		)
		local legacyTutorialIncomplete, legacyTutorialIncompleteState = ProfilePersistence.Migrate({
			DataVersion = 7,
			TutorialStep = 3,
		}, currentVersion)
		assert(
			legacyTutorialIncomplete
				and legacyTutorialIncompleteState == "Migrated"
				and legacyTutorialIncomplete.TutorialVersion == 2
				and legacyTutorialIncomplete.TutorialStep == 1
				and legacyTutorialIncomplete.TutorialCompleted == 0,
			"unfinished legacy tutorial was not restarted safely during v8 migration"
		)
	end
	assert(
		migrated.LegacyOnlyPayload == nil,
		"legacy migration did not drop unknown top-level fields"
	)
	local legacyFractionalMastery, legacyFractionalMasteryState =
		ProfilePersistence.Migrate({
			DataVersion = 3,
			FistMastery = 6.25,
			Coins = 1849,
		}, currentVersion)
	assert(
		legacyFractionalMastery
			and legacyFractionalMasteryState == "Migrated"
			and legacyFractionalMastery.FistMastery == 6
			and legacyFractionalMastery.Coins == 1849,
		"legacy fractional FistMastery was not migrated without data loss"
	)
	for _, field in ipairs(ProfilePersistence.BoostExpiryFields) do
		assert(type(migrated[field]) == "number", "boost migration field missing: " .. field)
	end
	for field, schema in pairs(ProfilePersistence.NumberFieldSchema) do
		assert(
			type(migrated[field]) == "number",
			"legacy numeric default missing: " .. field
		)
		assert(
			migrated[field] >= schema.min,
			"legacy numeric default out of range: " .. field
		)
	end
	for field in pairs(ProfilePersistence.TextFieldSchema) do
		assert(
			type(migrated[field]) == "string",
			"legacy text default missing: " .. field
		)
	end

	local currentProfile = ProfilePersistence.NewProfile(currentVersion)
	assert(currentProfile, "current profile fixture failed")
	local wrongTypeProfile = shallowCopy(currentProfile)
	wrongTypeProfile.Coins = "10"
	local wrongTypeResult, wrongTypeError = ProfilePersistence.Migrate(
		wrongTypeProfile,
		currentVersion
	)
	assert(
		wrongTypeResult == nil and wrongTypeError == "profile_Coins_not_number",
		"current wrong-type number must fail closed"
	)
	local wrongVersionTypeProfile = shallowCopy(currentProfile)
	wrongVersionTypeProfile.DataVersion = tostring(currentVersion)
	local wrongVersionTypeResult, wrongVersionTypeError = ProfilePersistence.Migrate(
		wrongVersionTypeProfile,
		currentVersion
	)
	assert(
		wrongVersionTypeResult == nil and wrongVersionTypeError == "invalid_data_version",
		"current wrong-type data version must fail closed"
	)
	local nonfiniteProfile = shallowCopy(currentProfile)
	nonfiniteProfile.Power = math.huge
	local nonfiniteResult, nonfiniteError = ProfilePersistence.Migrate(
		nonfiniteProfile,
		currentVersion
	)
	assert(
		nonfiniteResult == nil and nonfiniteError == "profile_Power_nonfinite",
		"current nonfinite number must fail closed"
	)
	local oversizedNumberProfile = shallowCopy(currentProfile)
	oversizedNumberProfile.Score = ProfilePersistence.MaxAuthoritativeNumber + 1
	local oversizedNumberResult, oversizedNumberError = ProfilePersistence.Migrate(
		oversizedNumberProfile,
		currentVersion
	)
	assert(
		oversizedNumberResult == nil
			and oversizedNumberError == "profile_Score_out_of_range",
		"current oversized number must fail closed"
	)
	local fractionalCounterProfile = shallowCopy(currentProfile)
	fractionalCounterProfile.Coins = 10.5
	local fractionalCounterResult, fractionalCounterError = ProfilePersistence.Migrate(
		fractionalCounterProfile,
		currentVersion
	)
	assert(
		fractionalCounterResult == nil
			and fractionalCounterError == "profile_Coins_not_integer",
		"fractional authoritative counter must fail closed"
	)
	local fractionalMultiplierProfile = shallowCopy(currentProfile)
	fractionalMultiplierProfile.CritChance = 12.5
	fractionalMultiplierProfile.FistMultiplier = 1.75
	fractionalMultiplierProfile.HonorPowerBonus = 0.115
	local fractionalMultiplierResult = ProfilePersistence.Migrate(
		fractionalMultiplierProfile,
		currentVersion
	)
	assert(
		fractionalMultiplierResult
			and fractionalMultiplierResult.CritChance == 12.5
			and fractionalMultiplierResult.FistMultiplier == 1.75
			and fractionalMultiplierResult.HonorPowerBonus == 0.115,
		"legitimate fractional multiplier or crit value was rejected"
	)
	local wrongTextTypeProfile = shallowCopy(currentProfile)
	wrongTextTypeProfile.Pet = {}
	local wrongTextTypeResult, wrongTextTypeError = ProfilePersistence.Migrate(
		wrongTextTypeProfile,
		currentVersion
	)
	assert(
		wrongTextTypeResult == nil
			and wrongTextTypeError == "profile_Pet_not_string",
		"current wrong-type text must fail closed"
	)
	local oversizedTextProfile = shallowCopy(currentProfile)
	oversizedTextProfile.EquippedFist = string.rep("x", 129)
	local oversizedTextResult, oversizedTextError = ProfilePersistence.Migrate(
		oversizedTextProfile,
		currentVersion
	)
	assert(
		oversizedTextResult == nil
			and oversizedTextError == "profile_EquippedFist_too_large",
		"current oversized text must fail closed"
	)
	local oversizedJsonProfile = shallowCopy(currentProfile)
	oversizedJsonProfile.LockedPetsJSON =
		"[" .. string.rep(" ", ProfilePersistence.MaxJsonBytes) .. "]"
	local oversizedJsonResult, oversizedJsonError = ProfilePersistence.Migrate(
		oversizedJsonProfile,
		currentVersion
	)
	assert(
		oversizedJsonResult == nil
			and oversizedJsonError == "profile_LockedPetsJSON_too_large",
		"current oversized JSON must fail closed"
	)
	local malformedJsonProfile = shallowCopy(currentProfile)
	malformedJsonProfile.PetInventoryJSON = "[}"
	local malformedJsonResult, malformedJsonError = ProfilePersistence.Migrate(
		malformedJsonProfile,
		currentVersion
	)
	assert(
		malformedJsonResult == nil
			and string.find(malformedJsonError, "profile_PetInventoryJSON_json_", 1, true) == 1,
		"current malformed JSON must fail closed"
	)
	local wrongJsonRootProfile = shallowCopy(currentProfile)
	wrongJsonRootProfile.EquippedPetsJSON = "{}"
	local wrongJsonRootResult, wrongJsonRootError = ProfilePersistence.Migrate(
		wrongJsonRootProfile,
		currentVersion
	)
	assert(
		wrongJsonRootResult == nil
			and wrongJsonRootError == "profile_EquippedPetsJSON_json_wrong_root",
		"current wrong-root JSON must fail closed"
	)
	local nonStringListProfile = shallowCopy(currentProfile)
	nonStringListProfile.PetInventoryJSON = "[\"Starter Pet\",3]"
	local nonStringListResult, nonStringListError = ProfilePersistence.Migrate(
		nonStringListProfile,
		currentVersion
	)
	assert(
		nonStringListResult == nil
			and nonStringListError
				== "profile_PetInventoryJSON_json_array_element_not_string",
		"JSON list accepted a non-string element"
	)
	local oversizedListElementProfile = shallowCopy(currentProfile)
	oversizedListElementProfile.LockedPetsJSON =
		"[\"" .. string.rep("x", ProfilePersistence.MaxJsonStringBytes + 1) .. "\"]"
	local oversizedListElementResult, oversizedListElementError =
		ProfilePersistence.Migrate(oversizedListElementProfile, currentVersion)
	assert(
		oversizedListElementResult == nil
			and oversizedListElementError
				== "profile_LockedPetsJSON_json_array_element_too_large",
		"JSON list accepted an oversized string element"
	)
	local tooManyJsonItems = {}
	for index = 1, ProfilePersistence.MaxJsonListEntries + 1 do
		tooManyJsonItems[index] = "\"pet-" .. tostring(index) .. "\""
	end
	local oversizedListProfile = shallowCopy(currentProfile)
	oversizedListProfile.DiscoveredPetsJSON =
		"[" .. table.concat(tooManyJsonItems, ",") .. "]"
	local oversizedListResult, oversizedListError = ProfilePersistence.Migrate(
		oversizedListProfile,
		currentVersion
	)
	assert(
		oversizedListResult == nil
			and oversizedListError
				== "profile_DiscoveredPetsJSON_json_too_many_items",
		"JSON list accepted too many string elements"
	)
	local invalidSettingsTypeProfile = shallowCopy(currentProfile)
	invalidSettingsTypeProfile.SettingsJSON =
		"{\"motion\":1,\"sound\":true,\"uiScale\":1}"
	local invalidSettingsTypeResult, invalidSettingsTypeError =
		ProfilePersistence.Migrate(invalidSettingsTypeProfile, currentVersion)
	assert(
		invalidSettingsTypeResult == nil
			and invalidSettingsTypeError
				== "profile_SettingsJSON_json_settings_invalid_motion",
		"Settings JSON accepted a non-boolean motion value"
	)
	local invalidSettingsScaleProfile = shallowCopy(currentProfile)
	invalidSettingsScaleProfile.SettingsJSON =
		"{\"motion\":true,\"sound\":true,\"uiScale\":1.21}"
	local invalidSettingsScaleResult, invalidSettingsScaleError =
		ProfilePersistence.Migrate(invalidSettingsScaleProfile, currentVersion)
	assert(
		invalidSettingsScaleResult == nil
			and invalidSettingsScaleError
				== "profile_SettingsJSON_json_settings_invalid_ui_scale",
		"Settings JSON accepted an out-of-range uiScale"
	)
	local nonfiniteSettingsProfile = shallowCopy(currentProfile)
	nonfiniteSettingsProfile.SettingsJSON =
		"{\"motion\":true,\"sound\":true,\"uiScale\":1e999}"
	local nonfiniteSettingsResult, nonfiniteSettingsError =
		ProfilePersistence.Migrate(nonfiniteSettingsProfile, currentVersion)
	assert(
		nonfiniteSettingsResult == nil
			and nonfiniteSettingsError == "profile_SettingsJSON_json_malformed",
		"Settings JSON accepted a nonfinite uiScale"
	)
	local unknownSettingsProfile = shallowCopy(currentProfile)
	unknownSettingsProfile.SettingsJSON =
		"{\"motion\":true,\"sound\":true,\"uiScale\":1,\"admin\":true}"
	local unknownSettingsResult, unknownSettingsError = ProfilePersistence.Migrate(
		unknownSettingsProfile,
		currentVersion
	)
	assert(
		unknownSettingsResult == nil
			and unknownSettingsError
				== "profile_SettingsJSON_json_settings_unknown_key",
		"Settings JSON accepted an unknown key"
	)
	local missingSettingsProfile = shallowCopy(currentProfile)
	missingSettingsProfile.SettingsJSON = "{\"motion\":true,\"uiScale\":1}"
	local missingSettingsResult, missingSettingsError = ProfilePersistence.Migrate(
		missingSettingsProfile,
		currentVersion
	)
	assert(
		missingSettingsResult == nil
			and missingSettingsError
				== "profile_SettingsJSON_json_settings_invalid_sound",
		"Settings JSON accepted a missing required key"
	)
	local boundarySettingsProfile = shallowCopy(currentProfile)
	boundarySettingsProfile.SettingsJSON =
		"{\"motion\":false,\"sound\":true,\"uiScale\":0.8}"
	assert(
		ProfilePersistence.Migrate(boundarySettingsProfile, currentVersion),
		"valid bounded Settings JSON was rejected"
	)
	local unknownCurrentFieldProfile = shallowCopy(currentProfile)
	unknownCurrentFieldProfile.HiddenPayload = {
		data = string.rep("x", ProfilePersistence.MaxJsonBytes),
	}
	local unknownCurrentFieldResult, unknownCurrentFieldError =
		ProfilePersistence.Migrate(unknownCurrentFieldProfile, currentVersion)
	assert(
		unknownCurrentFieldResult == nil
			and unknownCurrentFieldError == "unknown_profile_field",
		"current profile accepted an unknown top-level field"
	)
	local unknownSnapshotResult, unknownSnapshotError = ProfilePersistence.MergeSnapshot(
		currentProfile,
		{
			DataVersion = currentVersion,
			Coins = 11,
			HiddenSnapshotPayload = { exploit = true },
		},
		currentVersion
	)
	assert(
		unknownSnapshotResult == nil
			and unknownSnapshotError == "snapshot_unknown_field",
		"snapshot accepted an unknown top-level field"
	)
	local missingCurrentFieldProfile = shallowCopy(currentProfile)
	missingCurrentFieldProfile.Pet = nil
	local missingCurrentFieldResult, missingCurrentFieldError = ProfilePersistence.Migrate(
		missingCurrentFieldProfile,
		currentVersion
	)
	assert(
		missingCurrentFieldResult
			and missingCurrentFieldError == "Current"
			and missingCurrentFieldResult.Pet == "None",
		"legacy-shaped current profile did not receive a compatible missing-field default"
	)
	local migratedLegacyLedger = ProfilePersistence.Migrate({
		DataVersion = currentVersion - 1,
		ProcessedReceipts = {
			Order = { "legacy-receipt" },
			Entries = {
				["legacy-receipt"] = { ProductId = 99, Coins = 2 },
			},
		},
	}, currentVersion)
	assert(
		migratedLegacyLedger
			and ProfilePersistence.GetSeenReceiptProductId(
				migratedLegacyLedger,
				"legacy-receipt",
				3
			) == 99,
		"legacy receipt ledger migration forgot purchase id"
	)
	local mixedLedger, mixedLedgerError = ProfilePersistence.NormalizeReceiptLedger({
		Seen = {
			"mixed-array-receipt",
			["mixed-map-receipt"] = 701,
		},
	}, 3, 8)
	assert(mixedLedger and mixedLedgerError == nil, "mixed receipt ledger migration failed")
	assert(
		mixedLedger.Seen["mixed-array-receipt"] == 0,
		"mixed Seen migration forgot array purchase id"
	)
	assert(
		mixedLedger.Seen["mixed-map-receipt"] == 701,
		"mixed Seen migration forgot mapped purchase id"
	)
	local mixedProfile = ProfilePersistence.NewProfile(currentVersion)
	mixedProfile.ProcessedReceipts = mixedLedger
	mixedProfile.Coins = 25
	local mixedDuplicateProfile, mixedDuplicateEntry, mixedDuplicateGranted =
		ProfilePersistence.ApplyReceipt(
			mixedProfile,
			"mixed-map-receipt",
			701,
			{ coins = 9 },
			"mixed-duplicate-token",
			1900,
			3
		)
	assert(
		mixedDuplicateProfile
			and mixedDuplicateEntry
			and mixedDuplicateEntry.Compacted
			and not mixedDuplicateGranted,
		"duplicate after mixed Seen migration was not rejected"
	)
	assert(
		mixedDuplicateProfile.Coins == 25,
		"duplicate after mixed Seen migration changed balance"
	)

	local firstProfile, firstEntry, firstGrant = ProfilePersistence.ApplyReceipt(
		migrated,
		"receipt-a",
		101,
		{ coins = 7 },
		"token-a",
		2000,
		3
	)
	assert(firstProfile and firstEntry and firstGrant, "first receipt contract failed")
	assert(firstProfile.Coins == 17, "first receipt grant contract failed")
	local retryProfile, retryEntry, retryGrant = ProfilePersistence.CommitReceipt(
		firstProfile,
		{ DataVersion = currentVersion, Coins = 10 },
		false,
		"receipt-a",
		101,
		{ coins = 7 },
		"retry-token",
		2001,
		currentVersion,
		3
	)
	assert(retryProfile and retryEntry and not retryGrant, "receipt retry contract failed")
	assert(retryProfile.Coins == 17, "receipt retry erased or doubled durable reward")
	local duplicateProfile, duplicateEntry, duplicateGrant = ProfilePersistence.ApplyReceipt(
		retryProfile,
		"receipt-a",
		101,
		{ coins = 7 },
		"token-b",
		2001,
		3
	)
	assert(duplicateProfile and duplicateEntry and not duplicateGrant, "duplicate receipt contract failed")
	assert(duplicateProfile.Coins == 17, "duplicate receipt changed balance")

	local honorProfile = ProfilePersistence.NewProfile(currentVersion)
	honorProfile.Honor = 10
	local honoredProfile, honorEntry, honorGranted = ProfilePersistence.ApplyReceipt(
		honorProfile,
		"honor-receipt-a",
		401,
		{ honor = 25 },
		"honor-token-a",
		2002,
		3
	)
	assert(
		honoredProfile and honorEntry and honorEntry.Honor == 25 and honorGranted,
		"honor receipt metadata was not persisted"
	)
	assert(honoredProfile.Honor == 35, "honor receipt did not grant the exact amount")
	local honorReplay, _, honorReplayGranted = ProfilePersistence.ApplyReceipt(
		honoredProfile,
		"honor-receipt-a",
		401,
		{ honor = 25 },
		"honor-token-replay",
		2003,
		3
	)
	assert(honorReplay and not honorReplayGranted and honorReplay.Honor == 35, "honor receipt replay granted twice")
	local cappedHonorProfile = ProfilePersistence.NewProfile(currentVersion)
	cappedHonorProfile.Honor = ProfilePersistence.MaxAuthoritativeNumber - 24
	local cappedResult, _, cappedGranted, cappedError = ProfilePersistence.ApplyReceipt(
		cappedHonorProfile,
		"honor-overflow-a",
		402,
		{ honor = 25 },
		"honor-overflow-token",
		2004,
		3
	)
	assert(
		cappedResult == nil and not cappedGranted and cappedError == "invalid_honor_balance",
		"honor receipt overflow was not rejected without mutation"
	)
	assert(
		cappedHonorProfile.Honor == ProfilePersistence.MaxAuthoritativeNumber - 24
			and ProfilePersistence.GetSeenReceiptProductId(cappedHonorProfile, "honor-overflow-a", 3) == nil,
		"rejected honor receipt changed balance or durable replay state"
	)

	for index = 1, 4 do
		local updated, _, granted = ProfilePersistence.ApplyReceipt(
			duplicateProfile,
			"bounded-" .. index,
			200 + index,
			{ spins = 1 },
			"bounded-token-" .. index,
			2100 + index,
			3
		)
		assert(updated and granted, "bounded ledger insert failed")
		duplicateProfile = updated
	end
	assert(#duplicateProfile.ProcessedReceipts.Order == 3, "receipt ledger is not bounded")
	assert(ProfilePersistence.GetReceiptEntry(duplicateProfile, "bounded-4", 3), "latest receipt was trimmed")
	assert(
		ProfilePersistence.GetReceiptEntry(duplicateProfile, "receipt-a", 3) == nil,
		"old rich receipt metadata was not compacted"
	)
	assert(
		ProfilePersistence.GetSeenReceiptProductId(duplicateProfile, "receipt-a", 3) == 101,
		"compaction forgot durable purchase id"
	)
	local compactDuplicate, compactEntry, compactGranted = ProfilePersistence.ApplyReceipt(
		duplicateProfile,
		"receipt-a",
		101,
		{ coins = 7 },
		"compacted-duplicate-token",
		2200,
		3
	)
	assert(
		compactDuplicate and compactEntry and compactEntry.Compacted and not compactGranted,
		"compacted duplicate receipt was granted again"
	)
	assert(compactDuplicate.Coins == 17, "compacted duplicate changed balance")
	duplicateProfile = compactDuplicate

	local merged = ProfilePersistence.MergeSnapshot(duplicateProfile, {
		DataVersion = currentVersion,
		Coins = 4,
		ProcessedReceipts = { Order = {}, Entries = {} },
	}, currentVersion, 3)
	assert(merged and ProfilePersistence.GetReceiptEntry(merged, "bounded-4", 3), "snapshot erased receipt ledger")
	assert(
		ProfilePersistence.GetSeenReceiptProductId(merged, "receipt-a", 3) == 101,
		"snapshot erased compact receipt history"
	)
	assert(merged.Coins == 4, "snapshot merge contract failed")

	local boostProfile, boostEntry, boostGranted = ProfilePersistence.ApplyReceipt(
		merged,
		"boost-a",
		301,
		{ boost = "TrainingBoostExpiresAt", seconds = 900 },
		"boost-token",
		3000,
		3
	)
	assert(boostProfile and boostEntry and boostGranted, "boost receipt contract failed")
	assert(boostProfile.TrainingBoostExpiresAt == 3900, "boost expiry contract failed")

	local futureProfile = ProfilePersistence.Migrate({ DataVersion = currentVersion + 1 }, currentVersion)
	assert(futureProfile == nil, "future profile must fail closed")
	local corruptLedgerProfile = ProfilePersistence.Migrate({
		DataVersion = currentVersion,
		ProcessedReceipts = "corrupt",
	}, currentVersion)
	assert(corruptLedgerProfile == nil, "corrupt receipt ledger must fail closed")
	local seenGuardProfile, seenGuardError = ProfilePersistence.NormalizeReceiptLedger({
		Seen = {
			["guard-a"] = 1,
			["guard-b"] = 2,
			["guard-c"] = 3,
			["guard-d"] = 4,
		},
	}, 1, 3)
	assert(
		seenGuardProfile == nil and seenGuardError == "receipt_seen_guard_exceeded",
		"receipt seen guard must fail closed"
	)

	local leaseBase = ProfilePersistence.NewProfile(currentVersion)
	local leasedA, fenceA, acquiredA, acquireStateA =
		ProfilePersistence.AcquireSessionLease(
			leaseBase,
			"session-a",
			1000,
			ProfilePersistence.MaxSessionLeaseSeconds + 999,
			currentVersion,
			3
		)
	assert(
		leasedA and fenceA and acquiredA and acquireStateA == "Acquired",
		"first session lease acquisition failed"
	)
	assert(
		fenceA.Revision == 1
			and leasedA.ProfileRevision == 1
			and leasedA.SessionLease.ExpiresAt
				== 1000 + ProfilePersistence.MaxSessionLeaseSeconds,
		"session lease was not bounded or revisioned"
	)
	local blockedLease, _, blockedAcquire, blockedAcquireError =
		ProfilePersistence.AcquireSessionLease(
			leasedA,
			"session-b",
			1001,
			60,
			currentVersion,
			3
		)
	assert(
		blockedLease == nil
			and not blockedAcquire
			and blockedAcquireError == "session_lease_held",
		"live session lease allowed a second owner"
	)
	local renewedA, renewedFenceA, didRenewA =
		ProfilePersistence.RenewSessionLease(
			leasedA,
			fenceA,
			1100,
			60,
			currentVersion,
			3
		)
	assert(
		renewedA
			and renewedFenceA.Revision == fenceA.Revision
			and didRenewA
			and renewedA.SessionLease.ExpiresAt
				<= 1100 + ProfilePersistence.MaxSessionLeaseSeconds,
		"session lease renewal was not bounded"
	)
	local leasedB, fenceB, acquiredB =
		ProfilePersistence.AcquireSessionLease(
			renewedA,
			"session-b",
			renewedA.SessionLease.ExpiresAt + 1,
			60,
			currentVersion,
			3
		)
	assert(
		leasedB
			and fenceB
			and acquiredB
			and fenceB.Revision == fenceA.Revision + 1,
		"stale lease takeover did not advance the fencing revision"
	)
	local staleMerged, staleMergeError = ProfilePersistence.MergeSnapshotFenced(
		leasedB,
		{ DataVersion = currentVersion, Coins = 77 },
		fenceA,
		leasedB.SessionLease.ExpiresAt - 1,
		currentVersion,
		3
	)
	assert(
		staleMerged == nil and staleMergeError == "stale_session_fence",
		"stale fencing revision was allowed to merge"
	)
	local fencedMerged, fencedMergeState = ProfilePersistence.MergeSnapshotFenced(
		leasedB,
		{ DataVersion = currentVersion, Coins = 77 },
		fenceB,
		leasedB.SessionLease.ExpiresAt - 1,
		currentVersion,
		3
	)
	assert(
		fencedMerged
			and fencedMergeState == "Current"
			and fencedMerged.Coins == 77
			and fencedMerged.ProfileRevision == fenceB.Revision,
		"current fencing revision could not merge"
	)
	local fencedReceipt, fencedReceiptEntry, fencedReceiptGranted =
		ProfilePersistence.CommitReceiptFenced(
			fencedMerged,
			{ DataVersion = currentVersion, Coins = 77 },
			false,
			"fenced-receipt",
			801,
			{ coins = 5 },
			"fenced-grant-token",
			1200,
			fenceB,
			fencedMerged.SessionLease.ExpiresAt - 1,
			currentVersion,
			3
		)
	assert(
		fencedReceipt
			and fencedReceiptEntry
			and fencedReceiptGranted
			and fencedReceipt.Coins == 82
			and fencedReceipt.ProfileRevision == fenceB.Revision
			and fencedReceipt.SessionLease.Token == fenceB.Token,
		"fenced receipt commit failed"
	)
	local staleReceipt, _, staleReceiptGranted, staleReceiptError =
		ProfilePersistence.CommitReceiptFenced(
			fencedReceipt,
			{ DataVersion = currentVersion, Coins = 82 },
			true,
			"stale-fenced-receipt",
			802,
			{ coins = 5 },
			"stale-fenced-token",
			1201,
			fenceA,
			fencedReceipt.SessionLease.ExpiresAt - 1,
			currentVersion,
			3
		)
	assert(
		staleReceipt == nil
			and not staleReceiptGranted
			and staleReceiptError == "stale_session_fence",
		"stale fencing revision was allowed to commit a receipt"
	)
	local staleRelease, staleReleased, staleReleaseError =
		ProfilePersistence.ReleaseSessionLease(
			fencedReceipt,
			fenceA,
			fencedReceipt.SessionLease.ExpiresAt,
			currentVersion,
			3
		)
	assert(
		staleRelease == nil
			and not staleReleased
			and staleReleaseError == "stale_session_fence",
		"stale fencing revision was allowed to release a lease"
	)
	local releasedProfile, released, releaseError =
		ProfilePersistence.ReleaseSessionLease(
			fencedReceipt,
			fenceB,
			fencedReceipt.SessionLease.ExpiresAt,
			currentVersion,
			3
		)
	assert(
		releasedProfile
			and released
			and releaseError == nil
			and releasedProfile.SessionLease == nil
			and releasedProfile.ProfileRevision == fenceB.Revision,
		"current fencing revision could not release its lease"
	)
	return {
		ok = true,
		version = ProfilePersistence.ContractVersion,
		dataVersion = currentVersion,
		maxReceiptLedgerEntries = ProfilePersistence.MaxReceiptLedgerEntries,
		maxSeenReceiptIds = ProfilePersistence.MaxSeenReceiptIds,
		numberFieldCount = 30,
		textFieldCount = 14,
		maxSessionLeaseSeconds = ProfilePersistence.MaxSessionLeaseSeconds,
	}
end

return ProfilePersistence
