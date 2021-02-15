local meta = FindMetaTable("Player")
local _Global_Teams = Global_Teams

local SteamIDs = {}
_G.nGSteamIDs = {}

local function LoadUsers()
	local txt = file.Read("nadmin/users.txt", "DATA")
	if ( !txt ) then
		MsgN( "nadmin/users.txt не обнаружен! Создаём..." )
		file.Write("nadmin/users.txt")
		return
	end
	if txt == "" then
		txt = "{}"
	end
	for steamid, v in next, util.JSONToTable(txt) do
		SteamIDs[steamid] = {}
		SteamIDs[steamid].group = v.group
	end
	nGSteamIDs = SteamIDs
end

LoadUsers()
if not file.Exists("nadmin", "DATA") then
	file.CreateDir("nadmin")
end

function meta:SetUserGroup(group)
	self:SetNWString("usergroup", group)
	timer.Simple(0, function()
		self:SetTeam(_Global_Teams[group].num)
	end)
	local stid = self:SteamID():lower()
	if (group ~= "user" and SteamIDs[stid] == nil) or (SteamIDs[stid] and SteamIDs[stid].group ~= group) then
		SteamIDs[stid] = {}
		SteamIDs[stid].group = group
		file.Write("nadmin/users.txt", util.TableToJSON(SteamIDs))
	end
end

function SetUserGroupID(stid, group)
	SteamIDs[stid] = {}
	if _Global_Teams[group] == nil then
		SteamIDs[stid].group = nil
		goto skip
	end
	SteamIDs[stid].group = tostring(group:Trim())
	::skip::
	file.Write("nadmin/users.txt", util.TableToJSON(SteamIDs))
end

hook.Add("PlayerInitialSpawn", "PlayerAuthSpawn", function(ply)
	local steamid = ply:SteamID():lower()
	if (game.SinglePlayer() or ply:IsListenServerHost()) then
		ply:SetUserGroup("superadmin")
		return
	end
	if (SteamIDs[steamid] == nil) then
		ply:SetUserGroup("user")
		return
	end
	ply:SetUserGroup(SteamIDs[steamid].group)
end)