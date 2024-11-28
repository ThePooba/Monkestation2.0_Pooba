#define MONKEY_SOUNDS list('sound/creatures/monkey/monkey_screech_1.ogg', 'sound/creatures/monkey/monkey_screech_2.ogg', 'sound/creatures/monkey/monkey_screech_3.ogg','sound/creatures/monkey/monkey_screech_4.ogg','sound/creatures/monkey/monkey_screech_5.ogg','sound/creatures/monkey/monkey_screech_6.ogg','sound/creatures/monkey/monkey_screech_7.ogg')

/obj/effect/anomaly/monkey //Monkey Anomaly (Random Chimp Event)
	name = "Screeching Anomaly"
	desc = "An anomalous one-way gateway that leads straight to some sort of a ape dimension."
	icon_state = "dimensional_overlay"
	lifespan = 35 SECONDS
	var/active = TRUE
		var/static/list/walter_spawns = list(
		/mob/living/basic/pet/dog/bullterrier/walter/saulter = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/negative = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/syndicate = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/doom = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/space = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/clown = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/french = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/british = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/wizard = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/smallter = 5,
		/mob/living/basic/pet/dog/bullterrier/walter/sus = 1, //:(
		)

/obj/effect/anomaly/petsplosion/anomalyEffect(seconds_per_tick)
	..()

	playsound(src, pick(MONKEY_SOUNDS), vol = 33, vary = 1, mixer_channel = CHANNEL_MOB_SOUNDS)

	if(isspaceturf(src) || !isopenturf(get_turf(src)))
		return

	if(!active)
		active = TRUE
		return

	if(prob(10))
		new /mob/living/carbon/human/species/monkey/angry(src.loc)
	else
		new /mob/living/carbon/human/species/monkey(src.loc)
	active = FALSE

/obj/effect/anomaly/monkey/detonate()
	if(prob(25))
		new /mob/living/basic/hostile/gorilla(src.loc)

#undef MONKEY_SOUNDS
