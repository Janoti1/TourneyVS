local mod = get_mod("TourneyVS")

--[[

    This is a mod adjusting behavior of the gamemode Versus in order to make it useable in a Tournament Setting

]]

--- Pause
mod.paused = false
mod.do_pause = function()
	if not Managers.player.is_server then
		mod:echo(mod:localize("not_server"))
		return
	end

	if mod.paused then
		Managers.state.debug:set_time_scale(13)
		mod.paused = false
		mod:echo(mod:localize("game_unpaused"))
	else
		Managers.state.debug:set_time_scale(6)
		mod.paused = true
		mod:echo(mod:localize("game_paused"))
	end
end
mod:command("pause", mod:localize("pause_command_description"), function() mod.do_pause() end)


-- 15 second spawns for skaven
GameModeSettings.versus.dark_pact_respawn_timers = {
    {
        max = 1,
        mid = 1,
    },
    {
        max = 3,
        mid = 3,
    },
    {
        max = 10, --14
        mid = 6, --8
    },
    {
        max = 15, -- 20
        mid = 9, -- 12
    },
}


--[[

    Notes:


    damage profile templates vs https://github.com/Aussiemon/Vermintide-2-Source-Code/blob/da0bbdaf6af1ca7e8c96e7892a3416a4aa8a7f87/scripts/settings/equipment/damage_profile_templates_dlc_vs.lua#L837
    attack templates vs https://github.com/Aussiemon/Vermintide-2-Source-Code/blob/da0bbdaf6af1ca7e8c96e7892a3416a4aa8a7f87/scripts/settings/equipment/attack_templates_dlc_vs.lua

]]

