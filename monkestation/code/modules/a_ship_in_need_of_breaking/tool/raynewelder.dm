
/obj/item/weldingtool/electric/raynewelder
	name = "laser welding tool"
	desc = "A Rayne corp laser welse"
	icon = 'monkestation/code/modules/a_ship_in_need_of_breaking/icons/shipbreaking.dmi'
	icon_state = "raynewelder"
	light_power = 1
	light_color = LIGHT_COLOR_FLARE
	tool_behaviour = NONE
	toolspeed = 0.1
	power_use_amount = 30
	// We don't use fuel
	change_icons = FALSE
	max_fuel = 20

/obj/item/firing_pin/explorer
	name = "outback firing pin"
	desc = "A firing pin used by the austrailian defense force, retrofit to prevent weapon discharge on the station."
	icon_state = "firing_pin_explorer"
	fail_message = "cannot fire while on station, mate!"

// This checks that the user isn't on the station Z-level.
/obj/item/firing_pin/explorer/pin_auth(mob/living/user)
	var/turf/station_check = get_turf(user)
	if(!station_check || is_station_level(station_check.z))
		return FALSE
	return TRUE
