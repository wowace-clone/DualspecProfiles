local name, ns = ...
local mod = LibStub("AceAddon-3.0"):NewAddon(name, "AceEvent-3.0")

local db
local defaults = {
	profile = {
		addons = {
			["*"] = {},
		},
	},
}

function mod:OnInitialize()
	db = LibStub("AceDB-3.0"):New("DualspecProfilesDB", defaults)
	self:RegisterEvent("PLAYER_LOGIN")
end

function mod:OnEnable()
	self:MakeOptions()
	self:RegisterEvent("PLAYER_TALENT_UPDATE")
	self:PLAYER_TALENT_UPDATE();
end

local ace3dbs = {}
local ace2dbs = {}

local function switchAce3Profile(addon, supposed)
	if not supposed then return end
	local addondb = ace3dbs[addon]
	if not addondb then return end
	if addondb:GetCurrentProfile() ~= supposed then
		addondb:SetProfile(supposed)
	end
	return true
end

local function switchAce2Profile(addon, supposed)
	if not supposed then return end
	local object = ace2dbs[addon]
	if not object or not object.db then return end
	if object:GetProfile() ~= supposed then
		object:SetProfile(supposed)
	end
	return true
end

function mod:PLAYER_TALENT_UPDATE()
	local current_talents = GetActiveSpecGroup()
	for k,v in pairs(db.profile.addons) do
		if v.enabled then
			local supposed = v[current_talents]
			switchAce3Profile(k, supposed)
			switchAce2Profile(k, supposed)
		end
	end
end

-- options
local options = {
	name = name,
	desc = name,
	type = 'group',
	args = {},
}

local choices_cache = {}

local function getAce3ProfileChoices(info)
	local addon = info.arg
	local choices = {}
	for _, v in pairs(ace3dbs[addon]:GetProfiles()) do
		choices[v] = v
	end
	return choices
end

local function getAce2Profiles(db)
	local t = {}
	if db and db.raw then
		if db.raw.profiles then
			for k in pairs(db.raw.profiles) do
				t[k] = k
			end
		end
		if db.raw.namespaces then
			for _,n in pairs(db.raw.namespaces) do
				if n.profiles then
					for k in pairs(n.profiles) do
						if not k:find("^char/") and not k:find("^realm/") and not k:find("^class/") then
							t[k] = k
						end
					end
				end
			end
		end
	end
	return t
end

local function getAce2ProfileChoices(info)
	local addon = info.arg
	local choices = {}
	return getAce2Profiles(ace2dbs[addon])
end

local function getEnabled(info)
	return db.profile.addons[info.arg].enabled
end

local function getDisabled(info)
	return not getEnabled(info)
end

local function setEnabled(info, value)
	db.profile.addons[info.arg].enabled = value
end

local function getPrimary(info)
	return db.profile.addons[info.arg][1]
end

local function setPrimary(info, value)
	db.profile.addons[info.arg][1] = value
end

local function getSecondary(info)
	return db.profile.addons[info.arg][2]
end

local function setSecondary(info, value)
	db.profile.addons[info.arg][2] = value
end

local function makeAddonOption(addon, dbtype)
	local getProfileChoices
	if dbtype == "ace3" then
		getProfileChoices = getAce3ProfileChoices
	elseif dbtype == "ace2" then
		getProfileChoices = getAce2ProfileChoices
	end

	local opt = {
		name = addon,
		desc = addon,
		type = 'group',
		args = {
			enabled = {
				name = "Enabled",
				desc = "Enable dualspec profile changing",
				type = 'toggle',
				get = getEnabled,
				set = setEnabled,
				arg = addon,
			},
			primary = {
				name = "Primary",
				desc = "Profile for Primary Talent spec",
				type = 'select',
				values = getProfileChoices,
				get = getPrimary,
				set = setPrimary,
				disabled = getDisabled,
				arg = addon,
			},
			secondary = {
				name = "Secondary",
				desc = "Profile for Secondary Talent spec",
				type = 'select',
				values = getProfileChoices,
				get = getSecondary,
				set = setSecondary,
				disabled = getDisabled,
				arg = addon,
			},
		},
	}
	options.args[addon] = opt
end

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function mod:MakeOptions()
	AceConfig:RegisterOptionsTable(name, options)
	AceConfigDialog:AddToBlizOptions(name, name)
end

function mod:ADDON_LOADED(_, addonname)
	self:FindAce3Addon(addonname)
	self:FindAce2Addon(addonname)
end

local aceAddon3 = LibStub("AceAddon-3.0")
local aceDB3 = LibStub("AceDB-3.0")
function mod:FindAce3Addon(addonname)
	local object = aceAddon3:GetAddon(addonname, true)
	if not object then return end
	if object:IsModule() then return end

	local objectdb = object.db
	if objectdb and aceDB3.db_registry[objectdb] then
		self:RegisterAce3Addon(addonname, objectdb)
	end
end
local AceLibrary = AceLibrary
if AceLibrary and AceLibrary:HasInstance("AceAddon-2.0") and AceLibrary:HasInstance("AceModuleCore-2.0") then
	local ace2 = AceLibrary("AceAddon-2.0")
	local ace2mod = AceLibrary("AceModuleCore-2.0")
	function mod:FindAce2Addon(addonname)
		local object = ace2.addons[addonname]
		if not object then return end
		if ace2mod:IsModule(object) then return end

		local objectdb = object.db
		self:RegisterAce2Addon(addonname, objectdb)
	end
else
	function mod:FindAce2Addon()
	end
end

function mod:PLAYER_LOGIN()
	for name, object in aceAddon3:IterateAddons() do
		self:FindAce3Addon(name)
	end
	if ace2 then
		for k, v in pairs(ace2.addons) do
			if not ace2mod:IsModule(v) and v.db and type(k) == 'string' then
				self:RegisterAce2Addon(k, v)
			end
		end
	end
	mod:RegisterEvent("ADDON_LOADED")
end

function mod:RegisterAce3Addon(name, db)
	ace3dbs[name] = db
	makeAddonOption(name, "ace3")
end

function mod:RegisterAce2Addon(name, db)
	ace2dbs[name] = db
	makeAddonOption(name, "ace2")
end
