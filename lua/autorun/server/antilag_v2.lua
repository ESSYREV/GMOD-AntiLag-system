print("\n\n\n\n\n\n\n\n\n\n\n ANTILAG.ESRV 'n'n''n'n'n'n")

----- CONFIGURATION -----
local maxCollisionsCountInChunk = 256 -- Количество столкновений, которое может произойти в 1 месте в одну секунду
local maxCollisionForBadProps = 4 -- Если в 1 момент из-за одного пропа <= чем ___, то проп-виновник удаляется 








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

	if (ent1.shouldBeRemoved) or (ent2.shouldBeRemoved) then
		return false
	end

    if (ent1.disabledCollision == true) or (ent2.disabledCollision == true) and not (e1player or e2player) then -- попробовать OR
    	if e1world and not e2world then
    		return false
    	elseif e2world and not e1world then
    		return false
		end
    end

    if (ent1.disabledCollisionByPlayer == true) or (ent2.disabledCollisionByPlayer == true) then
    	return false
    end


    ------------ player
    if (e1player or e2player) and not (e1world or e2world) then
    	local vec = vecround(ent1:GetPos())
    	WORLD_COLLISION_CHUNK[tostring(vec)] = (WORLD_COLLISION_CHUNK[tostring(vec)] or 0) + (ent1.meshConvexes or 0) + (ent2.meshConvexes or 0)
    	WORLD_COLLISION_CHUNK_player[tostring(vec)] = (WORLD_COLLISION_CHUNK_player[tostring(vec)] or 0) + 1
		--WORLD_COLLISION_CHUNK_count[tostring(vec)] = (WORLD_COLLISION_CHUNK_count[tostring(vec)] or 0) + 1


        --print( WORLD_COLLISION_CHUNK[tostring(vec)], " //////player ",WORLD_COLLISION_CHUNK_player[tostring(vec)] )

    	if (WORLD_COLLISION_CHUNK[tostring(vec)] > 16000) and (WORLD_COLLISION_CHUNK_player[tostring(vec)] > maxCollisionsCountInChunk*6) then

			if e1player then
				ent2.disabledCollisionByPlayer = true
				--print(ent2.disabledCollisionByPlayer,ent2)
				if (WORLD_COLLISION_CHUNK[tostring(vec)] > 24000) or (WORLD_COLLISION_CHUNK_player[tostring(vec)] > maxCollisionsCountInChunk*10) then
					ent2.shouldBeRemoved = true
				end
			else
				ent1.disabledCollisionByPlayer = true
				--print(ent1.disabledCollisionByPlayer,ent1)
				if (WORLD_COLLISION_CHUNK[tostring(vec)] > 24000) or (WORLD_COLLISION_CHUNK_player[tostring(vec)] > maxCollisionsCountInChunk*10) then
					ent1.shouldBeRemoved = true
				end
			end

		end
    end



    ----------------- props- ---------
    if ent1.meshConvexes and ent2.meshConvexes then 
        --process_collision(ent1,ent2)
        local vec = vecround(ent1:GetPos())
        WORLD_COLLISION_CHUNK[tostring(vec)] = (WORLD_COLLISION_CHUNK[tostring(vec)] or 0) + (ent1.meshConvexes or 0) + (ent2.meshConvexes or 0)
		WORLD_COLLISION_CHUNK_count[tostring(vec)] = (WORLD_COLLISION_CHUNK_count[tostring(vec)] or 0) + 1


        --print( WORLD_COLLISION_CHUNK[tostring(vec)], " ////// ",WORLD_COLLISION_CHUNK_count[tostring(vec)] )
        if ((WORLD_COLLISION_CHUNK[tostring(vec)] > 32000)) and (not (ent1.TakedDamage==true or ent2.TakedDamage==true)) or (WORLD_COLLISION_CHUNK_count[tostring(vec)] > maxCollisionsCountInChunk) then 
        	if not e1world then ent1.disabledCollision = true end
        	if not e2world then ent2.disabledCollision = true end

        	WORLD_POPULAR_PROPS[ent1] = (WORLD_POPULAR_PROPS[ent1] or 0) + 1
        	WORLD_POPULAR_PROPS[ent2] = (WORLD_POPULAR_PROPS[ent2] or 0) + 1
        	if WORLD_POPULAR_PROPS[ent1] >= maxCollisionForBadProps then
        		ent1.shouldBeRemoved = true
        	end
        	if WORLD_POPULAR_PROPS[ent2] >= maxCollisionForBadProps then
        		ent2.shouldBeRemoved = true
        	end


        	--print(ent1,ent1.TakedDamage,ent2,ent2.TakedDamage)
        	

        	if WORLD_COLLISION_CHUNK[tostring(vec)] > 40000 then
        		if not e1world then ent1.shouldBeRemoved = true end
        		if not e2world then ent2.shouldBeRemoved = true end
        	end

        	return false
        end

    end


end)

hook.Add("Tick","esrv_collisionCount-shouldberemoved",function()



	local should_remove_players = {}

	for _,prop in pairs(ents.GetAll()) do
		if prop.shouldBeRemoved then
			if IsValid(prop:CPPIGetOwner()) then should_remove_players[prop:CPPIGetOwner():Nick()] = (should_remove_players[prop:CPPIGetOwner():Nick()] or 0) + 1 end
			prop:Remove()
		end

		if prop.disabledCollision then
			prop:SetCollisionGroup( 20 )
		end

		if prop.TakedDamage then
			prop.TakedDamage = nil
		end
	end

	--print( table.Count( should_remove_players ) )
	if table.Count(should_remove_players) == 0 then return end

	local count = 0
	local str = "Сервер посчитал, что его пытаются крашнуть  <emote=emoticon_happy,16,silkicons>\n"
	for player, props in pairs(should_remove_players) do
		count = count + props
		if count > 3 then
			str = str .. player .. ", удалённых пропов: "..props.."\n"
		end
	end

	if count < 4 then return end

	for _, ply in pairs(player.GetAll()) do
		ply:PrintMessage(3,str)
	end


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
                	--print(ent,ent.meshConvexes)
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
	--print("ent.TakedDamage",ent)
end)












local stressed

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

	local chips = ents.FindByClass("gmod_wire_expression2")
	for k,e2 in pairs(chips) do
		--e2:PCallHook( "destruct" )
	end

	chips = ents.FindByClass("starfall_processor")
	for _,sf in pairs(chips) do
		--sf:Remove()
	end

end











--hook.Remove("Tick","esrv_collisionCount-shouldberemoved")



--hook.Remove("ShouldCollide","esrv_collisionCount")
--hook.Remove("OnEntityCreated","esrv_collisionCount")
--hook.Remove("EntityRemoved","esrv_collisionCount")





--hook.Remove( "PlayerSpawn", "esrv_antilag-playercollisioncount")
--hook.Remove( "PlayerDisconnected", "esrv_antilag-playercollisioncount")
--hook.Remove("Tick","esrv_antilag")
