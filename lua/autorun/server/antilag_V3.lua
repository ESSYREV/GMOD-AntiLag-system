print("\n\n\n\n\n\n\n\n\n\n\n ANTILAG.ESRV 'n'n''n'n'n'n")

----- CONFIGURATION -----
local maxCollisionsCountInChunk = 256 -- Количество столкновений, которое может произойти в 1 месте в одну секунду
local maxCollisionForBadProps = 4 -- Если в 1 момент из-за одного пропа <= чем ___, то проп-виновник удаляется 







local PlayerUnfreezes = {}
local WORLD_COLLISION_CHUNK = {}
local WORLD_COLLISION_CHUNK_count = {}
local WORLD_COLLISION_CHUNK_player = {}
local WORLD_POPULAR_PROPS = {}

timer.Create("esrv_antilag-clearworldtable",1,0,function() 
	WORLD_COLLISION_CHUNK={}
	WORLD_COLLISION_CHUNK_player = {}
	WORLD_COLLISION_CHUNK_count = {}
end)
Entity(0).meshConvexes = nil
Entity(0).disabledCollision = false

local chunk_size = 10
local function vecround(vector)
    return Vector(math.Round(vector.x/chunk_size)*chunk_size, math.Round(vector.y/chunk_size)*chunk_size, math.Round(vector.z/chunk_size)*chunk_size)
end


local function process_collision(ent1,ent2)


    ent1.collisionCount = (ent1.collisionCount or 0) + (ent1.meshConvexes or 0)
    ent2.collisionCount = (ent2.collisionCount or 0) + (ent2.meshConvexes or 0)

    if (ent1.collisionCount + ent2.collisionCount) > 512 then
        ent1.disabledCollision = true
        ent2.disabledCollision = true
    end


end

local whitelist = {}
whitelist['gmod_sent_vehicle_fphysics_wheel'] = true

hook.Add("ShouldCollide","esrv_collisionCount", function( ent1, ent2 )

	local e1world = ent1==Entity(0)
	local e2world = ent2==Entity(0)

	local e1player = ent1:IsPlayer()
	local e2player = ent2:IsPlayer()

	if (ent1.shouldBeFreezed) and (ent2.shouldBeFreezed) and not (e1player or e2player) then
		return false
	end




    ----------------- props- ---------
    if ent1.meshConvexes and ent2.meshConvexes then 

        local vec = vecround(ent1:GetPos())
        WORLD_COLLISION_CHUNK[tostring(vec)] = (WORLD_COLLISION_CHUNK[tostring(vec)] or 0) + (ent1.meshConvexes or 0) + (ent2.meshConvexes or 0)
		WORLD_COLLISION_CHUNK_count[tostring(vec)] = (WORLD_COLLISION_CHUNK_count[tostring(vec)] or 0) + 1


        --print( WORLD_COLLISION_CHUNK[tostring(vec)], " ////// ",WORLD_COLLISION_CHUNK_count[tostring(vec)] )
        if  WORLD_COLLISION_CHUNK[tostring(vec)] > 16000 or 
        	WORLD_COLLISION_CHUNK_count[tostring(vec)] > maxCollisionsCountInChunk then

        	if (not e1world) then ent1.shouldBeFreezed = true end
        	if (not e2world) then ent2.shouldBeFreezed = true end

        end

    end


end)


local function antilag_realtime()

	local should_freeze_player = {}

	for _,prop in pairs(ents.GetAll()) do
		if prop.shouldBeFreezed then
			if IsValid(prop:CPPIGetOwner()) then should_freeze_player[prop:CPPIGetOwner():Nick()] = (should_freeze_player[prop:CPPIGetOwner():Nick()] or 0) + 1 end
			prop.shouldBeFreezed = nil
			if IsValid(prop:GetPhysicsObject()) then
				prop:GetPhysicsObject():EnableMotion(false)
				prop:GetPhysicsObject():Sleep()
			end
		end

		if prop.TakedDamage then
			prop.TakedDamage = nil
		end
	end

	--print( table.Count( should_freeze_player ) )
	if table.Count(should_freeze_player) == 0 then return end

	local count = 0
	local str = "Сервер посчитал, что его пытаются крашнуть  <emote=emoticon_happy,16,silkicons>\n"
	for player, props in pairs(should_freeze_player) do
		count = count + props
		--if count > 3 then
			str = str .. player .. ", замороженных пропов: "..props.."\n"
		--end
	end

	if count < 4 then return end

	for _, ply in pairs(player.GetAll()) do
		ply:PrintMessage(3,str)
	end

	--local embeds = discord.commands.createEmbeds("Попытка крашнуть сервер",str,"FF0000")
	--http.Post( "http://game11690.worldhosts.fun/discord/main.php", { method = "write",embeds = embeds, webhook = ""})

end

local function antilag_unfreeze()

end




hook.Add("Tick","esrv_collisionCount-shouldberemoved",function()

    ---if not (PlayerUnfreezes[ply]['bool'] == true) then 
    --if PlayerUnfreezes[ply]['props'] == nil then PlayerUnfreezes[ply]['props'] = {} end

    local message = {}
    for player, ptable in pairs(PlayerUnfreezes) do
    	if PlayerUnfreezes[player]['bool'] == true then

    		message[player] = (message[player] or 0) + 1

    		for _, prop in pairs(PlayerUnfreezes[player]['props']) do
    			local phys = prop:GetPhysicsObject()
    			if IsValid(phys) then
    				phys:EnableMotion(false)
    			end
    		end
    	end
    end


    for player, count in pairs(message) do
    	player:PrintMessage(3,player:GetName()..", сервер не позволит разморозить вам данную постройку")
    end


    PlayerUnfreezes = {}

end)



local function onEntityCreated(ent)
    timer.Simple(0,function()
        if IsValid(ent) and IsValid(ent:CPPIGetOwner()) then-- IsValid(ent:CPPIGetOwner()) then --ent:GetClass() == "prop_physics" then
            ent:SetCustomCollisionCheck( true )

            ent:SetModelScale(1)

            if IsValid(ent:GetPhysicsObject()) then
            	local mesh = ent:GetPhysicsObject():GetMesh()

            	if not (mesh==nil) then
            		mesh = #mesh
            		if mesh > 10000 then mesh = mesh / 2 end
                	ent.meshConvexes = mesh
            	end
            end

            timer.Create(tostring(ent),2,0,function()
            	if not IsValid(ent) then timer.Remove(tostring(ent)) end
                ent.collisionCount = 0
            end)

        end
    end)
end


hook.Add( "InitPostEntity", "esrv-antilag_start", function()
	hook.Add("OnEntityCreated","esrv_collisionCount",function(ent)
		onEntityCreated(ent)
	end)
end)

hook.Add("EntityRemoved","esrv_collisionCount",function(ent)
    timer.Remove(tostring(ent))
    WORLD_POPULAR_PROPS[ent] = nil
end)


hook.Add( "PlayerSpawn", "esrv_antilag-playercollisioncount",function(player)

	player.playerCollisionCount = 0
	timer.Create(tostring(player),1,0,function()
		player.playerCollisionCount = 0
		player.playerCanCollision = true
	end)

end)

hook.Add( "PlayerDisconnected", "esrv_antilag-playercollisioncount", function(ply)
	timer.Remove(tostring(player))
end)

hook.Add("EntityTakeDamage", "esrv_antilag", function(ent,dmginfo)
	ent.TakedDamage = true
end)















local stressed
local stressed_all

local last_table = 0
local should_table = {}
should_table[1] = 0
should_table[2] = 0
should_table[3] = 0
should_table[4] = 0
should_table[5] = 0
local should_active = false


hook.Add("Tick","esrv_antilag",function()

	local frametime = engine.AbsoluteFrameTime()

	if CurTime() > last_table then
		should_table[5] = nil
		table.insert( should_table, 1, frametime )
		last_table = CurTime() + 1
	end

	zero_second = 0



	--print( should_table[1] + should_table[2] + should_table[3] + should_table[4] + should_table[5] )

	if frametime >= 0.45 then
		should_active = true
	end

	if frametime > 0.4 then
		stressed()
 	end

	if frametime > 0.55 then
		stressed_all()
 	end



end)

local canMessage = 0
stressed = function()

	local attackers = {}

	for _,ent in pairs(ents.GetAll()) do
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			local owner = ent:CPPIGetOwner()
			local to = phys:GetStress()

			if not IsValid(owner) then continue end

			if to > 512 then

				ent:GetPhysicsObject():EnableMotion(false)
				attackers[owner] = (attackers[owner] or 0) + 1

			end

		end
	end

	local str = "Возможно, сервер лагает :) \n Замороженные пропы игроков:\n"
	for player, count in pairs(attackers) do
		str = str .. player:Nick() .. ": " .. count .. "\n"
	end

	if (CurTime() > canMessage) and (table.Count(attackers) > 0) then 
		for _,ply in pairs(player.GetAll()) do
			ply:PrintMessage(3,str)
		end

		canMessage = CurTime() + 2
	end

end


stressed_all = function()

	for _,ent in pairs(ents.GetAll()) do
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			if not IsValid(owner) then continue end
			ent:GetPhysicsObject():EnableMotion(false)
		end
	end

	local str = "Сервер обнаружил высокую нагрузку и заморозил все пропы на карте"
	if (CurTime() > canMessage) then 
		for _,ply in pairs(player.GetAll()) do
			ply:PrintMessage(3,str)
		end
		canMessage = CurTime() + 1
	end


	local chips = ents.FindByClass("gmod_wire_expression2")
	for k,e2 in pairs(chips) do
		e2:PCallHook( "destruct" )
	end

	chips = ents.FindByClass("starfall_processor")
	for _,sf in pairs(chips) do
		sf:Remove()
	end

end

hook.Add("CanPlayerUnfreeze","essyrev-antilag", function(ply,ent,phys )


    local vec = vecround(ent:GetPos())
    if PlayerUnfreezes[ply] == nil then PlayerUnfreezes[ply] = {} end
    if not (PlayerUnfreezes[ply]['bool'] == true) then 
    	PlayerUnfreezes[ply][tostring(vec)] = (PlayerUnfreezes[ply][tostring(vec)] or 0) + (ent.meshConvexes or 0) + (ent.meshConvexes or 0) 
    else
    	return false
    end

    --print(PlayerUnfreezes[ply][tostring(vec)])
    if PlayerUnfreezes[ply][tostring(vec)] > 1200 then
    	PlayerUnfreezes[ply]['bool'] = true
    	return false
    end

    if PlayerUnfreezes[ply]['props'] == nil then PlayerUnfreezes[ply]['props'] = {} end
    table.insert( PlayerUnfreezes[ply]['props'], ent )

end)






--hook.Remove("Tick","esrv_collisionCount")



--hook.Remove("ShouldCollide","esrv_collisionCount")
--hook.Remove("OnEntityCreated","esrv_collisionCount")
--hook.Remove("EntityRemoved","esrv_collisionCount")





--hook.Remove( "PlayerSpawn", "esrv_antilag-playercollisioncount")
--hook.Remove( "PlayerDisconnected", "esrv_antilag-playercollisioncount")
--hook.Remove("Tick","esrv_antilag")
