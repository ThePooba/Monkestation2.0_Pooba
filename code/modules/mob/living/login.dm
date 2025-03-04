/mob/living/Login()
	. = ..()
	if(!. || !client)
		return FALSE

	if(interview_safety(src, "client in living mob"))
		qdel(client)
		return FALSE

	//Mind updates
	sync_mind()

	update_damage_hud()
	update_health_hud()

	var/turf/T = get_turf(src)
	if (isturf(T))
		update_z(T.z)

	//Vents
	var/ventcrawler = HAS_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS) || HAS_TRAIT(src, TRAIT_VENTCRAWLER_NUDE)
	if(ventcrawler)
		to_chat(src, span_notice("You can ventcrawl! Use alt+click on vents to quickly travel about the station."))

	med_hud_set_status()

	update_fov_client()
