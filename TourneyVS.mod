return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`TourneyVS` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("TourneyVS", {
			mod_script       = "scripts/mods/TourneyVS/TourneyVS",
			mod_data         = "scripts/mods/TourneyVS/TourneyVS_data",
			mod_localization = "scripts/mods/TourneyVS/TourneyVS_localization",
		})
	end,
	packages = {
		"resource_packages/TourneyVS/TourneyVS",
	},
}
