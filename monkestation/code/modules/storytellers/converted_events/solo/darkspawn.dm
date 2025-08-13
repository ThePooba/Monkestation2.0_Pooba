/datum/round_event_control/antagonist/solo/darkspawn
	name = "Darkspawn"
	tags = list(TAG_COMBAT, TAG_TEAM_ANTAG, TAG_SPOOKY, TAG_MAGICAL, TAG_CREW_ANTAG)
	antag_flag = ROLE_BLOODLING
	antag_datum = /datum/antagonist/darkspawn
	typepath = /datum/round_event/antagonist/solo/darkspawn
	protected_roles = list(
		JOB_CAPTAIN,
		JOB_HEAD_OF_PERSONNEL,
		JOB_CHIEF_ENGINEER,
		JOB_CHIEF_MEDICAL_OFFICER,
		JOB_RESEARCH_DIRECTOR,
		JOB_DETECTIVE,
		JOB_HEAD_OF_SECURITY,
		JOB_PRISONER,
		JOB_SECURITY_OFFICER,
		JOB_SECURITY_ASSISTANT,
		JOB_WARDEN,
	)
	restricted_roles = list(
		JOB_AI,
		JOB_CYBORG,
	)
	enemy_roles = list(
		JOB_CAPTAIN,
		JOB_HEAD_OF_SECURITY,
		JOB_DETECTIVE,
		JOB_WARDEN,
		JOB_SECURITY_OFFICER,
		JOB_SECURITY_ASSISTANT,
	)
	required_enemies = 5
	weight = 4
	max_occurrences = 0
	maximum_antags = 3
	min_players = 45

/datum/round_event_control/antagonist/solo/bloodling/roundstart
	name = "Darkspawn"
	roundstart = TRUE
	earliest_start = 0 SECONDS
	max_occurrences = 1

/datum/round_event/antagonist/solo/darkspawn/add_datum_to_mind(datum/mind/antag_mind)
	antag_mind.special_role = ROLE_DARKSPAWN
	antag_mind.add_antag_datum(antag_datum)
