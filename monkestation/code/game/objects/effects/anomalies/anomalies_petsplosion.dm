/obj/effect/anomaly/petsplosion //2catz lmao (also see thermonuclear catsplosion)
	name = "Lifebringer Anomaly"
	desc = "An anomalous gateway that seemingly creates new life out of nowhere. Known by Lavaland Dwarves as the \"Petsplosion\"."
	icon_state = "bluestream_fade"
	lifespan = 30 SECONDS
	var/active = TRUE
	var/list/pet_type_cache
	var/catsplosion = FALSE

//todo: make a /turf/open/floor/iron/snow that works identically to /turf/open/floor/iron but is snowy and doesnt reveal pipes
/obj/effect/anomaly/petsplosion/Initialize(mapload, new_lifespan)
	. = ..()
	if(prob(1))
		catsplosion = TRUE

	pet_type_cache = subtypesof(/mob/living/basic/pet)
	pet_type_cache += list(
		/mob/living/basic/axolotl,
		/mob/living/basic/butterfly,
		/mob/living/basic/cockroach,
		/mob/living/basic/crab,
		/mob/living/basic/frog,
		/mob/living/basic/lizard,
		/mob/living/basic/mothroach,
		/mob/living/basic/bat,
		/mob/living/basic/parrot,
		/mob/living/basic/chicken,
		/mob/living/basic/sloth,
	pet_type_cache -= list(/mob/living/basic/pet/penguin, //Removing the risky and broken ones.
		/mob/living/basic/pet/dog/corgi/narsie,
		/mob/living/basic/pet/gondola/gondolapod,
		/mob/living/basic/pet/gondola,
		/mob/living/basic/pet/dog,
		/mob/living/basic/pet/fox
		)

/obj/effect/anomaly/petsplosion/anomalyEffect(seconds_per_tick)
	..()

	if(isspaceturf(src) || !isopenturf(get_turf(src)))
		return
	if(active)

		if(catsplosion)
			var/mob/living/basic/pet/chosen_pet = /mob/living/simple_animal/pet/cat
			new chosen_pet(src.loc)
			active = FALSE
			var/turf/open/tile = get_turf(src)
			if(istype(tile))
				tile.atmos_spawn_air("o2=10;plasma=1;TEMP=3000")
			return

		var/mob/living/basic/pet/chosen_pet = pick(pet_type_cache)
		new chosen_pet(src.loc)
		active = FALSE
		return

	active = TRUE
