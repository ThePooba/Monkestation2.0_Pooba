/datum/martial_art/slasher_grab //martial art that exists so slasher can aggro grab like a real evil dude

	name = "Slasher Grabbing"
	id = MARTIALART_SLASHER_GRAB

/datum/martial_art/slasher_grab/grab_act(mob/living/attacker, mob/living/defender)
	return big_grab(attacker, defender, TRUE)

/datum/martial_art/slasher_grab/proc/big_grab(mob/living/attacker, mob/living/defender, grab_attack)
	if(attacker.grab_state >= GRAB_AGGRESSIVE)
		defender.grabbedby(attacker, 1)
	else
		attacker.start_pulling(defender, supress_message = TRUE)
		if(attacker.pulling)
			defender.drop_all_held_items()
			defender.stop_pulling()
			if(grab_attack)
				log_combat(attacker, defender, "grabbed", addition="aggressively")
				defender.visible_message(span_warning("[attacker] violently grabs [defender]!"), \
								span_userdanger("You're violently grabbed by [attacker]!"), span_hear("You hear sounds of aggressive fondling!"), null, attacker)
				to_chat(attacker, span_danger("You violently grab [defender]!"))
				attacker.setGrabState(GRAB_AGGRESSIVE) //Instant aggressive grab
			else
				log_combat(attacker, defender, "grabbed", addition="passively")
				attacker.setGrabState(GRAB_PASSIVE)
