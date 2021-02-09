local limits = nAdmin.Limits
local p = p
local tostring = tostring

if not limits then return end
hook.Add("PlayerCheckLimit", "limits", function(pl, limit, cur, dMax)
	local a = limits[pl:GetUserGroup()]
	if a and a[limit] then
		if cur >= a[limit] then
			return false
		end
	end
end)

local alllogs = {
	"Prop",
	"Ragdoll",
	"SENT",
	"Effect"
}

for i = 1, #alllogs do
	local _log = alllogs[i]
	local tostring = tostring
	hook.Add("PlayerSpawned" .. _log, "nAdminLog", function(a, b)
		p(a:Name() .. " заспавнил: " .. tostring(b))
	end)
end

hook.Add("CanTool", "nAdminLog", function(a, _, b)
	p(a:Name() .. " использовал инструмент: " .. tostring(b))
end)