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
mod:command("die", mod:localize("die_command_description"), function()
	if DamageUtils.is_in_inn then
		mod:echo(mod:localize("die_cant_die"))
		return
	end

	local player_unit = Managers.player:local_player().player_unit
	local death_system = Managers.state.entity:system("death_system")
	death_system:kill_unit(player_unit, {})
	mod:echo(mod:localize("die_die"))
end)


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
mod.remove_loot_rats = function()
    if Managers.mechanism:current_mechanism_name() == "versus" then
        Breeds.skaven_loot_rat = Breeds.critter_pig
    else
        Breeds.skaven_loot_rat = Breeds.skaven_loot_rat
    end
end



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

-- comrades 50% dr changed to 20% dr
mod:add_talent_buff_template("empire_soldier", "markus_knight_guard_defence_tvs", {
    multiplier = -0.2,
    remove_buff_func = "remove_aura_buff",
    stat_buff = "damage_taken",
    update_func = "activate_buff_on_closest_distance",
    range = 5,
})
mod:modify_talent("es_knight", 5, 3, {
    buffer = "both",
    description = "markus_knight_guard_desc",
    icon = "markus_knight_passive_power_increase",
    name = "markus_knight_guard",
    num_ranks = 1,
    description_values = {
        {
            value_type = "percent",
            value = 0.1,
        },
        {
            value_type = "percent",
            value = 0.2,
        },
        {
            value_type = "percent",
            value = 0.1,
        },
    },
    buffs = {
        "markus_knight_guard",
        "markus_knight_guard_defence",
    },
	mechanism_overrides = {
		versus = {
			description = "markus_knight_guard_desc_tvs",
			buffs = {
				"markus_knight_guard",
				"markus_knight_guard_defence_tvs",
			}
		}
	}
})
mod:add_text("markus_knight_guard_desc_tvs", "Kruber gains 10.0% increased power. The closest ally to Kruber gains 20.0% damage reduction and 10.0% increased power. Passive aura from Protective Presence no longer affects allies.")

-- numb to pain 1 sec instead of 3
mod:modify_talent("es_knight", 6, 1, {
	mechanism_overrides = {
		versus = {
			description = "markus_knight_ability_invulnerability_desc_tvs",
			buffs = {
				"markus_knight_guard",
				"markus_knight_guard_defence_tvs",
			}
		}
	}
})
mod:add_text("markus_knight_ability_invulnerability_desc_tvs", "Valiant Charge grants invulnerability for 1 second.")

-- Blunderbus reduced stagger
-- https://github.com/Aussiemon/Vermintide-2-Source-Code/blob/da0bbdaf6af1ca7e8c96e7892a3416a4aa8a7f87/scripts/settings/equipment/item_master_list_carousel.lua#L414
--blunderbuss_template_1_vs -> Weapon Template
--AttackTemplates.shot_shotgun_vs.ranged_stagger = false --true
--AttackTemplates.shot_shotgun_vs.stagger_value = 1 --2
NewDamageProfileTemplate.shot_shotgun_vs_tvs = {
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
				0.4,
				0.4,
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
				0.2,
				0.25,
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
				attack = 0.1, --0.15,
				impact = 0.1, --0.15,
			},
			range_modifier_settings = drop_off_ranges.blunderbuss_dropoff_ranges,
		}
}
Weapons.blunderbuss_template_1_vs.actions.action_one.default.damage_profile = "shot_shotgun_vs_tvs"

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
require("scripts/settings/profiles/career_constants")
local stagger_types = require("scripts/utils/stagger_types")
local buff_perks = require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")
local settings = DLCSettings.bless
settings.buff_templates.victor_priest_nuke_dot.buffs[1].mechanism_overrides.versus = {
    damage_profile = "victor_priest_nuke_dot_vs",
    duration = 1.5, -- 5
    time_between_dot_damages = 1, -- 0.7
    update_start_delay = 1 -- 0.7
}


--[[
███████╗██╗██╗░░██╗███████╗░██████╗
██╔════╝██║╚██╗██╔╝██╔════╝██╔════╝
█████╗░░██║░╚███╔╝░█████╗░░╚█████╗░
██╔══╝░░██║░██╔██╗░██╔══╝░░░╚═══██╗
██║░░░░░██║██╔╝╚██╗███████╗██████╔╝
╚═╝░░░░░╚═╝╚═╝░░╚═╝╚══════╝╚═════╝░
]]
-- Crash on Game ending
-- TODO


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

    Notes:


    damage profile templates vs https://github.com/Aussiemon/Vermintide-2-Source-Code/blob/da0bbdaf6af1ca7e8c96e7892a3416a4aa8a7f87/scripts/settings/equipment/damage_profile_templates_dlc_vs.lua#L837
    attack templates vs https://github.com/Aussiemon/Vermintide-2-Source-Code/blob/da0bbdaf6af1ca7e8c96e7892a3416a4aa8a7f87/scripts/settings/equipment/attack_templates_dlc_vs.lua

]]

