if not file.Exists("nadmin/bans.txt", "DATA") then
	nAdmin.Print("Файл \"nadmin/bans.txt\" не существует. Создаю...")
	file.Write("nadmin/bans.txt", "{}")
end
local bans = util.JSONToTable(file.Read("nadmin/bans.txt", "DATA") or "{}")
local next = next
nAdmin.BanList = bans

local singleplayer = game.SinglePlayer()
if singleplayer then
	nAdmin.Print("Модуль util отключен. Причина: сервер запущен в одиночной игре.")
	return
end

util.AddNetworkString("nAdmin_JailHUD")

function nAdmin.UpdateBans()
	local function write_bans()
		file.Write("nadmin/bans.txt", util.TableToJSON(bans))
		coroutine.yield()
	end
	local a = SysTime()
	local co = coroutine.create(write_bans)
	coroutine.resume(co)
end

function nAdmin.AddBan(ply_, minutes, reason, o, banid_) -- это уёбищный код, но так как я ленивая залупа я не хочу это переписывать
	local ply_Kick = nAdmin.FindByNick(ply_)
	local reason_warn = ""
	if banid_ then
		goto zcont
	end
	if ply_Kick == nil then
		nAdmin.Warn(o, "Игрока с таким именем нет на сервере!")
		return
	end
	if ply_Kick == o or o:SteamID() == ply_ then
		nAdmin.Warn(o, "Вы не можете забанить самого себя!")
		return
	end
	if ply_Kick:Team() <= o:Team() then
		nAdmin.Warn(o, "Вы не можете забанить игрока выше/равного по привилегии!")
		return
	end
	::zcont::
	if banid_ == true then
		ply_ = ply_:Trim()
		ply_ = ply_:lower()
		if not string.StartWith(ply_, "steam_0") then
			nAdmin.Warn(o, "Неправильно введён аргумент!")
			return
		end
		local a
		local b
		if o:SteamID() == "STEAM_0:0:0" then
			goto conskip
		end
		a = Global_Teams[nGSteamIDs[o:SteamID():lower()].group].num
		b = nGSteamIDs[ply_]
		if b == nil then
			b = Global_Teams["user"].num
			goto hui
		end
		b = (Global_Teams[nGSteamIDs[ply_]] and Global_Teams[nGSteamIDs[ply_]].num) or 12
		::hui::
		if a > b then
			nAdmin.Warn(o, "Вы не можете забанить данный SteamID, т.к. у него выше/равная привилегия.")
			return
		end
		::conskip::
		ply_Kick = ply_:lower()
	end
	local banM = os.time() + (tonumber(minutes) * 60)
	if tonumber(minutes) == 0 then
		banM = 0
	end
	local who_banned = o:Name()
	local time = (banM ~= 0 and (banM - os.time())) or 0
	local str = ""
	if time == 0 then
		str = "Бесконечно"
	else
		str = string.NiceTime(time)
	end
	if ply_Kick ~= false and not banid_ and ply_Kick:IsPlayer() then
		local stid = ply_Kick:SteamID():lower()
		bans[stid] = {time = banM, reason = reason}
		if discord then
			discord.send({embeds = {[1] = {author = {name = ply_Kick:Name() .. " (" .. ply_Kick:SteamID() .. ")", url = "http://steamcommunity.com/profiles/".. ply_Kick:SteamID64() .."/",}, title = "Опа! А вот и бан.", color = 10038562, description = "Был забанен по причине: " .. bans[stid].reason .. ", на: " .. str .. ", админом: " .. who_banned}}})
		end
		local msg = ply_Kick:Name() .. " был заблокирован с причиной: " .. bans[stid].reason .. "; на: " .. str .. "; забанил: " .. who_banned
		nAdmin.PrintAndWarn(msg)
		ply_Kick:Kick("Вы забанены. Причина: " .. bans[stid].reason .. "; время: " .. str)
		goto skipb
	end
	bans[ply_Kick] = {time = banM, reason = reason}
	nAdmin.PrintAndWarn(util.SteamIDTo64(ply_Kick) .. " был заблокирован с причиной: " .. bans[ply_Kick].reason .. "; на: " .. str .. "; забанил: " .. who_banned)
	game.KickID(ply_Kick:upper(), "Вы забанены. Причина: " .. bans[ply_Kick].reason .. "; время: " .. str)
	if discord then
		discord.send({embeds = {[1] = {author = {name = ply_Kick:upper(), url = "http://steamcommunity.com/profiles/".. util.SteamIDTo64(ply_Kick:upper()) .."/",}, title = "Опа! А вот и бан.", color = 10038562, description = "Был забанен по причине: " .. bans[ply_Kick].reason .. ", на: " .. str .. ", админом: " .. who_banned}}})
	end
	::skipb::
	nAdmin.UpdateBans()
	nAdmin.unbanUpdate()
end

local util_SteamIDFrom64 = util.SteamIDFrom64
hook.Add("CheckPassword", "ban_System", function(id)
	local a = util_SteamIDFrom64(id):lower()
	if bans[a] then
		local reas = bans[a].reason or ""
		nAdmin.Print(a .. " попытался зайти на сервер, но у него блокировка по причине: " .. reas)
		return false,
		"Вы забанены на [RU] Уютный Сандбокс. Причина: " .. reas .. "; время до разбана: " .. string.NiceTime(bans[a].time - os.time())
	end
end)

function nAdmin.unban(id)
	bans[id] = nil
	nAdmin.UpdateBans()
end

function nAdmin.unbanUpdate()
	if not timer.Exists("nAdmin_unbanUpdate") then
		timer.Create("nAdmin_unbanUpdate", 3600, 0, nAdmin.unbanUpdate)
	end
	for id, data in next, bans do
		if data.time ~= 0 then
			if data.time - os.time() < 3600 then
				if timer.Exists("nAdmin_banRemove_" .. id) then
					timer.Remove("nAdmin_banRemove_" .. id)
				end
				timer.Create("nAdmin_banRemove_" .. id, data.time - os.time(), 1, function()
					nAdmin.unban(id)
				end)
			end
		end
	end
end

hook.Add("InitPostEntity", "nAdmin_unbanUpdate", function()
	hook.Remove("InitPostEntity", "nAdmin_unbanUpdate")
	nAdmin.unbanUpdate()
	nAdmin.UpdateBans()
	nAdmin.Print("В базе данных насчитывается около: " .. table.Count(bans) .. " банов.")
end)

local curtime = CurTime()

nAdmin.AddCommand("ban", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 3, ply, "ban")
	if not check then
		return
	end
	if curtime > CurTime() then
		nAdmin.Warn(ply, "Подождите ещё " .. math.Round(curtime - CurTime()) .. " секунд.")
		return
	end
	curtime = CurTime() + 10
	local min_ = args[2]
	local m2 = tonumber(string.sub(min_, 1, #min_ - 1))
	if tonumber(min_) == 0 then
		m2 = min_
		goto skip
	end
	if string.EndsWith(min_, "m") then
		m2 = m2
	elseif string.EndsWith(min_, "h") then
		m2 = m2 * 60
	elseif string.EndsWith(min_, "d") then
		m2 = m2 * 60 * 24
	elseif string.EndsWith(min_, "w") then
		m2 = m2 * 60 * 24 * 7
	else
		nAdmin.Warn(ply, "Введите корректное значение 2 аргумента. (Пример: 7m, 7h, 7d, 7w)")
		return
	end
	::skip::
	nAdmin.AddBan(args[1], m2, args[3], ply)
end)
nAdmin.SetTAndDesc("ban", "moderator", "Банит игрока. arg1 - ник, arg2 - время [7m, 7h, 7d, 7w], arg3 - причина.")

nAdmin.AddCommand("banid", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 3, ply, "banid")
	if not check then
		return
	end
	if curtime > CurTime() then
		nAdmin.Warn(ply, "Подождите ещё " .. math.Round(curtime - CurTime()) .. " секунд.")
		return
	end
	curtime = CurTime() + 10
	local min_ = args[2]
	local m2 = tonumber(string.sub(min_, 1, #min_ - 1))
	if tonumber(min_) == 0 then
		m2 = min_
		goto skip
	end
	if string.EndsWith(min_, "m") then
		m2 = m2
	elseif string.EndsWith(min_, "h") then
		m2 = m2 * 60
	elseif string.EndsWith(min_, "d") then
		m2 = m2 * 60 * 24
	elseif string.EndsWith(min_, "w") then
		m2 = m2 * 60 * 24 * 7
	else
		nAdmin.Warn(ply, "Введите корректное значение 2 аргумента. (Пример: 7m, 7h, 7d, 7w)")
		return
	end
	::skip::
	nAdmin.AddBan(args[1], m2, args[3]:Trim(), ply, true)
end)
nAdmin.SetTAndDesc("banid", "vutka", "Банит игрока по SteamID. arg1 - SteamID, arg2 - время [7m, 7h, 7d, 7w], arg3 - причина.")

nAdmin.AddCommand("unban", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "unban")
	if not check then
		return
	end
	nAdmin.unban(args[1]:Trim())
	nAdmin.WarnAll(ply:Name().. " разблокировал: " .. tostring(args[1]))
end)
nAdmin.SetTAndDesc("unban", "moderator", "Разбанивает игрока. arg1 - SteamID игрока.")

nAdmin.AddCommand("bancount", true, function(ply, args)
	nAdmin.Warn(ply, "В базе данных насчитывается около: " .. table.Count(bans) .. " банов.")
end)
nAdmin.SetTAndDesc("bancount", "vutka", "Количество игроков в бане.")

nAdmin.AddCommand("kick", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "kick")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	local reason = args[2]
	if reason then
		pl:Kick("Вас кикнул " .. ply:Name() .. "; с причиной: " .. reason)
		return
	end
	pl:Kick("Вы были кикнуты админом: " .. ply:Name() .. ".")
end)
nAdmin.SetTAndDesc("kick", "moderator", "Кикает игрока. arg1 - ник игрока, arg2 - причина.")

local vec = Vector(-15999, -15999, -15999)

nAdmin.AddCommand("jail", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "jail")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil and ply ~= Entity(0) then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	local function pl_Null()
		pl:SetNWBool("nAdmin_InJail", false)
	end
	pl_Null()
	local arg2 = tonumber(args[2]) or 0
	if arg2 ~= 0 then
		nAdmin.PrintAndWarn(ply:Name() .. " засунул в гулаг " .. pl:Name() .. " на " .. arg2 .. " секунд.")
		timer.Create(tostring(pl) .. "_nAdminJail", arg2, 1, function()
			pl_Null()
		end)
		goto skip
	end
	nAdmin.PrintAndWarn(ply:Name() .. " засунул в гулаг " .. pl:Name() .. ".")
	::skip::
	pl:SetNWBool("nAdmin_InJail", true)
	pl:SetPos(vec)
	local plName = pl:Name()
	local as = tostring(pl)
	timer.Create(as .. "nAdmin_ToJail", .05, 0, function()
		if not pl:IsValid() then
			timer.Remove(as .. "nAdmin_ToJail")
			nAdmin.WarnAll(plName .. " вышел из игры во время нахождения в гулаге!")
			return
		end
		if pl:GetNWBool("nAdmin_InJail") == true then
			pl:SetPos(vec)
		else
			pl:Spawn()
			timer.Remove(as .. "nAdmin_ToJail")
		end
	end)
	net.Start("nAdmin_JailHUD")
		net.WriteFloat(arg2)
	net.Send(pl)
end)
nAdmin.SetTAndDesc("jail", "builderreal", "Садит человека в гулаг. arg1 - ник игрока, arg2 - количество секунд.")

nAdmin.AddCommand("unjail", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "unjail")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	local arg2 = tonumber(args[2]) or 0
	if not pl:GetNWBool("nAdmin_InJail") then
		return
	end
	if timer.Exists(tostring(pl) .. "_nAdminJail") then
		timer.Remove(tostring(pl) .. "_nAdminJail")
	end
	pl:SetNWBool("nAdmin_InJail", false)
	pl:Spawn()
	nAdmin.PrintAndWarn(ply:Name() .. " выпустил из гулага " .. pl:Name() .. ".")
end)
nAdmin.SetTAndDesc("unjail", "builderreal", "Освобождает человека с гулага. arg1 - ник игрока.")

hook.Add("PlayerSpawnObject", "restrictJail", function(ply)
	if ply:GetNWBool("nAdmin_InJail") then
		return false
	end
end)

nAdmin.AddCommand("spectate", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "spectate")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	local function upd_Spectate()
		ply:SetObserverMode(OBS_MODE_IN_EYE)
		ply:SpectateEntity(pl)
	end
	upd_Spectate()
	nAdmin.Print(ply:Name() .. " следит за " .. pl:Name())
	local function del_AllSpectateHooks()
		ply:SetObserverMode(0)
		ply:UnSpectate()
		hook.Remove("KeyPress", ply:EntIndex().. "_nAdmin_UnSpectate")
		hook.Remove("PlayerDisconnected", ply:EntIndex().. "_nAdmin_UnSpectate")
		hook.Remove("PlayerSpawn", ply:EntIndex() .. "_nAdmin_UnSpectate")
	end
	hook.Add("KeyPress", ply:EntIndex().. "_nAdmin_UnSpectate", function(pl_, k)
		if pl_ ~= ply then return end
		if k ~= 8 and k ~= 16 and k ~= 512 and k ~= 1024 then return end
		del_AllSpectateHooks()
		nAdmin.Print(ply:Name() .. " больше не следит за " .. pl:Name())
	end)
	hook.Add("PlayerDisconnected", ply:EntIndex().. "_nAdmin_UnSpectate", function(pl_)
		if pl_ ~= pl or pl_ ~= ply then return end
		del_AllSpectateHooks()
		nAdmin.Print(ply:Name() .. " больше не следит за " .. pl:Name())
	end)
	hook.Add("PlayerSpawn", ply:EntIndex() .. "_nAdmin_UnSpectate", upd_Spectate)
end)
nAdmin.SetTAndDesc("spectate", "moderator", "Включает режим наблюдения за игроком. arg1 - ник игрока.")

nAdmin.AddCommand("gag", false, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "gag")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	if not pl.Gagged then
		pl.Gagged = true
	else
		pl.Gagged = false
	end
	nAdmin.PrintAndWarn(ply:Name() .. " " .. (pl.Gagged and "запретил" or "разрешил") .. " говорить в ГЧ " .. pl:Name().. ".")
end)
nAdmin.SetTAndDesc("gag", "moderator", "Запретить/разрешить игроку говорить. arg1 - ник.")

local function GagUngag(_, a)
	if a.Gagged then
		return false
	end
end
hook.Add("PlayerCanHearPlayersVoice", "nAdmin_gag", GagUngag)

nAdmin.AddCommand("goto", false, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "goto")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	ply.OldPositionTP = ply:GetPos()
	p(ply.OldPositionTP)
	ply:SetPos(pl:EyePos() + Vector(pl:EyeAngles():Right()[1], 0, 0) * 150)
end)
nAdmin.SetTAndDesc("goto", "noclip", "Телепортироваться к игроку. arg1 - ник.")

nAdmin.AddCommand("return", false, function(ply, args)
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		pl = ply
	end
	if not pl.OldPositionTP then
		nAdmin.Warn(ply, "Игрок никуда не телепортировался.")
		return
	end
	pl:SetPos(pl.OldPositionTP)
end)
nAdmin.SetTAndDesc("return", "builderreal", "Телепортироваться к игроку. arg1 - ник (необязательно).")

nAdmin.AddCommand("bring", false, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "bring")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	pl.OldPositionTP = pl:GetPos()
	pl:SetPos(ply:EyePos() + Vector(ply:EyeAngles():Right()[1], 0, 0) * 150)
end)
nAdmin.SetTAndDesc("bring", "builderreal", "Телепортировать игрока к себе. arg1 - ник.")

nAdmin.AddCommand("mute", false, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "mute")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	if not pl.Muted then
		pl.Muted = true
	else
		pl.Muted = false
	end
	nAdmin.PrintAndWarn(ply:Name() .. " " .. (pl.Muted and "запретил" or "разрешил") .. " писать в чат " .. pl:Name().. ".")
end)
nAdmin.SetTAndDesc("mute", "moderator", "Запретить/разрешить игроку писать в чат. arg1 - ник.")

local function plSay(pl, txt)
	if pl.Muted then return "" end
end
hook.Add("PlayerSay", "nAdmin_mute", plSay)

nAdmin.AddCommand("mgag", false, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "mgag")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	if not pl.Muted then
		pl.Muted = true
	else
		pl.Muted = false
	end

	if not pl.Gagged then
		pl.Gagged = true
	else
		pl.Gagged = false
	end

	if pl.Gagged ~= pl.Muted then
		pl.Gagged = true
		pl.Muted = true
		nAdmin.Print("Значения Gag и Mute различаются. Мучу и запрещаю игроку писать в чат!")
	end
	nAdmin.PrintAndWarn(ply:Name() .. " " .. (pl.Gagged and "запретил" or "разрешил") .. " писать в чат и говорить в ГЧ " .. pl:Name().. ".")
end)
nAdmin.SetTAndDesc("mgag", "moderator", "Запретить/разрешить игроку писать в чат и говорить в ГЧ. arg1 - ник.")

nAdmin.AddCommand("banip", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 2, ply, "banip")
	if not check then
		return
	end
	if curtime > CurTime() then
		nAdmin.Warn(ply, "Подождите ещё " .. math.Round(curtime - CurTime()) .. " секунд.")
		return
	end
	curtime = CurTime() + 10
	local min_ = args[2]
	local m2 = tonumber(string.sub(min_, 1, #min_ - 1))
	if string.EndsWith(min_, "m") then
		m2 = m2
	elseif string.EndsWith(min_, "h") then
		m2 = m2 * 60
	elseif string.EndsWith(min_, "d") then
		m2 = m2 * 60 * 24
	elseif string.EndsWith(min_, "w") then
		m2 = m2 * 60 * 24 * 7
	else
		nAdmin.Warn(ply, "Введите корректное значение 2 аргумента. (Пример: 7m, 7h, 7d, 7w)")
		return
	end
	RunConsoleCommand("addip", m2, args[1]:Trim())
	RunConsoleCommand("writeip")
	nAdmin.Print(ply:Name() .. " забанил: " .. args[1]:Trim())
end)
nAdmin.SetTAndDesc("banip", "vutka", "Банит IP адрес. arg1 - время, arg2 - IP.")

nAdmin.AddCommand("unbanip", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "unbanip")
	if not check then
		return
	end
	if curtime > CurTime() then
		nAdmin.Warn(ply, "Подождите ещё " .. math.Round(curtime - CurTime()) .. " секунд.")
		return
	end
	curtime = CurTime() + 10
	RunConsoleCommand("removeip", args[1]:Trim())
	RunConsoleCommand("writeip")
	nAdmin.Print(ply:Name() .. " разбанивает: " .. args[1]:Trim())
end)
nAdmin.SetTAndDesc("unbanip", "vutka", "Разбанивает IP адрес. arg1 - IP.")

nAdmin.AddCommand("freeze", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "freeze")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	if pl.Freezed then
		return
	end
	pl:Freeze(true)
	pl.Freezed = true
	nAdmin.WarnAll(ply:Name() .. " зафризил " .. pl:Name())
end)
nAdmin.SetTAndDesc("freeze", "e2_coder", "Зафризить/разфризить игрока. arg1 - ник игрока.")

nAdmin.AddCommand("unfreeze", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "unfreeze")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	if not pl.Freezed then
		return
	end
	pl:Freeze(false)
	pl.Freezed = false
	nAdmin.WarnAll(ply:Name() .. " разфризил " .. pl:Name())
end)
nAdmin.SetTAndDesc("unfreeze", "e2_coder", "Зафризить/разфризить игрока. arg1 - ник игрока.")

nAdmin.AddCommand("ip", true, function(ply, args)
	local check = nAdmin.ValidCheckCommand(args, 1, ply, "ip")
	if not check then
		return
	end
	local pl = nAdmin.FindByNick(args[1])
	if pl == nil then
		nAdmin.Warn(ply, "Игрока с таким ником нет на сервере.")
		return
	end
	local ip = pl:IPAddress()
	if ip == "loopback" then
		ip = "0.0.0.0:27015"
	end
	ip = ip:sub(1, ip:find(":") - 1)
	nAdmin.Warn(ply, "IP адрес " .. pl:Name() .. ": " .. ip)
end)
nAdmin.SetTAndDesc("ip", "admin", "Узнать имя игрока. arg1 - ник игрока.")