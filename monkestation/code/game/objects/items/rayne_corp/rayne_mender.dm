#define RAYNE_MENDER_SPEECH "monkey_companies/rayne_mender.json"
/// How long the gun should wait between speaking to lessen spam
#define RAYNE_MENDER_SPEECH_COOLDOWN 5 SECONDS
/// What color is the default kill mode for these guns, used to make sure the chat colors are right at roundstart
#define DEFAULT_RUNECHAT_COLOR "#449bcd"

/obj/item/storage/medkit/rayne
	name = "Rayne Corp Health Analyzer Kit"
	icon = 'icons/obj/device.dmi'
	item_flags = NOBLUDGEON
	var/speech_json_file = SHORT_MOD_LASER_SPEECH

/obj/item/storage/medkit/rayne/attack(mob/living/M, mob/living/carbon/human/user)
	if(!user.can_read(src) || user.is_blind())
		return

	flick("[icon_state]-scan", src) //makes it so that it plays the scan animation upon scanning, including clumsy scanning

	if(ispodperson(M) && !advanced)
		to_chat(user, "<span class='info'>[M]'s is a plant. Give them some water or something, I dont care.")
		return

	user.visible_message(span_notice("[user] analyzes [M]'s vitals."))
	playsound(user.loc, 'sound/items/healthanalyzer.ogg', 50)
	healthscan(user, M, mode, advanced)
	speak_up(json_speech_string, TRUE)
	add_fingerprint(user)
	judge_health(M)


//This proc controls what the medkit says when scanning a person, and recommends a best course of treatment (barely)
/obj/item/storage/medkit/rayne/proc/judge_health(mob/living/judged)

	var/brain

	if(judged.on_fire)
		speak_up('onfire')
		return
	if(ishuman(judged))
		if(!judged.get_organ_slot(ORGAN_SLOT_BRAIN))
			speakup("nobrain")
			return
		else
			brain = judged.get_organ_slot(ORGAN_SLOT_BRAIN).damage
			if(brain > 150)
				speakup("braindamage")
				return


	var/brute = judged.brute_loss
	var/oxy = judged.oxy_loss
	var/tox = judged.tox_loss
	var/burn = judged.burn_loss
	var/big = max(brute,oxy,burn,tox)
	if((brute + burn) >= 350)
		speakup("fuckedup")
		return
	switch(big)
		if(brute)
			speakup("brute")
		if(burn)
			speakup("burn")
		if(tox)
			speakup("tox")
		if(oxy)
			speakup("oxy")
		else
			speakup("fine")



/obj/item/storage/medkit/rayne/proc/speak_up(json_string, ignores_cooldown = FALSE)

	if(!personality_mode && !ignores_personality_toggle)
		return
	if(!json_string)
		return
	if(!ignores_cooldown && !COOLDOWN_FINISHED(src, last_speech))
		return
	say(pick_list_replacements(speech_json_file, json_string))
	playsound(src, 'sound/creatures/tourist/tourist_talk.ogg', 15, TRUE, SHORT_RANGE_SOUND_EXTRARANGE, frequency = rand(3, 3.5))
	Shake(2, 2, 1 SECONDS)
	COOLDOWN_START(src, last_speech, MOD_LASER_SPEECH_COOLDOWN)
