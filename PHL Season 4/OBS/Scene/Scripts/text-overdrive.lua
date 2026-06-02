-- OBS Lua Script: Force multiple text sources to refresh every frame

obs = obslua
source_names = {}  -- table to store up to 4 text source names

-- Description shown in Scripts dialog
function script_description()
	return "This script lets you select up to 4 text sources to force them to reread files every frame instead of once per second."
end

-- Called when script settings change
function script_update(settings)
	source_names = {}  -- reset
	for i = 1, 4 do
		local s = obs.obs_data_get_string(settings, "source"..i)
		if s ~= nil and s ~= "" then
			table.insert(source_names, s)
		end
	end
end

-- Define the properties shown in the Scripts dialog
function script_properties()
	local props = obs.obs_properties_create()
	local sources = obs.obs_enum_sources()
	
	for i = 1, 4 do
		local p = obs.obs_properties_add_list(
			props,
			"source"..i,
			"Text Source #" .. i,
			obs.OBS_COMBO_TYPE_EDITABLE,
			obs.OBS_COMBO_FORMAT_STRING
		)
		if sources ~= nil then
			for _, source in ipairs(sources) do
				local source_id = obs.obs_source_get_id(source)
				if source_id == "text_gdiplus" or source_id == "text_ft2_source" or source_id == "text_pango_source" then
					local name = obs.obs_source_get_name(source)
					obs.obs_property_list_add_string(p, name, name)
				end
			end
		end
	end
	
	if sources ~= nil then
		obs.source_list_release(sources)
	end
	
	return props
end

-- Called every frame
function script_tick(seconds)
	for _, source_name in ipairs(source_names) do
		local source = obs.obs_get_source_by_name(source_name)
		if source ~= nil then
			local settings = obs.obs_source_get_settings(source)
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end
	end
end
