local trust = 0
local revive_physics = 0
timer.Create("simple_antilag_checks",5,0,function()
	if revive_physics == 0 then return end

	if revive_physics < CurTime() then
		revive_physics = 0
		trust = 0
		physenv.SetPhysicsPaused(false)
	end
end)

hook.Add("Tick", "esrv_simpleantilag", function ()
	if physenv.GetPhysicsPaused() then return end

	if num > 18 then
		trust = math.min(trust + 1,3)
	else
		trust = math.max(trust - 1,0)
	end

	if trust > 2 then
		physenv.SetPhysicsPaused(true)
		revive_physics = CurTime() + 5
	end
end)
