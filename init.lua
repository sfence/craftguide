local craftguide, datas, npp = {}, {}, 8*3
local min, ceil = math.min, math.ceil

local group_stereotypes = {
	wool	     = "wool:white",
	dye	     = "dye:white",
	water_bucket = "bucket:bucket_water",
	vessel	     = "vessels:glass_bottle",
	coal	     = "default:coal_lump",
	flower	     = "flowers:dandelion_yellow",
	mesecon_conductor_craftable = "mesecons:wire_00000000_off",
}

function craftguide:get_recipe(item)
	if item:sub(1,6) == "group:" then
		local short_itemstr = item:sub(7)
		if group_stereotypes[short_itemstr] then
			item = group_stereotypes[short_itemstr]
		elseif minetest.registered_items["default:"..item:sub(7)] then
			item = item:gsub("group:", "default:")
		else for node, def in pairs(minetest.registered_items) do
			 if def.groups[item:match("[^,:]+$")] then item = node end
		     end
		end
	end
	return item
end

function craftguide:extract_groups(itemstr)
	if itemstr:sub(1,6) ~= "group:" then return end
	return itemstr:sub(7):split(",")
end

function craftguide:get_tooltip(item, recipe_type, cooktime, groups)
	local tooltip = ""
	if groups then
		local groupstr = "Any item belonging to the "
		for i=1, #groups do
			groupstr = groupstr..minetest.colorize("#FFFF00", groups[i])..
				   ((groups[i+1] and " and ") or "")
		end
		tooltip = "tooltip["..item..";"..groupstr.." group(s)"..
			  ((recipe_type ~= "cooking" and "]") or "")
	end
	if recipe_type == "cooking" then
		tooltip = ((groups and tooltip) or ("tooltip["..item..";"))..
			  ((groups and "") or minetest.registered_items[item].description)..
			  "\nCooking time: "..minetest.colorize("#FFFF00", cooktime).."]"
	end
	return tooltip
end

function craftguide:get_formspec(player_name)
	local data = datas[player_name]
	data.pagenum = data.pagenum or 1
	data.recipe_num = data.recipe_num or 1

	local formspec = [[ size[8,6.6;]
			button[2.5,0.2;0.8,0.5;search;?]
			button[3.2,0.2;0.8,0.5;clear;X]
			tooltip[search;Search]
			tooltip[clear;Reset]
			field_close_on_enter[craftguide_filter, false]
			button[5.4,0;0.8,0.95;prev;<] ]]..
			"label[6.1,0.18;"..minetest.colorize("#FFFF00",
				data.pagenum).." / "..data.pagemax.."]"..
			"button[7.2,0;0.8,0.95;next;>]"..
			"field[0.3,0.32;2.6,1;craftguide_filter;;"..
				minetest.formspec_escape(data.filter).."]"..
			default.gui_bg..default.gui_bg_img

	local first_item = (data.pagenum - 1) * npp
	for i = first_item, first_item + npp - 1 do
		local name = data.items[i + 1]
		if not name then break end -- last page
		local X = i % 8
		local Y = ((i % npp - X) / 8) + 1

		formspec = formspec.."item_image_button["..X..","..Y..";1,1;"..name..";"..name..";]"
	end

	if data.item and minetest.registered_items[data.item] then
		local recipes = minetest.get_all_craft_recipes(data.item)
		if data.recipe_num > #recipes then data.recipe_num = 1 end

		if #recipes > 1 then formspec = formspec..
			[[ button[0,6;2,1;alternate;Alternate]
			label[0,5.5;Recipe ]]..data.recipe_num.." of "..#recipes.."]"
		end

		local recipe_type = recipes[data.recipe_num].type
		if recipe_type == "cooking" then
			formspec = formspec.."image[3.75,4.6;0.5,0.5;default_furnace_front.png]"
		end

		local items = recipes[data.recipe_num].items
		local width = recipes[data.recipe_num].width
		if width == 0 then width = min(3, #items) end
		-- Lua 5.3 removed `table.maxn`, use this alternative in case of breakage:
		-- https://github.com/kilbith/xdecor/blob/master/handlers/helpers.lua#L1
		local rows = ceil(table.maxn(items) / width)

		for i, v in pairs(items) do
			local X = (i-1) % width + 4.5
			local Y = ceil(i / width + (5 - min(2, rows)))
			local groups = self:extract_groups(v)
			local label = (groups and "\nG") or ""
			local item = self:get_recipe(v)
			local tooltip = self:get_tooltip(item, recipe_type, width, groups)

			formspec = formspec.."item_image_button["..X..","..Y..";1,1;"..
					     item..";"..item..";"..label.."]"..tooltip
		end

		local output = recipes[data.recipe_num].output
		formspec = formspec..[[ image[3.5,5;1,1;gui_furnace_arrow_bg.png^[transformR90]
				        item_image_button[2.5,5;1,1;]]..output..";"..data.item..";]"
	end

	data.formspec = formspec
	minetest.show_formspec(player_name, "craftguide:book", formspec)
end

function craftguide:get_items(player_name)
	local items_list, data = {}, datas[player_name]
	for name, def in pairs(minetest.registered_items) do
		if not (def.groups.not_in_creative_inventory == 1) and
				minetest.get_craft_recipe(name).items and
				def.description and def.description ~= "" and
				(def.name:find(data.filter, 1, true) or
					def.description:lower():find(data.filter, 1, true)) then
			items_list[#items_list+1] = name
		end
	end

	table.sort(items_list)
	data.items = items_list
	data.size = #items_list
	data.pagemax = ceil(data.size / npp)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "craftguide:book" then return end
	local player_name = player:get_player_name()
	local data = datas[player_name]
	local formspec = data.formspec

	if fields.clear then
		data.filter, data.item, data.pagenum, data.recipe_num = "", nil, 1, 1
		craftguide:get_items(player_name)
		craftguide:get_formspec(player_name)
	elseif fields.alternate then
		data.recipe_num = (data.recipe_num and data.recipe_num + 1) or 1
		craftguide:get_formspec(player_name)
	elseif fields.search or fields.key_enter_field == "craftguide_filter" then
		data.filter = fields.craftguide_filter:lower()
		data.pagenum = 1
		craftguide:get_items(player_name)
		craftguide:get_formspec(player_name)
	elseif fields.prev or fields.next then
		if fields.prev then data.pagenum = data.pagenum - 1
		else data.pagenum = data.pagenum + 1 end
		if     data.pagenum > data.pagemax then data.pagenum = 1
		elseif data.pagenum == 0           then data.pagenum = data.pagemax end
		craftguide:get_formspec(player_name)
	else for item in pairs(fields) do
		 if minetest.get_craft_recipe(item).items then
			data.item = item
			data.recipe_num = 1
			craftguide:get_formspec(player_name)
		 end
	     end
	end
end)

minetest.register_craftitem("craftguide:book", {
	description = "Crafting Guide",
	inventory_image = "crafting_guide.png",
	wield_image = "crafting_guide.png",
	stack_max = 1,
	groups = {book=1},
	on_use = function(itemstack, user)
		local player_name = user:get_player_name()
		if not datas[player_name] then
			datas[player_name] = {}
			datas[player_name].filter = ""
			craftguide:get_items(player_name)
			craftguide:get_formspec(player_name)
		else
			minetest.show_formspec(player_name, "craftguide:book", datas[player_name].formspec)
		end
	end
})

minetest.register_craft({
	output = "craftguide:book",
	type = "shapeless",
	recipe = {"default:book"}
})

minetest.register_alias("xdecor:crafting_guide", "craftguide:book")

