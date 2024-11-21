local mod = get_mod("TourneyVS")

return {
	name = "TourneyVS",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "pause",
				type = "keybind",
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "do_pause",
				default_value = {},
				tootlip = "pause_keybind_description",
			}
		}
	}
}
