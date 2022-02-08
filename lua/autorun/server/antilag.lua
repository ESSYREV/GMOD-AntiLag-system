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

    if key <= 1 then return end

    local ply = player.GetAll()
    for i=1,#ply do
        ply[i]:PrintMessage(3,"Было найдено "..key.." конфликтных пропов у "..players.." игроков!")
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

end

local function E2stop()

    local fnd = ents.FindByClass("gmod_wire_expression2")
    for i=1,#fnd do
        fnd[i]:PCallHook( "destruct" )
    end

end

hook.Add("Tick","esrvAntiLag",function()
    local ntime = SysTime() - time

    ntime = (ntime - ntime%0.001) * 1000

    if alreadyLags > 0.1 then alreadyLags = alreadyLags - 0.1 end
    if ntime < 10 or ntime >= 17 then alreadyLags = alreadyLags + 1 end
    
    alreadyLags = alreadyLags - alreadyLags%0.1
    if ntime > 45 then
        checkLagProps() 
        --E2stop()
    end

    if ntime > 45 and alreadyLags > 95 then
        checkLagProps()
        freezeAll()
        E2stop()
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
print("antilag.lua loaded!")
