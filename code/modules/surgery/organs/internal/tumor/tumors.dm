#define TUMOR_STRENGTH_AVERAGE 0.25
#define TUMOR_STRENGTH_STRONG 0.5

#define TUMOR_SPREAD_AVERAGE 1
#define TUMOR_SPREAD_STRONG 2

/obj/item/organ/tumor
	name = "benign tumor"
	desc = "Hope there aren't more of these."
	icon_state = "tumor"
	zone = BODY_ZONE_HEAD
	var/strength = TUMOR_STRENGTH_AVERAGE
	var/spread_chance = TUMOR_SPREAD_AVERAGE

	var/helpful = FALSE //keeping track if they're helpful or not
	var/regeneration = FALSE //if limbs are regenerating
	var/datum/symptom/tumor/owner_symptom //what symptom of the disease it comes from

/obj/item/organ/tumor/Insert(mob/living/carbon/M, special = 0, drop_if_replaced = TRUE)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/organ/tumor/Remove(mob/living/carbon/M, special = 0)
	. = ..()
	var/tumors_left = FALSE
	for(var/obj/item/organ/tumor/IT in owner.internal_organs)
		if(IT.owner_symptom == owner_symptom)
			tumors_left = TRUE
	if(!tumors_left)
		//cure the disease, removing all tumors
		owner_symptom.disease.cure(FALSE)
	STOP_PROCESSING(SSobj, src)

/obj/item/organ/tumor/process()
	if(!owner)
		return
	if(!(src in owner.internal_organs))
		Remove(owner)
	if(helpful)
		if(owner.getBruteLoss() + owner.getFireLoss() > 0 && !(TRAIT_TOXINLOVER in owner?.dna?.species?.inherent_traits))
			owner.adjustToxLoss(strength/2)
			owner.adjustBruteLoss(-(strength/2))
			owner.adjustFireLoss(-(strength/2))
	else
		owner.adjustToxLoss(strength) //just take toxin damage
		//regeneration
	if(regeneration && prob(spread_chance))
		var/list/missing_limbs = owner.get_missing_limbs() - list(BODY_ZONE_HEAD, BODY_ZONE_CHEST) //don't regenerate the head or chest
		if(missing_limbs.len)
			var/limb_to_regenerate = pick(missing_limbs)
			owner.regenerate_limb(limb_to_regenerate,TRUE)
			var/obj/item/bodypart/new_limb = owner.get_bodypart(limb_to_regenerate)
			new_limb.receive_damage(45); //45 brute damage should be fine I think??????
			owner.emote("scream")
			owner.visible_message(span_warning("Gnarly tumors burst out of [owner]'s stump and form into a [parse_zone(limb_to_regenerate)]!"), span_notice("You scream as your [parse_zone(limb_to_regenerate)] reforms."))
	if(prob(spread_chance))
		owner_symptom?.spread(owner, TRUE)

/obj/item/organ/tumor/malignant
	name = "malignant tumor"
	desc = "Yikes. There's probably more of these in you."
	strength = TUMOR_STRENGTH_STRONG
	spread_chance = TUMOR_SPREAD_STRONG

#undef TUMOR_STRENGTH_AVERAGE
#undef TUMOR_STRENGTH_STRONG
#undef TUMOR_SPREAD_AVERAGE
#undef TUMOR_SPREAD_STRONG



/obj/item/organ/internal/zombie_infection
	name = "festering ooze"
	desc = "A black web of pus and viscera."
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_ZOMBIE
	icon_state = "blacktumor"
	var/causes_damage = TRUE
	var/datum/species/old_species = /datum/species/human
	var/living_transformation_time = 30
	var/converts_living = FALSE

	var/revive_time_min = 450
	var/revive_time_max = 700
	var/timer_id

/obj/item/organ/internal/zombie_infection/Initialize(mapload)
	. = ..()
	if(iscarbon(loc))
		Insert(loc)
	GLOB.zombie_infection_list += src

/obj/item/organ/internal/zombie_infection/Destroy()
	GLOB.zombie_infection_list -= src
	. = ..()

/obj/item/organ/internal/zombie_infection/Insert(mob/living/carbon/M, special = FALSE, drop_if_replaced = TRUE)
	. = ..()
	if(!.)
		return .
	START_PROCESSING(SSobj, src)

/obj/item/organ/internal/zombie_infection/Remove(mob/living/carbon/M, special = FALSE)
	. = ..()
	STOP_PROCESSING(SSobj, src)
	if(iszombie(M) && old_species && !special && !QDELETED(src))
		M.set_species(old_species)
	if(timer_id)
		deltimer(timer_id)

/obj/item/organ/internal/zombie_infection/on_find(mob/living/finder)
	to_chat(finder, "<span class='warning'>Inside the head is a disgusting black \
		web of pus and viscera, bound tightly around the brain like some \
		biological harness.</span>")

/obj/item/organ/internal/zombie_infection/process(seconds_per_tick, times_fired)
	if(!owner)
		return
	if(!(src in owner.organs))
		Remove(owner)
	if(owner.mob_biotypes & MOB_MINERAL)//does not process in inorganic things
		return
	if(HAS_TRAIT(owner, TRAIT_NO_ZOMBIFY))
		return
	if (causes_damage && !iszombie(owner) && owner.stat != DEAD)
		owner.adjustToxLoss(0.5 * seconds_per_tick)
		if (SPT_PROB(5, seconds_per_tick))
			to_chat(owner, span_danger("You feel sick..."))
	if(timer_id || HAS_TRAIT(owner, TRAIT_SUICIDED) || !owner.get_organ_by_type(/obj/item/organ/internal/brain))
		return
	if(owner.stat != DEAD && !converts_living)
		return
	if(!iszombie(owner))
		to_chat(owner, "<span class='cultlarge'>You can feel your heart stopping, but something isn't right... \
		life has not abandoned your broken form. You can only feel a deep and immutable hunger that \
		not even death can stop, you will rise again!</span>")
	var/revive_time = rand(revive_time_min, revive_time_max)
	var/flags = TIMER_STOPPABLE
	timer_id = addtimer(CALLBACK(src, PROC_REF(zombify), owner), revive_time, flags)

/obj/item/organ/internal/zombie_infection/proc/zombify(mob/living/carbon/target)
	timer_id = null

	if(!converts_living && owner.stat != DEAD)
		return

	if(!iszombie(owner))
		old_species = owner.dna.species.type
		target.set_species(/datum/species/zombie/infectious)

	var/stand_up = (target.stat == DEAD) || (target.stat == UNCONSCIOUS)

	//Fully heal the zombie's damage the first time they rise
	if(!target.heal_and_revive(0, span_danger("[target] suddenly convulses, as [target.p_they()][stand_up ? " stagger to [target.p_their()] feet and" : ""] gain a ravenous hunger in [target.p_their()] eyes!")))
		return

	to_chat(target, span_alien("You HUNGER!"))
	to_chat(target, span_alertalien("You are now a zombie! Do not seek to be cured, do not help any non-zombies in any way, do not harm your zombie brethren and spread the disease by killing others. You are a creature of hunger and violence."))
	playsound(target, 'sound/hallucinations/far_noise.ogg', 50, 1)
	target.do_jitter_animation(living_transformation_time)
	target.Stun(living_transformation_time)

/obj/item/organ/internal/zombie_infection/nodamage
	causes_damage = FALSE
