print("Essyrev AntiLag system: Loading ")

local settings = {}

settings.polygons = 145000				------ Максимальное количество обработанных полигонов в одном чанке

settings.count = 125					------ Максимальное количество обработанных колизий в одном чанке
settings.delay = 0.5					------ Время обнуления количества столкновений в чанках [секунда]

settings.size = 20 						------ Размер одного чанка для обработки колизии
settings.distance = settings.size*2 	------ Максимальная дистанция, при которой произойдет просчёт физики антилагом		(Vector1 - Vector2):Length()

settings.enable_player_check = true
settings.player = 125 					------ Максимальное количество столкновений игрока с пропами [время обновления settings.delay]
										------ Имеется ввиду, к примеру: игрок может столкнуться за 1 тик с 4 пропами максимум.
										------ Большие числа могут вызвать краш сервера!!!
										------ А низкие могут мешать игрокам нормально передвигаться в своих постройках



local process_collision
local onEntityCreated
local canunfreeze
local tick
local chunk = {}
local chunk_unfreeze = {}
local server_frametime = {}
local server_player_ents = {}
local server_frametime_next = 0
local player_update_ents = 0
local can_send_message = 0
local last_reset = 0
local last_tick = 0
local stress1
local stress2
local stress3
local shouldFreezeAll = false

local whitelist = {}
whitelist["func_brush"] = true
whitelist['func_reflective_glass'] = true
whitelist['func_vehicleclip'] = true

local function vecround(vector)
	local size = settings.size
    return Vector(math.Round(vector.x/size)*size, math.Round(vector.y/size)*size, math.Round(vector.z/size)*size)
end


hook.Remove("CanPlayerUnfreeze","essyrev-antilag", function(ply,ent)
	canunfreeze(ply,ent)
end) -- Фигня бесполезная. Не работает.

hook.Add("OnEntityCreated","esrv-antilag",function(ent)
	onEntityCreated(ent)
end)

hook.Add( "PlayerSpawn", "esrv-antilag",function(ply)
	ply:SetCustomCollisionCheck( true )
end)


local now_i_am_think = false
hook.Add( "ShouldCollide", "esrv-antilag", function( ent1, ent2 )

	if not (IsValid(ent1) and IsValid(ent2)) then return end
	if now_i_am_think then return end

	if shouldFreezeAll then	return false end
	if last_tick+(settings.delay * 5) < CurTime() then 
		ent1.shouldFreeze = true
		ent2.shouldFreeze = true
		return false 
	end

	local distance = (ent1:GetPos() - ent2:GetPos()):Length()
	if distance >= settings.distance then return end


	now_i_am_think = true

	local e1p = ent1:IsPlayer()
	local e2p = ent2:IsPlayer()

	if settings.enable_player_check and (e1p or e2p) then

		if e1p then

			if (server_player_ents[ent1] or 0) > settings.player then return false end
			server_player_ents[ent1] = (server_player_ents[ent1] or 0) + 1

		else

			if (server_player_ents[ent2] or 0) > settings.player then return false end
			server_player_ents[ent2] = (server_player_ents[ent2] or 0) + 1

		end

	end

	if (ent1.meshConvexes or ent2.meshConvexes) and (e1p==false and e2p==false) then
		process_collision(ent1,ent2)
	end

	now_i_am_think = false
end)

hook.Add( "Tick", "esrv-antilag", function() tick() end)











onEntityCreated = function(ent)
    timer.Simple(0,function()

    	if IsValid(ent) and string.StartsWith(ent:GetClass(), "func_") then
    		ent.EntityIsFunc = true
    	end

        if IsValid(ent) and IsValid(ent:CPPIGetOwner()) then
            ent:SetCustomCollisionCheck( true )

            ent:SetModelScale(1)

            if IsValid(ent:GetPhysicsObject()) then
            	local mesh = ent:GetPhysicsObject():GetMesh()

            	if not (mesh==nil) then
                	ent.meshConvexes = #mesh
            	end
            end
            ent.collisionCount = 0
            ent.AntilagLastReset = 0

            timer.Create(tostring(ent),0,0,function()
            	if not IsValid(ent) then timer.Remove(tostring(ent)) return end
                if IsValid(ent) and ent.AntilagLastReset < settings.delay then 
                	ent.collisionCount = 0
                	ent.AntilagLastReset = CurTime() + settings.delay
                end
            end)

        end
    end)
end

process_collision = function(ent1,ent2)

	if (	whitelist[ent1:GetClass()]		) or (		whitelist[ent2:GetClass()]		) then return end

	if (	ent1.EntityIsFunc==true			) or (		ent2.EntityIsFunc==true			) then return end



	local position = tostring(vecround(ent1:GetPos()))
	chunk[position] = (chunk[position] or 0) + (ent1.meshConvexes or 0) + (ent2.meshConvexes or 0)
	chunk["count"..position] = (chunk["count"..position] or 0) + 1
	ent1.collisionCount = ent1.collisionCount + 1
	ent2.collisionCount = ent1.collisionCount + 1

	if ent1.shouldFreeze or ent2.shouldFreeze then 
		return false
	end

	if chunk[position] >= settings.polygons or 
		chunk["count"..position] >= settings.count then

			if (ent1.collisionCount >= settings.count*2) then ent1.shouldFreeze = true end
			if (ent2.collisionCount >= settings.count*2) then ent2.shouldFreeze = true end

			if ent1.shouldFreeze==true and ent2.shouldFreeze==true then return false end
	end 
end

canunfreeze = function(ply,ent)

	local position = tostring(vecround(ent:GetPos()))
    if chunk_unfreeze[ply] == nil then 
    	chunk_unfreeze[ply] = {} 
    end

    chunk_unfreeze[ply][position] = (chunk_unfreeze[ply][position] or 0) + (ent.meshConvexes or 0) 

    if chunk_unfreeze[ply][position] >= settings.polygons/2 then
    	chunk_unfreeze[ply]['message'] = true
    	return false
    end 

end


tick = function()

	last_tick = CurTime()

	if server_frametime_next <= CurTime() then
		local frametime = engine.AbsoluteFrameTime()
		table.insert(server_frametime,1,frametime)
		server_frametime[5] = nil

		server_frametime_next = CurTime() + 0.25
	end


	local frametime = 0
	for i=1,#server_frametime do
		frametime = frametime + server_frametime[i]
	end


	local overflow_frametime = frametime >= 0.6

	if overflow_frametime and can_send_message < CurTime() then


		if (frametime > 0.6) and (frametime < 1.5) then
			print("0.6")
			stress1()

			elseif (frametime > 1.5) and (frametime < 1.85) then
				print("1.5")
				stress2()

				elseif frametime > 1.85 then
					print("1.85")
					stress2() 	-- Здесь  пока не придумал, что написать
								-- Но очищать карту не очень бы хотелось

					end

	can_send_message = CurTime() + 1.5

	end



	for _, prop in pairs(ents.GetAll()) do

		if prop.shouldFreeze == true then
			if whitelist[ prop:GetClass() ] then
				prop.shouldFreeze = false
				continue
			end
			local phys = prop:GetPhysicsObject()
			local parented = IsValid(prop:GetParent())

			if IsValid(phys) and not parented then
				phys:EnableMotion(false)
				phys:Sleep()
				prop.shouldFreeze = false
			end

		end
	end


	if last_reset < CurTime() then
		chunk = {}
		last_reset = CurTime() + settings.delay
		chunk_unfreeze = {}
	end


	for player,_ in pairs(chunk_unfreeze) do
		if chunk_unfreeze[player]['message'] then
			player:PrintMessage(3,player:Nick()..", ваши постройки, вероятно, могут нанести ущерб серверу.")
		end
	end

	server_player_ents = {}

end



stress1 = function()

	local players = {}

	for _, prop in pairs(ents.GetAll()) do

		local phys = prop:GetPhysicsObject()
		local owner = prop:CPPIGetOwner()

		if IsValid(phys) and IsValid(owner) and not IsValid( prop:GetParent() ) then
			if phys:GetStress() > 256 and prop.collisionCount > settings.count/10 then
				phys:EnableMotion(false)
				players[owner] = (players[owner] or 0) + 1
			end
		end

	end

	if table.Count(players) == 0 then return end
	if can_send_message > CurTime() then return end

	local string = "Сервер находится под нагрузкой, заморожены пропы игроков:\n"
	for player, count in pairs(players) do
		string = string .. player:Nick()..": "..count.."\n"
	end

	for _, player in pairs(player.GetAll()) do
		player:PrintMessage(3,string)
	end

end

stress2 = function() -- Замораживает все энтити на карте и выключает Е2 вместе с SF

	shouldFreezeAll = true

	for _, prop in pairs(ents.GetAll()) do

		local phys = prop:GetPhysicsObject()
		if IsValid(phys) and not IsValid( prop:GetParent() ) then
			phys:EnableMotion(false)
		end

	end

	local chips = ents.FindByClass("gmod_wire_expression2")
	for k,e2 in pairs(chips) do
		e2:PCallHook( "destruct" )
	end

	chips = ents.FindByClass("starfall_processor")
	for _,sf in pairs(chips) do
		sf:Remove()
	end

	if can_send_message > CurTime() then return end

	local string = "Сервер находится под средним уровнем нагрузки, все пропы и чипы заморожены."
	for _, player in pairs(player.GetAll()) do
		player:PrintMessage(3,string)
	end

	timer.Simple(0.5,function() shouldFreezeAll = false end)

end

