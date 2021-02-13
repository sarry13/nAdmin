if CLIENT or SERVER then
	local meta = FindMetaTable("Player")

	function meta:GetTotalTime()
		return self:GetNWInt("TotalTime", 0) + self:GetSessionTime()
	end

	function meta:GetSessionTime()
		return CurTime() - self:GetNWInt("StartTimeSession", 0)
	end

	function meta:GetStartTimeSession()
		return self:GetNWInt("StartTimeSession", 0)
	end

	function meta:SetTotalTime(n)
		ply:SetNWInt("TotalTime", tonumber(n) or ply:GetTotalTime() or 0)
	end
end

if SERVER then
    if game.SinglePlayer() then
		nAdmin.Print("Вы находитесь в одиночной игре. Модуль playtime не будет включён.")
		return
	end

	if nAdminDBFail then
		nAdmin.Print("Не удалось подключиться к базе данных.")
		return
	end

	local meta = FindMetaTable'Player'

	function meta:SetPTime(TIME)
		local ACID = self:AccountID()
		local Q = nAdminDB:query("REPLACE INTO nAdmin_time (infoid, time) VALUES (" .. SQLStr(ACID) .. ", " .. SQLStr(TIME) .. ")")
		function Q:onError(err)
			nAdmin.Print("Запрос выдал ошибку: " .. err)
		end
		Q:start()
	end

	function meta:GetPTime(func)
		local ACID = self:AccountID()
		local Q = nAdminDB:query("SELECT time FROM nAdmin_time WHERE infoid = " .. SQLStr(ACID) .. " LIMIT 1")
		function Q:onError(err)
			nAdmin.Print("Запрос выдал ошибку: " .. err)
		end
		Q:start()
		function Q:onSuccess(data)
			if data and data[1] then
				func(data[1].time)
			else
				func(0)
			end
		end
	end

	function meta:RemovePTime()
		local ACID = self:AccountID()
		local Q = nAdminDB:query("DELETE FROM nAdmin_time WHERE infoid = " .. SQLStr(ACID))
		function Q:onError(err)
			nAdmin.Print("Запрос выдал ошибку: " .. err)
		end
		Q:start()
	end

	function nAdminDB:onConnected()
		nAdmin.Print("База данных успешно подключена.")
	end

	function nAdminDB:onConnectionFailed( err )
		print("Ошибка подключения к базе данных!")
		print("Ошибка:", err)
	end
	nAdminDB:connect()

    hook.Add("PlayerInitialSpawn", "PTime", function(ply)
        ply:SetNWInt("StartTimeSession", CurTime())
		ply:GetPTime(function(a)
			ply:SetNWInt("TotalTime", a)
		end)
    end)

    hook.Add("PlayerDisconnected", "PTime", function(ply)
        ply:SetPTime(ply:GetTotalTime())
    end)

	local function savePTime()
		for _, ply in ipairs(player.GetAll()) do
			ply:SetPTime(ply:GetTotalTime())
		end
	end

	timer.Create("savePTime", 120, 0, savePTime)

	hook.Add("PlayerInitialSpawn", "restoretime", function(ply)
		timer.Simple(.5, function()
			local query = sql.QueryRow("SELECT totaltime FROM utime WHERE player = " .. ply:UniqueID() .. ";")
			if query ~= nil then
				ply:SetPTime(query)
				sql.Query("DELETE FROM utime WHERE player = " .. ply:UniqueID() .. ";")
			end
		end)
	end)
end