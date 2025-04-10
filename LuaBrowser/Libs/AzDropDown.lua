--[[
	### Rev 04 ###
	- Dropdowns can now overwrite the label in their init and selectvalue funcs.
	- Empty menus now show "No items".
	### Rev 05 ###
	- A menu entry now supports a .tip key, and will show a tooltip if it's a string.
	- The SelectValueFunc() now has a third parameter, the menu item index that was clicked.
	- The checkmark texture is now the green one used for readychecks in the raid tab.
	- Will now obey the .checked key if set, not only when it's true.
	- The autoselect feature of the last selected value, will not just select everything when nil.
	- The InitSelectedItem() function will not ignore an initialisation with nil anymore.
	### Rev 06 ###
	- The "menu.list" table now has a meta table which will automatically create a table or take one from storage.
	- If tables are creates through the new metatable index method, it will recycle old tables from storage.
	### Rev 07 ###
	- The menu will now hide itself, if any of it's parents was hidden.
--]]

local REVISION = 7;
if (type(AzDropDown) == "table") and (AzDropDown.vers >= REVISION) then
	return;
end

AzDropDown = AzDropDown or {};
AzDropDown.vers = REVISION;

local menu;
local measure;
local menuMaxItems = 15;
local menuItemHeight = 14;
local backDrop = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 2.5, right = 2.5, top = 2.5, bottom = 2.5 } };
local storage = {};

--------------------------------------------------------------------------------------------------------
--                                          Menu Functions                                            --
--------------------------------------------------------------------------------------------------------

-- MenuItem OnClick
local function MenuItem_OnClick(self,button)
	local table = menu.list[this.index];
	local parent = menu.parent;
	if (parent.isAutoSelect) then
		parent.label:SetText(table.text);
		parent.SelectedValue = table.value;
	end
	menu.SelectValueFunc(parent,table,this.index);
	menu:Hide();
end

-- MenuItem OnEnter
local function MenuItem_OnEnter(self)
	local entry = menu.list[this.index];
	if (type(entry.tip) == "string") then
		GameTooltip_SetDefaultAnchor(GameTooltip,this);
		GameTooltip:AddLine(entry.text,1,1,1);
		GameTooltip:AddLine(entry.tip,nil,nil,nil,1);
		GameTooltip:Show();
	end
end

-- HideGTT
local function HideGTT()
	GameTooltip:Hide();
end

-- Make Menu Item
local function CreateMenuItem()
	local item = CreateFrame("Button",nil,menu);
	item:SetHeight(menuItemHeight);
	item:SetHitRectInsets(-12,-10,0,0);
	item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
	item:SetScript("OnClick",MenuItem_OnClick);
	item:SetScript("OnEnter",MenuItem_OnEnter);
	item:SetScript("OnLeave",HideGTT);

	item.text = item:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
	item.text:SetPoint("LEFT",2,0);

	item.check = item:CreateTexture(nil,"ARTWORK");
	item.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");--(READY_CHECK_READY_TEXTURE);
	item.check:SetWidth(14);
	item.check:SetHeight(14);
	item.check:SetPoint("RIGHT",item,"LEFT");
	item.check:Hide();

	if (getn(menu.items) == 0) then
		item:SetPoint("TOPLEFT",20,-8);
		menu.scroll:SetPoint("TOPLEFT",item);
	else
		item:SetPoint("TOPLEFT",menu.items[getn(menu.items)],"BOTTOMLEFT");
		item:SetPoint("TOPRIGHT",menu.items[getn(menu.items)],"BOTTOMRIGHT");
		menu.scroll:SetPoint("BOTTOMRIGHT",item);
	end

	menu.items[getn(menu.items) + 1] = item;
	return item;
end

-- UpdateList
local function Menu_UpdateList()
	FauxScrollFrame_Update(menu.scroll,getn(menu.list),menuMaxItems,menuItemHeight);
	local item, entry;
	local index = menu.scroll.offset;
	-- Loop
	for i = 1, menuMaxItems do
		index = (index + 1);
		item = menu.items[i] or CreateMenuItem();
		if (index <= getn(menu.list)) then
			entry = menu.list[index];
			item.text:SetText(entry.text);
			item.index = index;
			item.text:SetTextColor(1,entry.header and 0.82 or 1,entry.header and 0 or 1);
			if (entry.header) then
				item:Disable();
			else
				item:Enable();
			end
			if (entry.checked) or (entry.checked == nil and menu.parent.isAutoSelect and entry.value ~= nil and entry.value == menu.parent.SelectedValue) then
				item.check:Show();
			else
				item.check:Hide();
			end
			item:Show();
		else
			item:Hide();
		end
	end
end

-- Create Menu
local function CreateMenu()
	menu = CreateFrame("Frame",nil,nil);
	menu:SetBackdrop(backDrop);
	menu:SetBackdropColor(0.1,0.1,0.1,1);
	menu:SetBackdropBorderColor(0.4,0.4,0.4,1);
	menu:SetToplevel(1);
	menu:SetClampedToScreen(1);
	menu:SetFrameStrata("FULLSCREEN_DIALOG");
	menu:SetScript("OnHide",function(self) if (this:IsShown()) then this:Hide(); end end);
	menu:Hide();
	
	measure = menu:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
	measure:Hide();

	menu.scroll = CreateFrame("ScrollFrame","AzDropDownScroll"..REVISION,menu,"FauxScrollFrameTemplate");
	menu.scroll:SetScript("OnVerticalScroll",function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,menuItemHeight,Menu_UpdateList); end);

	menu.items = {};
	menu.list = setmetatable({},{ __index = function(t,k) t[k] = getn(storage) > 0 and tremove(storage,getn(storage)) or {}; return t[k]; end });
end

local function wipe(tbl)
	for k in pairs(tbl) do
		tbl[k] = nil;
	end
end

-- InitList
local function InitMenu(parent,initFunc,selectValueFunc,point,parentPoint)
	if (not initFunc) then
		return;
	end
	-- Set DropDown Parent
	menu.parent = parent;
	menu:SetParent(parent);
	-- Anchor to Parent
	menu:ClearAllPoints();
	menu:SetPoint(point or "TOPRIGHT",parent,parentPoint or "BOTTOMRIGHT");
	-- Clear Old List & Init the New
	for index, tbl in ipairs(menu.list) do
		wipe(tbl);
		storage[getn(storage) + 1] = tbl;
	end
	wipe(menu.list);
	menu.SelectValueFunc = selectValueFunc;
	menu.InitFunc = initFunc;
	initFunc(parent,menu.list);
	-- Show "No items" for empty lists & Update List
	if (getn(menu.list) == 0) then
		menu.list[1].text = "No items"; menu.list[1].header = 1;
	end
	Menu_UpdateList();
	-- Set Width
	local maxItemWidth = 0;
	for _, table in ipairs(menu.list) do
		measure:SetText(table.text);
		maxItemWidth = max(maxItemWidth,measure:GetWidth() + 10);
	end
	if (getn(menu.list) > menuMaxItems) then
		maxItemWidth = (maxItemWidth + 12);
		menu.items[1]:SetPoint("TOPRIGHT",-28,-8);
	else
		menu.items[1]:SetPoint("TOPRIGHT",-16,-8);
	end
	menu:SetWidth(maxItemWidth + 38);
	menu:SetHeight(min(getn(menu.list),menuMaxItems) * menuItemHeight + 16);
end

--------------------------------------------------------------------------------------------------------
--                                        Drop Down Functions                                         --
--------------------------------------------------------------------------------------------------------

-- DropDown OnClick
local function DropDown_OnClick(self,button)
	local parent = this:GetParent();
	AzDropDown.ToggleMenu(parent,parent.InitFunc,parent.SelectValueFunc);
end

-- Init Selected DropDown Item
local function DropDown_InitSelectedItem(self,selectedValue)
	if (not menu) then
		CreateMenu();
	end
	this.label:SetText("|cff00ff00Select Value...");
	InitMenu(self,this.InitFunc,this.SelectValueFunc);
	this.SelectedValue = selectedValue;
	for _, table in ipairs(menu.list) do
		if (table.value == this.SelectedValue) then
			this.label:SetText(table.text);
			return;
		end
	end
end

--------------------------------------------------------------------------------------------------------
--                                        "Exported" Functions                                        --
--------------------------------------------------------------------------------------------------------

-- ToggleMenu
function AzDropDown.HideMenu()
	if (menu) then
		menu:Hide();
	end
end

-- ToggleMenu
function AzDropDown.ToggleMenu(parent,initFunc,selectValueFunc,point,parentPoint)
	if (not parent or not initFunc or not selectValueFunc) then
		return;
	end
	if (not menu) then
		CreateMenu();
	end
	PlaySound("igMainMenuOptionCheckBoxOn");
	if (menu:IsShown()) and (menu.parent == parent) then
		menu:Hide();
	else
		InitMenu(parent,initFunc,selectValueFunc,point,parentPoint);
		menu:Show();
	end
end

-- Create DropDown
function AzDropDown.CreateDropDown(parent,width,isAutoSelect,initFunc,selectValueFunc)
	if (not parent or not width) then
		return;
	end
	local f = CreateFrame("Frame",nil,parent);
	f:SetWidth(width);
	f:SetHeight(24);
	f:SetBackdrop(backDrop);
	f:SetBackdropColor(0.1,0.1,0.1,1);
	f:SetBackdropBorderColor(0.4,0.4,0.4,1);

	f.button = CreateFrame("Button",nil,f);
	f.button:SetPoint("TOPRIGHT", f);
	f.button:SetPoint("BOTTOMRIGHT", f);
	f.button:SetWidth(24);
	f.button:SetHitRectInsets(-1 * (width - f.button:GetWidth()),0,0,0);
	f.button:SetScript("OnClick",DropDown_OnClick);

	f.button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up");
	f.button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down");
	f.button:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled");
	f.button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight");

	f.label = f:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
	f.label:SetPoint("RIGHT",f.button,"LEFT",-2,0);

	f.isAutoSelect = isAutoSelect;

	f.InitFunc = initFunc;
	f.SelectValueFunc = selectValueFunc;
	f.InitSelectedItem = DropDown_InitSelectedItem;
	return f;
end