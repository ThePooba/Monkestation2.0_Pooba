/obj/machinery/recycler/shipbreaker
	name = "ship recycler"
	desc = "An expensive crushing machine used to recycle ship parts somewhat efficiently."
	icon = 'icons/obj/recycling.dmi'
	icon_state = "grinder-o0"
	layer = ABOVE_ALL_MOB_LAYER // Overhead
	plane = ABOVE_GAME_PLANE
	density = TRUE
	circuit = /obj/item/circuitboard/machine/recycler/shipbreaker
	var/safety_mode = FALSE // Temporarily stops machine if it detects a mob
	var/icon_name = "grinder-o"
	var/bloody = FALSE
	var/eat_dir = WEST
	var/item_recycle_sound = 'sound/items/welder.ogg'
	var/recycle_points = 0

/obj/machinery/recycler/shipbreaker/proc/on_entered(datum/source, atom/movable/AM)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(eat), AM)

/obj/machinery/recycler/shipbreaker/proc/eat(atom/movable/morsel, sound=TRUE)
	if(machine_stat & (BROKEN|NOPOWER))
		return
	if(iseffect(morsel))
		return
	if(!isturf(morsel.loc))
		return //I don't know how you called Crossed() but stop it.
	if(morsel.resistance_flags & INDESTRUCTIBLE)
		return
	if(!istype(morsel, /obj/item/stack/scrap)) //we only eat shipbreaker scrap for now
		playsound(src, 'sound/machines/buzz-sigh.ogg')
		return
	if(amount > 0)
		var/recycle_reward = morsel.amount * morsel.point_value
		playsound(src, item_recycle_sound, (50 + morsel.amount), TRUE, morsel.amount)
		use_power(active_power_usage)
		var/datum/bank_account/dept_budget = SSeconomy.get_dep_account(ACCOUNT_ENG)
		if(dept_budget)
			dept_budget.adjust_money(recycle_reward, "Shipbreaker Scrap Processed.")
	qdel(morsel)
