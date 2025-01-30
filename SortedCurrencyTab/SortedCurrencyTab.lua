--[[

	Sorted Currency Tab - version 2.2 (10/10/20)
	Kirsia - Dalaran (US)

	Change Log
	==========
	2.2		- Updated for Shadowlands compatibility

	2.1		- Corrected sorting arrows not disappearing when you used the mouse wheel to scroll the currency frame
			- Added command to reset sort order to default (current categories are sorted in the game's default order [alphabetically]; new ones will still be added to the bottom)
			-- Use /sortcurrencytab, /sortcurtab, or /sortcurrency

	2.0		- Added way for users to customize order (up/down arrows on category headers)
			- As the order is now customizable, Warlords of Draenor and Dungeon & Raid categories are no longer sorted to the top and bottom, respectively, by default.
			- Localization should be a non-issue, as the addon will sort and organize using the localized names returned in-game (localization.lua removed).
			- Collapsed status of the categories is now remembered between sessions

	1.2a		- Removed an extraneous print() (debug) statement

	1.2		- Added localization support (full support for deDE, esMX, ptBR; possibly also esES, frFR, and itIT)
			- Defaulted search for WoD currency header to Blizzard-provided constant (theoretically adds partial support for all localizations)

	1.1		- Fixed issue where new currencies would not display on currency tab
			- Made data variable local (was global for testing and forgot to set it back)

	1.0		- Initial Release
	==========

]]--

SortedCurrencyTabData = SortedCurrencyTabData or {}
SortedCurrencyTabData["order"] = SortedCurrencyTabData["order"] or {}
SortedCurrencyTabData["collapsed"] = SortedCurrencyTabData["collapsed"] or {}

local oldGetCurrencyListInfo = C_CurrencyInfo.GetCurrencyListInfo
local oldExpandCurrencyList = C_CurrencyInfo.ExpandCurrencyList
local oldGetCurrencyListLink = C_CurrencyInfo.GetCurrencyListLink
local oldSetCurrencyUnused = C_CurrencyInfo.SetCurrencyUnused
local oldSetCurrencyBackpack = C_CurrencyInfo.SetCurrencyBackpack
local oldGameTooltipSetCurrencyToken = GameTooltip.SetCurrencyToken
local oldTokenFrameUpdate = TokenFrame_Update

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
	wipe(sct_headers)
	wipe(sct_jagged)
	wipe(sct_data)

	local curIndex = 0
	for i=1,C_CurrencyInfo.GetCurrencyListSize() do
		local result = C_CurrencyInfo.GetCurrencyListInfo(i)

		if result.isHeader then
			curIndex = curIndex + 1

			tinsert(sct_headers, result.name)
			tinsert(sct_jagged, {i})

			if not tContains(SortedCurrencyTabData["order"], result.name) then
				tinsert(SortedCurrencyTabData["order"], result.name) -- add newly discovered currency categories to the bottom
				SortedCurrencyTabData["collapsed"][result.name] = not result.isHeaderExpanded or nil -- store proper collapsed state
			end
		else
			tinsert(sct_jagged[curIndex], i)
		end
	end

	SortLists(sct_jagged, sct_headers, SortedCurrencyTabData["order"])

	FlattenList(sct_jagged, sct_data)
end

SortedCurrencyTab_MoveUp = function(name)
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
	if (not TokenFrameContainer.buttons) then
		return;
	end

	local scrollFrame = TokenFrameContainer
	local offset = HybridScrollFrame_GetOffset(scrollFrame)
	local buttons = scrollFrame.buttons
	local numButtons = #buttons
	local button, index;
	for i=1, numButtons do
		button = buttons[i];

		button.highlight:SetAlpha(0.5) -- lessen the highlight effect, making the buttons more visible

		if not button.sctMoveUp then
			local b = CreateFrame("Button", nil, button)
			button.sctMoveUp = b
			b:SetPoint("TOPRIGHT", -1, -0.5)
			b:SetSize(16, 8)
			b:Hide()

			local t = b:CreateTexture(nil, "BACKGROUND")
			t:SetTexture("Interface\\PaperDollInfoFrame\\StatSortArrows.blp")
			t:SetAlpha(0.6)
			t:SetTexCoord(0, 1, 0, 0.5)
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
				SortedCurrencyTab_MoveUp(self:GetParent().name:GetText())
			end)
		end

		if not button.sctMoveDown then
			local b = CreateFrame("Button", nil, button)
			button.sctMoveDown = b
			b:SetPoint("TOPLEFT", button.sctMoveUp, "BOTTOMLEFT")
			b:SetSize(16, 8)
			b:Hide()

			local t = b:CreateTexture(nil, "BACKGROUND")
			t:SetTexture("Interface\\PaperDollInfoFrame\\StatSortArrows.blp")
			t:SetAlpha(0.6)
			t:SetTexCoord(0, 1, 0.5, 1)
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
				SortedCurrencyTab_MoveDown(self:GetParent().name:GetText())
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

C_CurrencyInfo.GetCurrencyListInfo = function(index)
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldGetCurrencyListInfo(index) -- just pass their index
	end

	return oldGetCurrencyListInfo(sct_data[index])
end

C_CurrencyInfo.ExpandCurrencyList = function(index, value)
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldExpandCurrencyList(index, value) -- just pass their index
	end

	local name = C_CurrencyInfo.GetCurrencyListInfo(index).name
	local collapsed = not value
	SortedCurrencyTabData["collapsed"][name] = collapsed or nil -- remove on true (nil it out), rather than keep it around

	local returnValues = { oldExpandCurrencyList(sct_data[index], value) }

	InitList()

	return unpack(returnValues)
end

C_CurrencyInfo.GetCurrencyListLink = function(index)
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldGetCurrencyListLink(index) -- just pass their index
	end

	return oldGetCurrencyListLink(sct_data[index])
end

C_CurrencyInfo.SetCurrencyUnused = function(index, value)
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldSetCurrencyUnused(index, value) -- just pass their index
	end
	local returnValues = { oldSetCurrencyUnused(sct_data[index], value) }

	InitList()

	return unpack(returnValues)
end

C_CurrencyInfo.SetCurrencyBackpack = function(index, value)
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldSetCurrencyBackpack(index, value) -- just pass their index
	end

	return oldSetCurrencyBackpack(sct_data[index], value)
end

GameTooltip.SetCurrencyToken = function(self, index)
	if index < 1 then
		return nil
	elseif index > #sct_data then
		return oldGameTooltipSetCurrencyToken(GameTooltip, index) -- just pass their index
	end

	return oldGameTooltipSetCurrencyToken(GameTooltip, sct_data[index])
end

TokenFrame_Update = function()
	InitList()
	oldTokenFrameUpdate()
	CreateArrows()
end
TokenFrameContainer.update = TokenFrame_Update -- Need to set this, as it was keeping a reference to the original function

local UnusedHidingFrame = CreateFrame("Frame")
UnusedHidingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
UnusedHidingFrame:SetScript("OnEvent", function()
	for i=1,C_CurrencyInfo.GetCurrencyListSize() do
		local result = C_CurrencyInfo.GetCurrencyListInfo(i)
		if result and SortedCurrencyTabData["collapsed"][result.name] and result.isHeaderExpanded then
			C_CurrencyInfo.ExpandCurrencyList(i, false)
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