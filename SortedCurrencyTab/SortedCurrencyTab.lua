-- Saved Variabled
SortedCurrencyTabData = SortedCurrencyTabData or {}
SortedCurrencyTabData["order"] = SortedCurrencyTabData["order"] or {}
SortedCurrencyTabData["collapsed"] = SortedCurrencyTabData["collapsed"] or {}

-- -- store original WoW API
-- local oldGetCurrencyListInfo = C_CurrencyInfo.GetCurrencyListInfo
-- local oldExpandCurrencyList = C_CurrencyInfo.ExpandCurrencyList
-- local oldGetCurrencyListLink = C_CurrencyInfo.GetCurrencyListLink -- does not exist in 3.3.5
-- local oldSetCurrencyUnused = C_CurrencyInfo.SetCurrencyUnused
-- local oldSetCurrencyBackpack = C_CurrencyInfo.SetCurrencyBackpack
-- local oldGameTooltipSetCurrencyToken = GameTooltip.SetCurrencyToken
-- local oldTokenFrameUpdate = TokenFrame_Update

-- https://wowwiki-archive.fandom.com/wiki/Widget_API?oldid=2263587
-- https://wowwiki-archive.fandom.com/wiki/World_of_Warcraft_API?oldid=2308628
local oldGetCurrencyListInfo         = GetCurrencyListInfo 	-- GetCurrencyListInfo(index) - return information about an element in the currency list.
local oldExpandCurrencyList          = ExpandCurrencyList 	-- ExpandCurrencyList(index, state) - sets the expanded/collapsed state of a currency list header.
local oldSetCurrencyUnused           = SetCurrencyUnused 	-- SetCurrencyUnused(id, state) - alters whether a currency is marked as unused.
local oldSetCurrencyBackpack         = SetCurrencyBackpack 	-- SetCurrencyBackpack(id, state) - alters whether a currency is tracked.
local oldGameTooltipSetCurrencyToken = SetCurrencyToken 	-- SetCurrencyToken(tokenId) - Shows the tooltip for the specified token
local oldTokenFrameUpdate            = TokenFrame_Update

local pastelColors = {  "|cFFFF8080", "|cFF80FF80", "|cFF8080FF", "|cFFFFFF80", "|cFFFF80FF", "|cFF8080FF",
						"|cFFFF4040", "|cFF40FF40", "|cFF4040FF", "|cFFFFFF40", "|cFFFF40FF", "|cFF4040FF",
						"|cFFFFC0C0", "|cFFC0FFC0", "|cFFC0C0FF", "|cFFFFFFC0", "|cFFFFC0FF", "|cFFC0C0FF",
						}
local oldPrint = print
local print = function(...) 
	local line = strjoin("; ", tostringall(...) )
	oldPrint(pastelColors[(strlen(line) % #pastelColors) + 1] .. "-- SCT:|r", line)
end

local sct_data = {}
local sct_jagged = {}
local sct_headers = {}

local indexOf = function(table, value)
	for i=1,#table do
		if table[i] == value then
			return i
		end
	end

	return nil
end

local SortLists = function(jaggedList, currentOrder, desiredOrder)
	local curIndex = 0
	for i=1,#desiredOrder do
		local nextCategory = desiredOrder[i]
		local index = indexOf(currentOrder, nextCategory)
		if index then
			curIndex = curIndex + 1
			tremove(currentOrder, index)
			tinsert(currentOrder, curIndex, nextCategory)

			local data = jaggedList[index]
			tremove(jaggedList, index)
			tinsert(jaggedList, curIndex, data)
		end
	end
end

local FlattenList = function(jaggedList, flatList)
	flatList = flatList and type(flatList) == "table" and wipe(flatList) or {}

	for i=1,#jaggedList do
		for j=1,#jaggedList[i] do
			tinsert(flatList, jaggedList[i][j])
		end
	end

	return flatList
end

local InitList = function(self)
	-- print("CALLED InitList")
	wipe(sct_headers)
	wipe(sct_jagged)
	wipe(sct_data)

	local curIndex = 0
	for i=1,GetCurrencyListSize() do
		-- GetCurrencyListInfo
		-- name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon, itemID
		local result = {GetCurrencyListInfo(i)}

		-- if result.isHeader then
		if result[2] then
			curIndex = curIndex + 1

			tinsert(sct_headers, result[1])
			tinsert(sct_jagged, {i})

			if not tContains(SortedCurrencyTabData["order"], result[1]) then
				tinsert(SortedCurrencyTabData["order"], result[1]) -- add newly discovered currency categories to the bottom
				SortedCurrencyTabData["collapsed"][result[1]] = not result[3] or nil -- store proper collapsed state
			end
		else
			tinsert(sct_jagged[curIndex], i)
		end
	end

	SortLists(sct_jagged, sct_headers, SortedCurrencyTabData["order"])

	FlattenList(sct_jagged, sct_data)
end

SortedCurrencyTab_MoveUp = function(name)
	-- print("CALLED SortedCurrencyTab_MoveUp", name)
	local activeIndex = indexOf(sct_headers, name)
	local storageIndex = indexOf(SortedCurrencyTabData["order"], name)

	if not activeIndex or not storageIndex or activeIndex == 1 then
		return
	end

	local offset = 1
	while SortedCurrencyTabData["order"][storageIndex-offset] and not tContains(sct_headers, SortedCurrencyTabData["order"][storageIndex-offset]) do
		offset = offset + 1
	end

	tremove(SortedCurrencyTabData["order"], storageIndex)
	tinsert(SortedCurrencyTabData["order"], storageIndex-offset, name)

	TokenFrame_Update()
end

SortedCurrencyTab_MoveDown = function(name)
	-- print("CALLED SortedCurrencyTab_MoveDown", name)
	local activeIndex = indexOf(sct_headers, name)
	local storageIndex = indexOf(SortedCurrencyTabData["order"], name)

	if not activeIndex or not storageIndex or activeIndex == #sct_headers then
		return
	end

	local offset = 1
	while SortedCurrencyTabData["order"][storageIndex+offset] and not tContains(sct_headers, SortedCurrencyTabData["order"][storageIndex+offset]) do
		offset = offset + 1
	end

	tremove(SortedCurrencyTabData["order"], storageIndex)
	tinsert(SortedCurrencyTabData["order"], storageIndex+offset, name)

	TokenFrame_Update()
end

local CreateArrows = function()
	-- print("CALLED CreateArrows")
	if (not TokenFrameContainer.buttons) then
		-- print("returned CreateArrows")
		return;
	end

	local scrollFrame = TokenFrameContainer
	-- print("scrollFrame",scrollFrame)
	local offset = HybridScrollFrame_GetOffset(scrollFrame)
	-- print("offset",offset)
	local buttons = scrollFrame.buttons
	-- print("buttons",buttons)
	local numButtons = #buttons
	-- print("numButtons",numButtons)
	local button, index;
	for i=1, numButtons do
		button = buttons[i];

		button.highlight:SetAlpha(0.5) -- lessen the highlight effect, making the buttons more visible

		if not button.sctMoveUp then
			local b = CreateFrame("Button", nil, button)
			button.sctMoveUp = b
			b:SetPoint("TOPRIGHT", -20, -0.5)
			b:SetSize(16, 8)
			b:Hide()

			local t = b:CreateTexture(nil, "BACKGROUND")
			-- t:SetTexture("Interface\\PaperDollInfoFrame\\StatSortArrows.blp")
			t:SetTexture("Interface\\TALENTFRAME\\UI-TalentArrows.blp")
			t:SetAlpha(0.6)
			-- t:SetTexCoord(0, 1, 0, 0.5)
			t:SetTexCoord(0, 0.5, 0.375, 0.125)
			t:SetAllPoints()
			b.texture = t

			b:SetScript("OnEnter", function(self)
				self:Show()
				self.texture:SetAlpha(1)
				self:GetParent().sctMoveDown:Show()
			end)

			b:SetScript("OnLeave", function(self)
				self.texture:SetAlpha(0.6);
				if not self:GetParent():IsMouseOver() then
					self:Hide();
					self:GetParent().sctMoveDown:Hide();
				end
			end)

			b:SetScript("OnClick", function(self)
				-- SortedCurrencyTab_MoveUp(self:GetParent().name:GetText())
				SortedCurrencyTab_MoveUp(self:GetParent():GetText())
			end)
		end

		if not button.sctMoveDown then
			local b = CreateFrame("Button", nil, button)
			button.sctMoveDown = b
			b:SetPoint("TOPLEFT", button.sctMoveUp, "BOTTOMLEFT")
			b:SetSize(16, 8)
			b:Hide()

			local t = b:CreateTexture(nil, "BACKGROUND")
			-- t:SetTexture("Interface\\PaperDollInfoFrame\\StatSortArrows.blp")
			t:SetTexture("Interface\\TALENTFRAME\\UI-TalentArrows.blp")
			t:SetAlpha(0.6)
			t:SetTexCoord(0, 0.5, 0.125, 0.375)
			t:SetAllPoints()
			b.texture = t

			b:SetScript("OnEnter", function(self)
				self:Show()
				self.texture:SetAlpha(1)
				self:GetParent().sctMoveUp:Show()
			end)

			b:SetScript("OnLeave", function(self)
				self.texture:SetAlpha(0.6);
				if not self:GetParent():IsMouseOver() then
					self:Hide();
					self:GetParent().sctMoveUp:Hide();
				end
			end)

			b:SetScript("OnClick", function(self)
				-- SortedCurrencyTab_MoveDown(self:GetParent().name:GetText())
				SortedCurrencyTab_MoveDown(self:GetParent():GetText())
			end)
		end

		if not button.scriptsChanged then
			button.scriptsChanged = true

			button.oldOnEnter = button:GetScript("OnEnter")

			button:SetScript("OnEnter", function(self, ...)
				if self.isHeader then
					self.sctMoveUp:Show()
					self.sctMoveDown:Show()
				end
				if self.oldOnEnter then
					self.oldOnEnter(self, ...)
				end
			end)

			button.oldOnLeave = button:GetScript("OnLeave")

			button:SetScript("OnLeave", function(self, ...)
				if self.isHeader then
					self.sctMoveUp:Hide()
					self.sctMoveDown:Hide()
				end
				if self.oldOnLeave then
					self.oldOnLeave(self, ...)
				end
			end)
		end
		
		if not button.isHeader then
			button.sctMoveUp:Hide()
			button.sctMoveDown:Hide()
		end
	end
end

GetCurrencyListInfo = function(index)
	-- print("CALLED GetCurrencyListInfo")
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldGetCurrencyListInfo(index) -- just pass their index
	end

	return oldGetCurrencyListInfo(sct_data[index])
end

ExpandCurrencyList = function(index, value)
	-- print("CALLED ExpandCurrencyList")
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldExpandCurrencyList(index, value) -- just pass their index
	end
	
	-- local name = GetCurrencyListInfo(index).name
	local name = GetCurrencyListInfo(index)
	local collapsed = not value
	SortedCurrencyTabData["collapsed"][name] = collapsed or nil -- remove on true (nil it out), rather than keep it around

	local returnValues = { oldExpandCurrencyList(sct_data[index], value) }

	InitList()

	return unpack(returnValues)
end

-- does not exist in 3.3.5
--[[ C_CurrencyInfo.GetCurrencyListLink = function(index)
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldGetCurrencyListLink(index) -- just pass their index
	end

	return oldGetCurrencyListLink(sct_data[index])
end ]]--

SetCurrencyUnused = function(index, value)
	-- print("CALLED SetCurrencyUnused")
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldSetCurrencyUnused(index, value) -- just pass their index
	end
	local returnValues = { oldSetCurrencyUnused(sct_data[index], value) }

	InitList()

	return unpack(returnValues)
end

SetCurrencyBackpack = function(index, value)
	-- print("CALLED SetCurrencyBackpack")
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldSetCurrencyBackpack(index, value) -- just pass their index
	end

	return oldSetCurrencyBackpack(sct_data[index], value)
end

SetCurrencyToken = function(self, index)
	-- print("CALLED SetCurrencyToken")
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldGameTooltipSetCurrencyToken(GameTooltip, index) -- just pass their index
	end

	return oldGameTooltipSetCurrencyToken(GameTooltip, sct_data[index])
end

TokenFrame_Update = function()
	-- print("CALLED TokenFrame_Update")
	InitList()
	oldTokenFrameUpdate()
	CreateArrows()
end
TokenFrameContainer.update = TokenFrame_Update -- Need to set this, as it was keeping a reference to the original function

local UnusedHidingFrame = CreateFrame("Frame")
UnusedHidingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
UnusedHidingFrame:SetScript("OnEvent", function()
	for i=1,GetCurrencyListSize() do
		-- local result = GetCurrencyListInfo(i)
		local result = {GetCurrencyListInfo(i)}
		if result and SortedCurrencyTabData["collapsed"][result[1]] and result[3] then
			ExpandCurrencyList(i, false)
		end
	end
end)

SLASH_SORTEDCURRENCYTAB1 = "/sortcurrencytab"
SLASH_SORTEDCURRENCYTAB2 = "/sortcurtab"
SLASH_SORTEDCURRENCYTAB3 = "/sortcurrency"
SlashCmdList["SORTEDCURRENCYTAB"] = function ()
	wipe(SortedCurrencyTabData["order"]) -- clear current order

	if TokenFrame:IsVisible() then
		TokenFrame_Update() -- calls InitList and updates the frame (redrawing currencies in original order)
	else
		InitList() -- generates order for current currencies (likely gets called again before they are shown, but this makes sure it is ready)
	end
end