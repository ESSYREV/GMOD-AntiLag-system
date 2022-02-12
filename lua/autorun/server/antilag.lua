--[[
	Советую поработать над ntime > число
	Изначально антилаг создавался на локальном сервере, 
	где, естественно, нагрузка меньше.
--]] 

local time = SysTime()
local alreadyLags = 0

local function checkLagProps()
    local tbl = {}

    local fnd = ents.GetAll()
    for i=1,#fnd do

        if not IsValid(fnd[i]:GetPhysicsObject()) then continue end

        if fnd[i]:GetPhysicsObject():GetStress() < 512 or not fnd[i]:CPPIGetOwner() then continue end
        local ent = fnd[i]:GetPhysicsObject()

        local owner = fnd[i]:CPPIGetOwner():GetName()

        if not tbl[owner] then    tbl[owner] = 0    end
        tbl[owner] = tbl[owner] + 1
        ent:Sleep()
        ent:EnableMotion(false)
    end

    local key = 0
    local players = 0
    for k, v in pairs( tbl ) do
       players = players + 1
       key = v + 1
    end

	key = key - 1
    if key <= 1 then return end

    local str = ""
    for k, v in pairs( tbl ) do
		str = str .. k .. " - " .. v .. "\n"
    end

    local ply = player.GetAll()
    for i=1,#ply do
        ply[i]:PrintMessage(3,"Было найдено "..key.." конфликтных пропов у "..players.." игроков! \n"..str)
    end


end

local function freezeAll()
    local fnd = ents.GetAll()
    for i=1,#fnd do
        if not IsValid(fnd[i]:GetPhysicsObject()) then continue end
        local ent = fnd[i]:GetPhysicsObject()
        ent:Sleep()
        ent:EnableMotion(false)
    end
    local ply = player.GetAll()
    for i=1,#ply do
        ply[i]:PrintMessage(3,"Заморозка всех пропов.") 
    end

    alreadyLags = alreadyLags - (alreadyLags/2)

end

local function E2stop()

    local fnd = ents.FindByClass("gmod_wire_expression2")
    for i=1,#fnd do
        fnd[i]:PCallHook( "destruct" )
    end

end

local function ExperementalFinder()

    local class = "prop_physics"
    local all = ents.FindByClass(class)
    local fnd = all[math.random(#all)]

    local owners = {}
    local needSendMsg = false

    local fnd = ents.FindInSphere( fnd:GetPos(), 45)

    if #fnd >= 15 then

        for i=1,(#fnd-#fnd/5) do

            local rand = fnd[math.random(#fnd)]

            if not IsValid(rand:GetPhysicsObject()) then continue end

            if rand:GetClass() == "prop_physics" then

                 local owner = tostring( fnd[i]:CPPIGetOwner() )
                 if not owners[owner] then owners[owner] = 0 end
                 owners[owner] = owners[owner] + 1; needSendMsg = true


                rand:Remove()

            end

        end

    end

    if not needSendMsg then return end

    local str = "На сервере обнаружено подозрение на попытку краша! \n Подозреваемые игроки: \n "
    for k, v in pairs( owners ) do
        if k == "nil" then continue end
        str = str .. k .. " (Подозреваемые пропы: "..v.. ")\n"
    end

    local ply = player.GetAll()
    for i=1,#ply do
        ply[i]:PrintMessage(3,str)
    end

end

hook.Add("Tick","esrvAntiLag",function()
    local ntime = SysTime() - time

    ntime = (ntime - ntime%0.001) * 1000

    if alreadyLags > 0.1 then alreadyLags = alreadyLags - 0.1 end
    if ntime < 10 or ntime >= 17 then alreadyLags = alreadyLags + 1 end
    
    alreadyLags = alreadyLags - alreadyLags%0.1
    if ntime > 100 or alreadyLags > 75 then
        checkLagProps() 
        if alreadyLags > 128 then
		freezeAll()
		E2stop()	
	end
    end

    if ntime > 700 then
        game.CleanUpMap()
        local ply = player.GetAll()
        for i=1,#ply do
            ply[i]:PrintMessage(3,"Самоуничтожение!!! Обнаружены сильные лаги!!!")
        end
    end

    time = SysTime()
end)


timer.Create( "esrv.AntiLag.TimerFinder_BadProps",3,0, function() 
    ExperementalFinder()
end)
