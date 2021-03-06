if CLIENT then
	nAdmin.AddCommand("menu", function()
		if not IsValid(nGUI) then
			xpcall(nAdmin.mGUI, function()
				p("Меню недоступно. Перезагружаю файлы!")
				nAdmin.UpdateFiles()
			end)
		else
			if nGUI:IsVisible() then
				gui.EnableScreenClicker(false)
				nGUI:AlphaTo(0, .1, 0, function()
					nGUI:SetVisible(false)
				end)
			else
				nGUI:SetVisible(true)
				gui.EnableScreenClicker(true)
				nGUI:AlphaTo(255, .1, 0)
			end
		end
	end)
	nAdmin.AddCommand("fullupdate", function()
		LocalPlayer():ConCommand("record 1;stop")
	end)
	nAdmin.AddCommand("g", function(a)
		gui.OpenURL("https://www.google.com/search?&q=" .. table.concat(a, "+"))
	end)
	nAdmin.AddCommand("y", function(a)
		gui.OpenURL("https://yandex.ru/search/?text=" .. table.concat(a, "%20"))
	end)
	nAdmin.AddCommand("browser", function()
		gui.OpenURL("https://yandex.ru/")
	end)
	nAdmin.AddCommand("git", function(a)
		gui.OpenURL("https://github.com/search?q=" .. table.concat(a, "+"))
	end)
	nAdmin.AddCommand("mutecl", function(a)
		local ent = nAdmin.FindByNick(a[1])
		if ent == nil then
			chat.AddText(Color(150, 150, 150), "Игрока с таким ником нет на сервере!")
			return
		end
		ent:SetMuted(true)
		ent.Muted = true
		hook.Add("OnPlayerChat","nAdminMute",function(ply)
			if ply.Muted then
				return true
			end
		end)
	end)
	nAdmin.AddCommand("unmutecl", function(a)
		local ent = nAdmin.FindByNick(a[1])
		if ent == nil then
			chat.AddText(Color(150, 150, 150), "Игрока с таким ником нет на сервере!")
			return
		end
		ent:SetMuted(false)
		ent.Muted = nil
		for k, v in ipairs(player.GetAll()) do
			if v.Muted then
				return
			end
		end
		hook.Remove("OnPlayerChat","nAdminMute")
	end)
	nAdmin.AddCommand("help", function()
		nAdmin.Warn(_, "Смотрите консоль.")
		for k, v in SortedPairs(nAdmin.Commands) do
			p("", "n " .. k .. " -", v.desc or "Нет описания", "Доступен с: " .. (v.T or "Игрок"))
		end
	end)
	nAdmin.SetTAndDesc("g", "user", "Поиск чего-нибудь в Google. arg1 - что-то искать.")
	nAdmin.SetTAndDesc("git", "user", "Поиск чего-нибудь в GitHub. arg1 - что-то искать.")
	nAdmin.SetTAndDesc("browser", "user", "Открыть браузер.")
	nAdmin.SetTAndDesc("mutecl", "user", "Замутить на клиенте игрока. arg1 - ник игрока.")
	nAdmin.SetTAndDesc("unmutecl", "user", "Размутить на клиенте игрока. arg1 - ник игрока.")
	nAdmin.SetTAndDesc("y", "user", "Поиск чего-нибудь в Яндексе. arg1 - что-то искать.")
end

if SERVER then
	local meta = FindMetaTable("Player")
	nAdmin.AddCommand("giveammo", false, function(ply, args)
		local check = nAdmin.ValidCheckCommand(args, 1, ply, "giveammo")
		if not check then
			return
		end
		if not IsValid(ply:GetActiveWeapon()) then return end
		local a = ply:GetActiveWeapon():GetPrimaryAmmoType()
		local num = tonumber(args[1])
		local c = (num ~= nil and num or 0)
		if a ~= -1 then
			ply:GiveAmmo(math.Clamp(c, 0, 9999), a)
		end
		local b = ply:GetActiveWeapon():GetSecondaryAmmoType()
		if b ~= -1 then
			ply:GiveAmmo(math.Clamp(c, 0, 9999), b)
		end
	end)
	nAdmin.SetTAndDesc("giveammo", "user", "Дать себе патроны. arg1 - количество патрон.")
	local function days( time )
		time = time / 60 / 60
		return time
	end
	nAdmin.AddCommand("uptime", false, function(ply, args)
		timer.Simple(0, function()
			nAdmin.Warn(ply, "Сервер онлайн уже: " .. math.Round(days(SysTime())) .. " часов.")
		end)
	end)
	nAdmin.AddCommand("leave", false, function(ply, args)
		timer.Simple(.5, function()
			if not args then
				ply:Kick("Отключился")
			else
				ply:Kick("Отключился: " .. table.concat(args, " "))
			end
		end)
	end)
	nAdmin.SetTAndDesc("leave", "user", "Выйти с сервера. arg1 - причина. (необязательно)")
	nAdmin.AddCommand("me", false, function(ply, args)
		for _, pl in ipairs(player.GetAll()) do
			if pl:GetPos():DistToSqr(ply:GetPos()) > 300000 then continue end
			pl:ChatPrint("* " .. ply:Name() .. " " .. table.concat(args, " "))
		end
	end)
	nAdmin.SetTAndDesc("me", "user", "Что-то \"сделать\". arg1 - текст.")
	--[[
	nAdmin.AddCommand("ulxbanstonadmin", false, function(ply, _, args)
		if not ply:IsSuperAdmin() then return end
		local a = file.Read("nadmin/ulxbans.txt", "DATA")
		a = "\"ULXGAYSTVO\" {" .. a .. "}" -- замечательный обход
		a = util.KeyValuesToTable(a)
		for stid, tbl in next, a do
			if tbl.reason == nil then
				tbl.reason = "Нет причины."
			end
			nAdmin.AddBan(stid, tonumber(os.time()) - tonumber(tbl.time), tbl.reason, ply, true)
		end
	end)
	nAdmin.SetTAndDesc("ulxbanstonadmin", "superadmin", "")
	nAdmin.AddCommand("ulxusergroupsstonadmin", false, function(ply, _, args)
		if not ply:IsSuperAdmin() then return end
		local a = file.Read("nadmin/ulxusergroups.txt", "DATA")
		a = "\"ULXGAYSTVO\" {" .. a .. "}" -- замечательный обход
		a = util.KeyValuesToTable(a)
		for stid, tbl in next, a do
			SetUserGroupID(stid, tbl.group)
		end
		p("есть ошибка? да и похуй")
	end)
	nAdmin.SetTAndDesc("ulxusergroupsstonadmin", "superadmin", "")
	]]--
end
