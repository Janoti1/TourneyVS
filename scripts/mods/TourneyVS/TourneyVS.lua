local mod = get_mod("TourneyVS")

--[[

    This is a mod adjusting behavior of the gamemode Versus in order to make it useable in a Tournament Setting

]]

--[[	
███╗░░░███╗░█████╗░██╗███╗░░██╗  ███████╗██╗░░░██╗███╗░░██╗░█████╗░████████╗██╗░█████╗░███╗░░██╗░██████╗
████╗░████║██╔══██╗██║████╗░██║  ██╔════╝██║░░░██║████╗░██║██╔══██╗╚══██╔══╝██║██╔══██╗████╗░██║██╔════╝
██╔████╔██║███████║██║██╔██╗██║  █████╗░░██║░░░██║██╔██╗██║██║░░╚═╝░░░██║░░░██║██║░░██║██╔██╗██║╚█████╗░
██║╚██╔╝██║██╔══██║██║██║╚████║  ██╔══╝░░██║░░░██║██║╚████║██║░░██╗░░░██║░░░██║██║░░██║██║╚████║░╚═══██╗
██║░╚═╝░██║██║░░██║██║██║░╚███║  ██║░░░░░╚██████╔╝██║░╚███║╚█████╔╝░░░██║░░░██║╚█████╔╝██║░╚███║██████╔╝
╚═╝░░░░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝  ╚═╝░░░░░░╚═════╝░╚═╝░░╚══╝░╚════╝░░░░╚═╝░░░╚═╝░╚════╝░╚═╝░░╚══╝╚═════╝░
]]

-- Text Localization
local _language_id = Application.user_setting("language_id")
local _localization_database = {}
local buff_perks = require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")

mod._quick_localize = function (self, text_id)
    local mod_localization_table = _localization_database
    if mod_localization_table then
        local text_translations = mod_localization_table[text_id]
        if text_translations then
            return text_translations[_language_id] or text_translations["en"]
        end
    end
end
mod:hook("Localize", function(func, text_id)
    local str = mod:_quick_localize(text_id)
    if str then return str end
    return func(text_id)
end)
function mod.add_text(self, text_id, text)
    if type(text) == "table" then
        _localization_database[text_id] = text
    else
        _localization_database[text_id] = {
            en = text
        }
    end
end
function mod.add_talent_text(self, talent_name, name, description)
    mod:add_text(talent_name, name)
    mod:add_text(talent_name .. "_desc", description)
end

-- Buff and Talent Functions
local function is_local(unit)
	local player = Managers.player:owner(unit)

	return player and not player.remote
end
local function merge(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end
function is_at_inn()
    local game_mode = Managers.state.game_mode
    if not game_mode then return nil end
    return game_mode:game_mode_key() == "inn"
end
function mod.modify_talent_buff_template(self, hero_name, buff_name, buff_data, extra_data)   
    local new_talent_buff = {
        buffs = {
            merge({ name = buff_name }, buff_data),
        },
    }
    if extra_data then
        new_talent_buff = merge(new_talent_buff, extra_data)
    elseif type(buff_data[1]) == "table" then
        new_talent_buff = {
            buffs = buff_data,
        }
        if new_talent_buff.buffs[1].name == nil then
            new_talent_buff.buffs[1].name = buff_name
        end
    end

    local original_buff = TalentBuffTemplates[hero_name][buff_name]
    local merged_buff = original_buff
    for i=1, #original_buff.buffs do
        if new_talent_buff.buffs[i] then
            merged_buff.buffs[i] = merge(original_buff.buffs[i], new_talent_buff.buffs[i])
        elseif original_buff[i] then
            merged_buff.buffs[i] = merge(original_buff.buffs[i], new_talent_buff.buffs)
        else
            merged_buff.buffs = merge(original_buff.buffs, new_talent_buff.buffs)
        end
    end

    TalentBuffTemplates[hero_name][buff_name] = merged_buff
    BuffTemplates[buff_name] = merged_buff
end
function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end
function mod.set_talent(self, career_name, tier, index, talent_name, talent_data)
    local career_settings = CareerSettings[career_name]
    local hero_name = career_settings.profile_name
    local talent_tree_index = career_settings.talent_tree_index
    
    local talent_lookup = TalentIDLookup[talent_name]
    local talent_id
    if talent_lookup == nil then
        talent_id = #Talents[hero_name] + 1
    else
        talent_id = talent_lookup.talent_id
    end

    Talents[hero_name][talent_id] = merge({
        name = talent_name,
        description = talent_name .. "_desc",
        icon = "icons_placeholder",
        num_ranks = 1,
        buffer = "both",
        requirements = {},
        description_values = {},
        buffs = {},
        buff_data = {},
    }, talent_data)
    TalentTrees[hero_name][talent_tree_index][tier][index] = talent_name
    TalentIDLookup[talent_name] = {
        talent_id = talent_id,
        hero_name = hero_name
    }
    -- mod:echo("-----------------------")
    -- mod:echo("Buff: " .. dump(talent_data.buffs))
    -- mod:echo("Talent lookup for " .. hero_name .. ": " .. talent_name .. " => " .. talent_id)
end
function mod.add_talent(self, career_name, tier, index, new_talent_name, new_talent_data)
    local career_settings = CareerSettings[career_name]
    local hero_name = career_settings.profile_name
    local talent_tree_index = career_settings.talent_tree_index
  
    local new_talent_index = #Talents[hero_name] + 1

    Talents[hero_name][new_talent_index] = merge({
        name = new_talent_name,
        description = new_talent_name .. "_desc",
        icon = "icons_placeholder",
        num_ranks = 1,
        buffer = "both",
        requirements = {},
        description_values = {},
        buffs = {},
        buff_data = {},
    }, new_talent_data)

    TalentTrees[hero_name][talent_tree_index][tier][index] = new_talent_name
    TalentIDLookup[new_talent_name] = {
        talent_id = new_talent_index,
        hero_name = hero_name
    }
end
function mod.modify_talent(self, career_name, tier, index, new_talent_data)
    local career_settings = CareerSettings[career_name]
    local hero_name = career_settings.profile_name
    local talent_tree_index = career_settings.talent_tree_index

    local old_talent_name = TalentTrees[hero_name][talent_tree_index][tier][index]
    local old_talent_id_lookup = TalentIDLookup[old_talent_name]
    local old_talent_id = old_talent_id_lookup.talent_id
    local old_talent_data = Talents[hero_name][old_talent_id]

    Talents[hero_name][old_talent_id] = merge(old_talent_data, new_talent_data)
end
function mod.add_talent_buff_template(self, hero_name, buff_name, buff_data, extra_data)
    local new_talent_buff = {
        buffs = {
            merge({ name = buff_name }, buff_data),
        },
    }
    if extra_data then
        new_talent_buff = merge(new_talent_buff, extra_data)
    elseif type(buff_data[1]) == "table" then
        new_talent_buff = {
            buffs = buff_data,
        }
        if new_talent_buff.buffs[1].name == nil then
            new_talent_buff.buffs[1].name = buff_name
        end
    end
    TalentBuffTemplates[hero_name][buff_name] = new_talent_buff
    BuffTemplates[buff_name] = new_talent_buff
    local index = #NetworkLookup.buff_templates + 1
    NetworkLookup.buff_templates[index] = buff_name
    NetworkLookup.buff_templates[buff_name] = index
end
function mod.add_buff_template(self, buff_name, buff_data, extra_data)
    local new_buff = {
        buffs = {
            merge({ name = buff_name }, buff_data),
        },
    }
    if extra_data then
        new_buff = merge(new_buff, extra_data)
    end
    BuffTemplates[buff_name] = new_buff
    local index = #NetworkLookup.buff_templates + 1
    NetworkLookup.buff_templates[index] = buff_name
    NetworkLookup.buff_templates[buff_name] = index
end
function mod.add_buff(self, owner_unit, buff_name)
    if Managers.state.network ~= nil then
        local network_manager = Managers.state.network
        local network_transmit = network_manager.network_transmit

        local unit_object_id = network_manager:unit_game_object_id(owner_unit)
        local buff_template_name_id = NetworkLookup.buff_templates[buff_name]
        local is_server = Managers.player.is_server

        if is_server then
            local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")

            buff_extension:add_buff(buff_name)
            network_transmit:send_rpc_clients("rpc_add_buff", unit_object_id, buff_template_name_id, unit_object_id, 0, false)
        else
            network_transmit:send_rpc_server("rpc_add_buff", unit_object_id, buff_template_name_id, unit_object_id, 0, true)
        end
    end
end
function mod.add_buff_function(self, name, func)
    BuffFunctionTemplates.functions[name] = func
end
function mod.add_proc_function(self, name, func)
    ProcFunctions[name] = func
end
function mod.add_explosion_template(self, explosion_name, data)
    ExplosionTemplates[explosion_name] = merge({ name = explosion_name}, data)
    local index = #NetworkLookup.explosion_templates + 1
    NetworkLookup.explosion_templates[index] = explosion_name
    NetworkLookup.explosion_templates[explosion_name] = index
end

-- Damage Profile Templates
NewDamageProfileTemplates = NewDamageProfileTemplates or {}


--[[
░██████╗░░█████╗░██╗░░░░░
██╔═══██╗██╔══██╗██║░░░░░
██║██╗██║██║░░██║██║░░░░░
╚██████╔╝██║░░██║██║░░░░░
░╚═██╔═╝░╚█████╔╝███████╗
░░░╚═╝░░░░╚════╝░╚══════╝
]]

--- Pause
mod.paused = false
mod.do_pause = function()
	if not Managers.player.is_server then
		mod:echo(mod:localize("not_server"))
        mod:chat_broadcast(mod:localize("inform_host"))
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

-- Suicide
-- Cooldown?
mod:command("die", mod:localize("die_command_description"), function()
	-- check if you are in the keep
	if DamageUtils.is_in_inn then
		mod:echo(mod:localize("die_cant_die"))
		return
	end

	-- check if you are a player
	local peer_id = Network.peer_id()
	local party_id = Managers.mechanism:reserved_party_id_by_peer(peer_id)
	local party_manager = Managers.party
	local party = party_manager:get_party(party_id)
	local side = Managers.state.side.side_by_party[party]
	local is_dark_pact = side and side:name() == "dark_pact"
	if not is_dark_pact then
		mod:echo(mod:localize("die_cant_die_player"))
		return
	end

	local player_unit = Managers.player:local_player().player_unit
	local death_system = Managers.state.entity:system("death_system")
	death_system:kill_unit(player_unit, {})
	mod:echo(mod:localize("die_die"))
end)

-- picking characters speed reduced
GameModeSettings.versus.character_picking_settings = {
    closing_time = 1,
    parading_duration = 1,
    player_pick_time = 5,
    startup_time = 3,
}
-- start game duration lowered
GameModeSettings.versus.pre_start_round_duration = 15
GameModeSettings.versus.initial_set_pre_start_duration = 20


--[[
░██████╗░░█████╗░███╗░░░███╗███████╗  ███╗░░░███╗░█████╗░██████╗░███████╗
██╔════╝░██╔══██╗████╗░████║██╔════╝  ████╗░████║██╔══██╗██╔══██╗██╔════╝
██║░░██╗░███████║██╔████╔██║█████╗░░  ██╔████╔██║██║░░██║██║░░██║█████╗░░
██║░░╚██╗██╔══██║██║╚██╔╝██║██╔══╝░░  ██║╚██╔╝██║██║░░██║██║░░██║██╔══╝░░
╚██████╔╝██║░░██║██║░╚═╝░██║███████╗  ██║░╚═╝░██║╚█████╔╝██████╔╝███████╗
░╚═════╝░╚═╝░░╚═╝╚═╝░░░░░╚═╝╚══════╝  ╚═╝░░░░░╚═╝░╚════╝░╚═════╝░╚══════╝
]]

-- 15 second spawns for skaven
GameModeSettings.versus.dark_pact_minimum_spawn_time = 0
GameModeSettings.versus.dark_pact_respawn_timers = {
	{
		max = 1,
		min = 1,
	},
	{
		max = 3,
		min = 3,
	},
	{
		max = 10, -- 14
		min = 6, -- 8
	},
	{
		max = 15, -- 20
		min = 9, -- 12
	},
}
-- set maximum amount of wounds to 1
GameModeSettings.versus.player_wounds = {
    dark_pact = 1,
    heroes = 2,
    spectators = 0,
}
-- Remove loot rats from the game
mod.loot_rats_backup = Breeds.skaven_loot_rat
mod.remove_loot_rats = function()
    if Managers.mechanism:current_mechanism_name() == "versus" then
        Breeds.skaven_loot_rat = Breeds.critter_pig
    else
        Breeds.skaven_loot_rat = mod.loot_rats_backup
    end
end

-- Horde timers lowered
--[[
local settings = require("scripts/settings/versus_horde_ability_settings")
-- Horde ability stuff
settings.cooldown = 150 -- 300
settings.team_size_difference_recharge_modifier = {
    [0] = 1, -- 4
    1.75, -- 3
    2.75, -- 2 
    4, -- 1 person
}
]]

--[[
██████╗░░█████╗░██╗░░░░░░█████╗░███╗░░██╗░█████╗░███████╗
██╔══██╗██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗██╔════╝
██████╦╝███████║██║░░░░░███████║██╔██╗██║██║░░╚═╝█████╗░░
██╔══██╗██╔══██║██║░░░░░██╔══██║██║╚████║██║░░██╗██╔══╝░░
██████╦╝██║░░██║███████╗██║░░██║██║░╚███║╚█████╔╝███████╗
╚═════╝░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝░╚════╝░╚══════╝
]]

--[[

	Footknight

]]

-- comrades 50% dr changed to 20% dr (overriding adventure)
mod:modify_talent_buff_template("empire_soldier", "markus_knight_guard_defence_buff", {
    mechanism_overrides = {
		versus = {
			multiplier = -0.2,
		}
	}
})
mod:modify_talent("es_knight", 4, 3, {
	mechanism_overrides = {
		versus = {
			description_values = {
				{
					value_type = "percent",
					value = 0.1
				},
				{
					value_type = "percent",
					value = 0.2
				},
				{
					value_type = "percent",
					value = 0.1
				}
			},
		}
	}
})

-- numb to pain 1 sec instead of 3
mod:modify_talent_buff_template("empire_soldier", "markus_knight_ability_invulnerability_buff", {
    mechanism_overrides = {
		versus = {
			duration = 1,
		}
	}
})
mod:modify_talent("es_knight", 6, 1, {
	mechanism_overrides = {
		versus = {
			description_values = {
				{
					value = 1
				}
			},
		}
	}
})

-- Blunderbus reduced stagger and damage a lot
-- increase damage against monster a little
NewDamageProfileTemplates.shot_shotgun_blunderbuss_vs_tvs = {
    charge_value = "instant_projectile",
		no_stagger_damage_reduction_ranged = true,
		shield_break = true,
		critical_strike = {
			attack_armor_power_modifer = {
				1,
				0.3,
				0.5,
				1,
				1,
				0,
			},
			impact_armor_power_modifer = {
				1,
				1,
				1,
				1,
				1,
				0.5,
			},
		},
		armor_modifier_near = {
			attack = {
				0.8, --1
				0.4,
				1, --0.4,
				0.75,
				1,
				0,
			},
			impact = {
				1,
				1,
				3,
				0,
				1,
				0.75,
			},
		},
		armor_modifier_far = {
			attack = {
				0.8, --1
				0.2,
				0.4, --0.25,
				0.75,
				1,
				0,
			},
			impact = {
				1,
				0.7,
				0.5,
				0,
				1,
				0.5,
			},
		},
		cleave_distribution = {
			attack = 0.1,
			impact = 0.1,
		},
		default_target = {
			attack_template = "shot_shotgun_vs",
			boost_curve_coefficient = 0.75,
			boost_curve_coefficient_headshot = 0.75,
			boost_curve_type = "linesman_curve",
			power_distribution_near = {
				attack = 0.1, --0.25,
				impact = 0.1, --0.3,
			},
			power_distribution_far = {
				attack = 0.09, --0.15,
				impact = 0.1, --0.15,
			},
			range_modifier_settings = {
				dropoff_end = 20,
				dropoff_start = 8,
			},
		}
}
Weapons.blunderbuss_template_1_vs.actions.action_one.default.damage_profile = "shot_shotgun_blunderbuss_vs_tvs"

--[[

	Ranger Veteran

]]
-- Grudgeraker reduce stagger and damage a little
-- reduced overall damage
-- increased monster and armor damage slightly for better bp against hook and gunners
NewDamageProfileTemplates.shot_shotgun_grudgeraker_vs_tvs = {
    charge_value = "instant_projectile",
		no_stagger_damage_reduction_ranged = true,
		shield_break = true,
		critical_strike = {
			attack_armor_power_modifer = {
				1,
				0.3,
				0.5,
				1,
				1,
				0,
			},
			impact_armor_power_modifer = {
				1,
				1,
				1,
				1,
				1,
				0.5,
			},
		},
		armor_modifier_near = {
			attack = {
				1,
				0.2, --0.4
				0.6, --0.4,
				0.75,
				1,
				0,
			},
			impact = {
				1,
				1,
				3,
				0,
				1,
				0.75,
			},
		},
		armor_modifier_far = {
			attack = {
				1,
				0.15, --0.2
				0.4, --0.25
				0.75,
				1,
				0,
			},
			impact = {
				1,
				0.7,
				0.5,
				0,
				1,
				0.5,
			},
		},
		cleave_distribution = {
			attack = 0.1,
			impact = 0.1,
		},
		default_target = {
			attack_template = "shot_shotgun_vs",
			boost_curve_coefficient = 0.75,
			boost_curve_coefficient_headshot = 0.75,
			boost_curve_type = "linesman_curve",
			power_distribution_near = {
				attack = 0.15, --0.25,
				impact = 0.1, --0.3,
			},
			power_distribution_far = {
				attack = 0.12, --0.15,
				impact = 0.1, --0.15,
			},
			range_modifier_settings = {
				dropoff_end = 20,
				dropoff_start = 8,
			},
		}
}
Weapons.grudge_raker_template_1_vs.actions.action_one.default.damage_profile = "shot_shotgun_grudgeraker_vs_tvs"


--[[

    Engineer

]]
-- Remove Trollhammer from IB and Engi
ItemMasterList.vs_dr_deus_01.can_wield = {}

-- remove holding multiple bombs
CareerSettings.dr_engineer.additional_item_slots = {}

--[[

    Warrior Priest

]]
-- reduce the damage of WP bubble
-- reduced it by 66% against monsters
DLCSettings.bless.buff_templates.victor_priest_nuke_dot.buffs[1].mechanism_overrides.versus = {
    damage_profile = "victor_priest_nuke_dot_vs",
    duration = 1.5, -- 5
    time_between_dot_damages = 1, -- 0.7
    update_start_delay = 1 -- 0.7
}
DamageProfileTemplates.victor_priest_nuke_dot_vs.armor_modifier.attack[3] = 1.0


--[[
███████╗██╗██╗░░██╗███████╗░██████╗
██╔════╝██║╚██╗██╔╝██╔════╝██╔════╝
█████╗░░██║░╚███╔╝░█████╗░░╚█████╗░
██╔══╝░░██║░██╔██╗░██╔══╝░░░╚═══██╗
██║░░░░░██║██╔╝╚██╗███████╗██████╔╝
╚═╝░░░░░╚═╝╚═╝░░╚═╝╚══════╝╚═════╝░
]]
-- Crash on Game ending
-- attempt of fixing it without a FS hotfix by Aledend
mod:hook(StateInGameRunning, "_setup_end_of_level_UI ", function(self)

	if script_data.disable_end_screens then
		Managers.state.network.network_transmit:send_rpc_server("rpc_is_ready_for_transition")
	elseif not Managers.state.game_mode:setting("skip_level_end_view") then
		local game_won = not self.game_lost and not self.game_tied
		local game_mode_key = Managers.state.game_mode:game_mode_key()
		local mechanism_name = Managers.mechanism:current_mechanism_name()
		local is_versus = mechanism_name == "versus"
		local hero_name
		local peer_id = Network.peer_id()
		local profile_index = self.profile_synchronizer:get_persistent_profile_index_reservation(peer_id)

		if profile_index and profile_index ~= 0 then
			local profile = SPProfiles[profile_index]

			hero_name = profile.display_name
		end

		local level_end_view_context = {}

		level_end_view_context.world_manager = Managers.world
		level_end_view_context.is_server = self.is_server
		level_end_view_context.is_quickplay = self.is_quickplay
		level_end_view_context.peer_id = peer_id
		level_end_view_context.local_player_hero_name = hero_name
		level_end_view_context.game_won = game_won
		level_end_view_context.game_mode_key = game_mode_key
		level_end_view_context.difficulty = Managers.state.difficulty:get_difficulty()
		level_end_view_context.level_key = Managers.state.game_mode:level_key()
		level_end_view_context.weave_personal_best_achieved = self._weave_personal_best_achieved
		level_end_view_context.completed_weave = self._completed_weave
		level_end_view_context.profile_synchronizer = self.profile_synchronizer
		level_end_view_context.challenge_progression_status = {
			start_progress = Managers.mechanism:get_stored_challenge_progression_status(),
			end_progress = Managers.mechanism:get_challenge_progression_status()
		}

		if is_versus then
			level_end_view_context.party_composition = Managers.party:get_party_composition()
		end

		if self.is_server then
			local players_session_score = Managers.mechanism:get_players_session_score(self.statistics_db, self.profile_synchronizer, self._saved_scoreboard_stats)

			Managers.mechanism:sync_players_session_score(players_session_score)

			level_end_view_context.players_session_score = players_session_score
		end

		self._weave_personal_best_achieved = nil
		self._completed_weave = nil

		--[[if not self._booted_eac_untrusted then
			local level, start_experience, start_experience_pool = self.rewards:get_level_start()
			local versus_level, versus_start_experience = self.rewards:get_versus_level_start()
			local win_track_start_experience = self.rewards:get_win_track_experience_start()
			local rewards, end_of_level_rewards_arguments = self.rewards:get_rewards()
			local win_conditions = mechanism_name == "versus" and Managers.mechanism:game_mechanism():win_conditions()

			level_end_view_context.rewards = {
				end_of_level_rewards = rewards and table.clone(rewards) or {},
				level_start = {
					level,
					start_experience,
					start_experience_pool
				},
				versus_level_start = {
					versus_level,
					versus_start_experience
				},
				mission_results = table.clone(self.rewards:get_mission_results()),
				win_track_start_experience = win_track_start_experience,
				team_scores = win_conditions and win_conditions:get_total_scores()
			}
			level_end_view_context.end_of_level_rewards_arguments = end_of_level_rewards_arguments and table.clone(end_of_level_rewards_arguments) or {}
		end]]

		level_end_view_context.level_end_view = Managers.mechanism:get_level_end_view()
		self.parent.parent.loading_context.level_end_view_context = level_end_view_context

		if IS_PS4 then
			Managers.account:set_presence("dice_game")
		end

		if Managers.chat:chat_is_focused() then
			Managers.chat.chat_gui:block_input()
		end
	end

	self.has_setup_end_of_level = true

end)
--[[
mod:hook(EndViewStateScoreVS, "create_ui_elements", function (self, params)

	local state, reason, cause, violation = EAC.state()
	if state == "untrusted" or state == "banned" then
		Managers.state.game_mode:start_specific_level("carousel_hub")
	end

end)
mod:hook(LevelEndViewVersus, "setup_pages", function (self, game_won, rewards)
	mod:echo("Setting up untrusted state.")
	local index_by_state_name = LevelEndViewVersus:_setup_pages_untrusted()
	return index_by_state_name
end)]]




mod.on_game_state_changed = function(status, state_name)
	if status == "enter" and state_name == "StateIngame" then
        mod.remove_loot_rats()
	end
end





-- New Damage Profile Templates
--Add the new templates to the DamageProfile templates
--Setup proper linkin in NetworkLookup
for key, _ in pairs(NewDamageProfileTemplates) do
    i = #NetworkLookup.damage_profiles + 1
    NetworkLookup.damage_profiles[i] = key
    NetworkLookup.damage_profiles[key] = i
end
--Merge the tables together
table.merge_recursive(DamageProfileTemplates, NewDamageProfileTemplates)
--Do FS things
for name, damage_profile in pairs(DamageProfileTemplates) do
	if not damage_profile.targets then
		damage_profile.targets = {}
	end

	fassert(damage_profile.default_target, "damage profile [\"%s\"] missing default_target", name)

	if type(damage_profile.critical_strike) == "string" then
		local template = PowerLevelTemplates[damage_profile.critical_strike]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.critical_strike)

		damage_profile.critical_strike = template
	end

	if type(damage_profile.cleave_distribution) == "string" then
		local template = PowerLevelTemplates[damage_profile.cleave_distribution]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.cleave_distribution)

		damage_profile.cleave_distribution = template
	end

	if type(damage_profile.armor_modifier) == "string" then
		local template = PowerLevelTemplates[damage_profile.armor_modifier]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.armor_modifier)

		damage_profile.armor_modifier = template
	end

	if type(damage_profile.default_target) == "string" then
		local template = PowerLevelTemplates[damage_profile.default_target]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.default_target)

		damage_profile.default_target = template
	end

	if type(damage_profile.targets) == "string" then
		local template = PowerLevelTemplates[damage_profile.targets]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.targets)

		damage_profile.targets = template
	end
end

local no_damage_templates = {}
for name, damage_profile in pairs(DamageProfileTemplates) do
	local no_damage_name = name .. "_no_damage"

	if not DamageProfileTemplates[no_damage_name] then
		local no_damage_template = table.clone(damage_profile)

		if no_damage_template.targets then
			for _, target in ipairs(no_damage_template.targets) do
				if target.power_distribution then
					target.power_distribution.attack = 0
				end
			end
		end

		if no_damage_template.default_target.power_distribution then
			no_damage_template.default_target.power_distribution.attack = 0
		end

		no_damage_templates[no_damage_name] = no_damage_template
	end
end

DamageProfileTemplates = table.merge(DamageProfileTemplates, no_damage_templates)

local MeleeBuffTypes = MeleeBuffTypes or {
	MELEE_1H = true,
	MELEE_2H = true
}
local RangedBuffTypes = RangedBuffTypes or {
	RANGED_ABILITY = true,
	RANGED = true
}
local WEAPON_DAMAGE_UNIT_LENGTH_EXTENT = 1.919366
local TAP_ATTACK_BASE_RANGE_OFFSET = 0.6
local HOLD_ATTACK_BASE_RANGE_OFFSET = 0.65

for item_template_name, item_template in pairs(Weapons) do
	item_template.name = item_template_name
	item_template.crosshair_style = item_template.crosshair_style or "dot"
	local attack_meta_data = item_template.attack_meta_data
	local tap_attack_meta_data = attack_meta_data and attack_meta_data.tap_attack
	local hold_attack_meta_data = attack_meta_data and attack_meta_data.hold_attack
	local set_default_tap_attack_range = tap_attack_meta_data and tap_attack_meta_data.max_range == nil
	local set_default_hold_attack_range = hold_attack_meta_data and hold_attack_meta_data.max_range == nil

	if RangedBuffTypes[item_template.buff_type] and attack_meta_data then
		attack_meta_data.effective_against = attack_meta_data.effective_against or 0
		attack_meta_data.effective_against_charged = attack_meta_data.effective_against_charged or 0
		attack_meta_data.effective_against_combined = bit.bor(attack_meta_data.effective_against, attack_meta_data.effective_against_charged)
	end

	if MeleeBuffTypes[item_template.buff_type] then
		fassert(attack_meta_data, "Missing attack metadata for weapon %s", item_template_name)
		fassert(tap_attack_meta_data, "Missing tap_attack metadata for weapon %s", item_template_name)
		fassert(hold_attack_meta_data, "Missing hold_attack metadata for weapon %s", item_template_name)
		fassert(tap_attack_meta_data.arc, "Missing arc parameter in tap_attack metadata for weapon %s", item_template_name)
		fassert(hold_attack_meta_data.arc, "Missing arc parameter in hold_attack metadata for weapon %s", item_template_name)
	end

	local actions = item_template.actions

	for action_name, sub_actions in pairs(actions) do
		for sub_action_name, sub_action_data in pairs(sub_actions) do
			local lookup_data = {
				item_template_name = item_template_name,
				action_name = action_name,
				sub_action_name = sub_action_name
			}
			sub_action_data.lookup_data = lookup_data
			local action_kind = sub_action_data.kind
			local action_assert_func = ActionAssertFuncs[action_kind]

			if action_assert_func then
				action_assert_func(item_template_name, action_name, sub_action_name, sub_action_data)
			end

			if action_name == "action_one" then
				local range_mod = sub_action_data.range_mod or 1

				if set_default_tap_attack_range and string.find(sub_action_name, "light_attack") then
					local current_attack_range = tap_attack_meta_data.max_range or math.huge
					local tap_attack_range = TAP_ATTACK_BASE_RANGE_OFFSET + WEAPON_DAMAGE_UNIT_LENGTH_EXTENT * range_mod
					tap_attack_meta_data.max_range = math.min(current_attack_range, tap_attack_range)
				elseif set_default_hold_attack_range and string.find(sub_action_name, "heavy_attack") then
					local current_attack_range = hold_attack_meta_data.max_range or math.huge
					local hold_attack_range = HOLD_ATTACK_BASE_RANGE_OFFSET + WEAPON_DAMAGE_UNIT_LENGTH_EXTENT * range_mod
					hold_attack_meta_data.max_range = math.min(current_attack_range, hold_attack_range)
				end
			end

			local impact_data = sub_action_data.impact_data

			if impact_data then
				local pickup_settings = impact_data.pickup_settings

				if pickup_settings then
					local link_hit_zones = pickup_settings.link_hit_zones

					if link_hit_zones then
						for i = 1, #link_hit_zones, 1 do
							local hit_zone_name = link_hit_zones[i]
							link_hit_zones[hit_zone_name] = true
						end
					end
				end
			end
		end
	end
end



--[[

	local peer_id = Network.peer_id()
	local party_id = Managers.mechanism:reserved_party_id_by_peer(peer_id)
	local party_manager = Managers.party
	local party = party_manager:get_party(party_id)
	local side = Managers.state.side.side_by_party[party]
	local is_dark_pact = side and side:name() == "dark_pact"

	mod:echo("Dark Pact: " .. tostring(is_dark_pact))

	local mod = get_mod("TourneyVS")
	local trust = LevelEndViewVersus._is_untrusted
	mod:echo("Trust status: " .. tostring(trust))

GUID: 968afaab-1ae9-4483-8f8e-2a36bbf28807
Log File: 
Info Type: 
-----------------------------------------------
[Script Error]: ...ts/ui/views/level_end/states/end_view_state_score_vs.lua:115: attempt to index field 'rewards' (a nil value)
-----------------------------------------------
[Crash Link]:
crashify://968afaab-1ae9-4483-8f8e-2a36bbf28807

]]

