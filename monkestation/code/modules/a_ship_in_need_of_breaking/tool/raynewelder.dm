
/obj/item/weldingtool/electric/raynewelder
	name = "laser welding tool"
	desc = "A Rayne corp laser cutter and welder."
	icon = 'monkestation/code/modules/a_ship_in_need_of_breaking/icons/shipbreaking.dmi'
	icon_state = "raynewelder"
	light_power = 1
	light_color = LIGHT_COLOR_FLARE
	tool_behaviour = NONE
	toolspeed = 0.2
	power_use_amount = 30
	// We don't use fuel
	change_icons = FALSE
	max_fuel = 20
	var/area/mapped_start_area = /area/shipbreak

/obj/item/weldingtool/electric/raynewelder/process(seconds_per_tick)
	if(!powered)
		switched_off()
		return
	if(get_area(src) != mapped_start_area)
		switched_off()
		return
	if(!(item_use_power(power_use_amount) & COMPONENT_POWER_SUCCESS))
		switched_off()
		return
