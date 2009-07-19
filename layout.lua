--[[
            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                    Version 2, December 2004

 Copyright (C) 2009 Constantin Schomburg
 Everyone is permitted to copy and distribute verbatim or modified
 copies of this license document, and changing it is allowed as long
 as the name is changed.

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. You just DO WHAT THE FUCK YOU WANT TO.
]]

-- This function is only used inside the layout, so the cargBags-core doesn't care about it
-- It creates the border for glowing process in UpdateButton()
local createGlow = function(button)
	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture"Interface\\Buttons\\UI-ActionButton-Border"
	glow:SetBlendMode"ADD"
	glow:SetAlpha(.8)
	glow:SetWidth(70)
	glow:SetHeight(70)
	glow:SetPoint("CENTER", button)
	button.Glow = glow
end

-- The main function for updating an item button,
-- the item-table holds all data known about the item the button is holding, e.g.
--   bagID, slotID, texture, count, locked, quality - from GetContainerItemInfo()
--   link - well, from GetContainerItemLink() ofcourse ;)
--   name, link, rarity, level, minLevel, type, subType, stackCount, equipLoc - from GetItemInfo()
-- if you need cooldown item data, use self:RequestCooldownData()
local UpdateButton = function(self, button, item)
	button.Icon:SetTexture(item.texture)
	SetItemButtonCount(button, item.count)
	SetItemButtonDesaturated(button, item.locked, 0.5, 0.5, 0.5)

	-- Color the button's border based on the item's rarity / quality!
	if(item.rarity and item.rarity > 1) then
		if(not button.Glow) then createGlow(button) end
		button.Glow:SetVertexColor(GetItemQualityColor(item.rarity))
		button.Glow:Show()
	else
		if(button.Glow) then button.Glow:Hide() end
	end
end

-- Updates if the item is locked (currently moved by user)
--   bagID, slotID, texture, count, locked, quality - from GetContainerItemInfo()
-- if you need all item data, use self:RequestItemData()
local UpdateButtonLock = function(self, button, item)
	SetItemButtonDesaturated(button, item.locked, 0.5, 0.5, 0.5)
end

-- Updates the item's cooldown
--   cdStart, cdFinish, cdEnable - from GetContainerItemCooldown()
-- if you need all item data, use self:RequestItemData()
local UpdateButtonCooldown = function(self, button, item)
	if(button.Cooldown) then
		CooldownFrame_SetTimer(button.Cooldown, item.cdStart, item.cdFinish, item.cdEnable) 
	end
end

-- The function for positioning the item buttons in the bag object
local UpdateButtonPositions = function(self)
	local button
	local col, row = 0, 0
	for i, button in self:IterateButtons() do
		button:ClearAllPoints()

		local xPos = col * 38
		local yPos = -1 * row * 38
		if(self.Caption) then yPos = yPos - 20 end	-- Spacing for the caption

		button:SetPoint("TOPLEFT", self, "TOPLEFT", xPos, yPos)	 
		if(col >= self.Columns-1) then	 
			col = 0	 
			row = row + 1	 
		else	 
			col = col + 1	 
		end
	end

	-- This variable stores the size of the item button container
	self.ContainerHeight = (row + (col>0 and 1 or 0)) * 38

	if(self.UpdateDimensions) then self:UpdateDimensions() end -- Update the bag's height
end

-- Function is called after a button was added to an object
-- We color the borders of the button to see if it is an ammo bag or else
-- Please note that the buttons are in most cases recycled and not new created
local PostAddButton = function(self, button)
	if(not button.NormalTexture) then return end

	local bagType = cargBags.Bags[button.bagID].bagType
	if(button.bagID == KEYRING_CONTAINER) then
		button.NormalTexture:SetVertexColor(1, 0.7, 0)	-- Key ring
	elseif(bagType and bagType > 0 and bagType < 8) then
		button.NormalTexture:SetVertexColor(1, 1, 0)		-- Ammo bag
	elseif(bagType and bagType > 4) then
		button.NormalTexture:SetVertexColor(0, 1, 0)		-- Profession bags
	else
		button.NormalTexture:SetVertexColor(1, 1, 1)		-- Normal bags
	end
end

-- More slot buttons -> more space!
local UpdateDimensions = function(self)
	local height = 0			-- Normal margin space
	if(self.BagBar and self.BagBar:IsShown()) then
		height = height + 43				-- Bag button space
	end
	if(self.Space or self.Money) then
		height = height + 16	-- additional info display space
	end
	if(self.Caption) then	-- Space for captions
		height = height + 20
	end

	self:SetHeight(self.ContainerHeight + height)
end

-- Style of the bag and its contents
local func = function(settings, self)
	self:EnableMouse(true)

	self.UpdateDimensions = UpdateDimensions
	self.UpdateButtonPositions = UpdateButtonPositions
	self.UpdateButton = UpdateButton
	self.UpdateButtonLock = UpdateButtonLock
	self.UpdateButtonCooldown = UpdateButtonCooldown
	self.PostAddButton = PostAddButton
	
	self:SetFrameStrata("HIGH")
	tinsert(UISpecialFrames, self:GetName()) -- Close on "Esc"

	-- Make main frames movable
	if(self.Name == "cBags_Main" or self.Name == "cBags_Bank") then
		self:SetMovable(true)
		self:RegisterForClicks("LeftButton", "RightButton");
	    self:SetScript("OnMouseDown", function() 
	        if(IsAltKeyDown()) then 
	            self:ClearAllPoints() 
	            self:StartMoving() 
	        end 
	    end)
	    self:SetScript("OnMouseUp",  self.StopMovingOrSizing)
	end

	if(self.Name == "cBags_Keyring") then
		self.Columns = 2 -- 2 item button columns for the key ring
		self:SetScale(0.8)	-- Make key ring a bit smaller
	elseif(self.Name == "cBags_Bank") then
		self.Columns = 12 -- 12 columns for the bank as you can see
		self:SetScale(1)	-- Scale of the bank frame
	else
		self.Columns = 8
		self:SetScale(1)	-- Scale of the main bag frame
	end

	self.ContainerHeight = 0
	self:UpdateDimensions()
	self:SetWidth(38*self.Columns)	-- Set the frame's width based on the columns

	if(self.Name == "cBags_Main" or self.Name == "cBags_Bank") then

		-- Caption and close button
		local caption = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		if(caption) then
			local name = self.Name == "cb_bank" and "Bank" or "Inventory"
			caption:SetText(UnitName("player").."'s "..name)
			caption:SetPoint("TOPLEFT", 0, 0)
			self.Caption = caption

			local close = CreateFrame("Button", nil, self, "UIPanelCloseButton")
			close:SetPoint("TOPRIGHT", 5, 8)
			close:SetScript("OnClick", function(self) self:GetParent():Hide() end)
		end

		-- The frame for money display
		local money = self:SpawnPlugin("Money")
		if(money) then
			money:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
		end

		-- The font string for bag space display
		local bagType
		if(self.Name == "cBags_Main") then
			bagType = "bags"	-- We want to add all bags to our bag button bar
		else
			bagType = "bank"	-- the bank gets bank bags, of course
		end
		-- You can see, it works with tags, - [free], [max], [used] are currently supported
		local space = self:SpawnPlugin("Space", "[free] / [max] free", bagType)
		if(space) then
			space:SetPoint("BOTTOMLEFT", self, 0, 0)
			space:SetJustifyH"LEFT"
		end

		-- The button for viewing other characters' bags
		if(self.Name == "cBags_Main") then
			local anywhere = self:SpawnPlugin("Anywhere")
			if(anywhere) then
				anywhere:SetPoint("TOPRIGHT", -19, 4)
				anywhere:GetNormalTexture():SetDesaturated(1)
			end
		end

		 -- A nice bag bar for changing/toggling bags
		local bagType
		if(self.Name == "cBags_Main") then
			bagType = "bags"	-- We want to add all bags to our bag button bar
		else
			bagType = "bank"	-- the bank gets bank bags, of course
		end
		local bagButtons = self:SpawnPlugin("BagBar", bagType)
		if(bagButtons) then
			bagButtons:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 17)
			bagButtons:Hide()

			-- main window gets a fake bag button for toggling key ring
			if(self.Name == "cBags_Main") then
				local keytoggle = bagButtons:CreateKeyRingButton()
				keytoggle:SetScript("OnClick", function()
					if(cBags_Keyring:IsShown()) then
						cBags_Keyring:Hide()
						keytoggle:SetChecked(0)
					else
						cBags_Keyring:Show()
						keytoggle:SetChecked(1)
					end
				end)
			end
		end

		-- A little fix that positions the bagToggle between space and money
		local spacer = CreateFrame("Frame", nil, self)
		spacer:SetPoint("BOTTOMLEFT", space, "BOTTOMRIGHT", 0, 0)
		spacer:SetPoint("RIGHT", money, "LEFT", 0, 0)

		-- We don't need the bag bar every time, so let's create a toggle button for them to show
		local bagToggle = CreateFrame("CheckButton", nil, self)
		bagToggle:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		bagToggle:SetWidth(40)
		bagToggle:SetHeight(12)
		bagToggle:SetPoint("CENTER", spacer)
		bagToggle:RegisterForClicks("LeftButtonUp")
		bagToggle:SetScript("OnClick", function()
			if(self.BagBar:IsShown()) then
				self.BagBar:Hide()
			else
				self.BagBar:Show()
			end
			self:UpdateDimensions()	-- The bag buttons take space, so let's update the height of the frame
		end)
		local bagToggleText = bagToggle:CreateFontString(nil, "OVERLAY")
		bagToggleText:SetPoint("CENTER", bagToggle)
		bagToggleText:SetFontObject(GameFontNormalSmall)
		bagToggleText:SetText("Bags")

	end

	-- For purchasing bank slots
	if(self.Name == "cBags_Bank") then
		local purchase = self:SpawnPlugin("Purchase")
		if(purchase) then
			purchase:SetText(BANKSLOTPURCHASE)
			purchase:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 20)
			if(self.BagBar) then purchase:SetParent(self.BagBar) end

			purchase.Cost = self:SpawnPlugin("Money", "static")
			purchase.Cost:SetParent(purchase)
			purchase.Cost:SetPoint("BOTTOMRIGHT", purchase, "TOPRIGHT", 0, 2)
		end
	end

	-- And the frame background!
	local background = CreateFrame("Frame", nil, self)
	background:SetBackdrop{
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4},
	}
	background:SetFrameStrata("HIGH")
	background:SetFrameLevel(1)
	background:SetBackdropColor(0, 0, 0,   0.8)
	background:SetBackdropBorderColor(0, 0, 0,   0.5)

	background:SetPoint("TOPLEFT", -6, 6)
	background:SetPoint("BOTTOMRIGHT", 6, -6)

	return self
end

-- Register the style with cargBags
cargBags:RegisterStyle("Pernobilis", setmetatable({}, {__call = func}))

-- Filter functions
--   As you can see, these functions get the same item-table seen at the top in UpdateButton(self, button, item)
--   Just check the properties you want to have and return true/false if the item belongs in this bag object
local INVERTED = -1 -- with inverted filters (using -1), everything goes into this bag when the filter returns false

local onlyBags = function(item) return item.bagID >= 0 and item.bagID <= 4 end
local onlyKeyring = function(item) return item.bagID == -2 end
local onlyBank = function(item) return item.bagID == -1 or item.bagID >= 5 and item.bagID <= 11 end
-- local onlyRareEpics = function(item) return item.rarity and item.rarity > 3 end
local onlyEpics = function(item) return item.rarity and item.rarity > 3 end
local hideJunk = function(item) return not item.rarity or item.rarity > 0 end
local hideEmpty = function(item) return item.texture ~= nil end

-- Now we add the containers
--  cargBags:Spawn( name , parentFrame ) spawns the container with that name
--  object:SetFilter ( filterFunc, enabled ) adds a filter or disables one

-- Bagpack and bags
local main 	= cargBags:Spawn("cBags_Main")
	main:SetFilter(onlyBags, true)
	main:SetPoint("RIGHT", -5, 0)

-- Keyring
local key = cargBags:Spawn("cBags_Keyring", main)
	key:SetFilter(onlyKeyring, true)
	key:SetFilter(hideEmpty, true)
	key:SetPoint("TOPRIGHT", main, "TOPLEFT", -10, 0)

-- Bank frame and bank bags
local bank = cargBags:Spawn("cBags_Bank")
	bank:SetFilter(onlyBank, true)
	bank:SetPoint("LEFT", 5, 0)


-- Opening / Closing Functions
function OpenCargBags()
	main:Show()
end

function CloseCargBags()
	main:Hide()
	bank:Hide()
end

function ToggleCargBags(forceopen)
	if(main:IsShown() and not forceopen) then CloseCargBags() else OpenCargBags() end
end

-- To toggle containers when entering / leaving a bank
local bankToggle = CreateFrame"Frame"
bankToggle:RegisterEvent"BANKFRAME_OPENED"
bankToggle:RegisterEvent"BANKFRAME_CLOSED"
bankToggle:SetScript("OnEvent", function(self, event)
	if(event == "BANKFRAME_OPENED") then
		bank:Show()
	else
		bank:Hide()
	end
end)

-- Close real bank frame when our bank frame is hidden
bank:SetScript("OnHide", CloseBankFrame)

-- Hide the original bank frame
BankFrame:UnregisterAllEvents()

-- Blizzard Replacement Functions
ToggleBackpack = ToggleCargBags
ToggleBag = function() ToggleCargBags() end
OpenAllBags = ToggleBag
CloseAllBags = CloseCargBags
OpenBackpack = OpenCargBags
CloseBackpack = CloseCargBags

-- Set cargBags_Anywhere as default handler when used
if(cargBags.Handler["Anywhere"]) then
	cargBags:SetActiveHandler("Anywhere")
end