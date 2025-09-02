SUBSYSTEM_DEF(air)
	name = "Atmospherics"
	init_order = INIT_ORDER_AIR
	priority = FIRE_PRIORITY_AIR
	wait = 0.5 SECONDS
	flags = SS_BACKGROUND
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	var/cached_cost = 0

	/// How long we took for a full pass through the subsystem. Custom-tracked version of `cost`.
	var/datum/resumable_cost_counter/cost_full = new()
	/// How long we spent sleeping while waiting for MILLA to finish the last tick, shown in SS Info's C block as ZZZ.
	var/datum/resumable_cost_counter/time_slept = new()
	/// The cost of a pass through bound gas mixtures, shown in SS Info's C block as BM.
	var/datum/resumable_cost_counter/cost_bound_mixtures = new()
	/// The cost of a MILLA tick in ms, shown in SS Info's C block as MT.
	var/cost_milla_tick = 0
	/// The cost of a pass through interesting tiles, shown in SS Info's C block as IT.
	var/datum/resumable_cost_counter/cost_interesting_tiles = new()
	/// The cost of a pass through hotspots, shown in SS Info's C block as HS.
	var/datum/resumable_cost_counter/cost_hotspots = new()
	/// The cost of a pass through pipenets, shown in SS Info's C block as PN.
	var/datum/resumable_cost_counter/cost_pipenets = new()
	/// The cost of a pass through building pipenets, shown in SS Info's C block as DPN.
	var/datum/resumable_cost_counter/cost_pipenets_to_build = new()
	/// The cost of a pass through atmos machinery, shown in SS Info's C block as AM.
	var/datum/resumable_cost_counter/cost_atmos_machinery = new()

	/// The set of current bound mixtures. Shown in SS Info as BM:x+y, where x is the length at the start of the most recent processing, and y is the number of mixtures that have been added during processing.
	var/list/bound_mixtures = list()
	/// The original length of bound_mixtures.
	var/original_bound_mixtures = 0
	/// The number of bound mixtures we saw when we last stopped processing them.
	var/last_bound_mixtures = 0
	/// The number of bound mixtures that were added during this processing cycle.
	var/added_bound_mixtures = 0
	/// The length of the most recent interesting tiles list, shown in SS Info as IT.
	var/interesting_tile_count = 0
	/// The set of current active hotspots. Length shown in SS Info as HS.
	var/list/hotspots = list()
	/// The set of pipenets that need to be built. Length shown in SS Info as PTB.
	var/list/pipenets_to_build = list()
	/// The set of active pipenets. Length shown in SS Info as PN.
	var/list/pipenets = list()
	/// The set of active atmos machinery. Length shown in SS Info as AM.
	var/list/atmos_machinery = list()

	/// A list of atmos machinery to set up in Initialize.
	var/list/machinery_to_construct = list()

	/// Pipe overlay/underlay icon manager
	var/datum/pipe_icon_manager/icon_manager

	/// An arbitrary list of stuff currently being processed.
	var/list/currentrun = list()

	/// Which step we're currently on, used to let us resume if our time budget elapses.
	var/currentpart = SSAIR_DEFERREDPIPENETS

	/// Is MILLA currently in synchronous mode? TRUE if data is fresh and changes can be made, FALSE if data is from last tick and changes cannot be made (because this tick is still processing).
	var/is_synchronous = TRUE

	/// Are we currently running in a MILLA-safe context, i.e. is is_synchronous *guaranteed* to be TRUE. Nothing outside of this file should change this.
	VAR_PRIVATE/in_milla_safe_code = FALSE

	/// When did we start the last MILLA tick?
	var/milla_tick_start = null

	/// Is MILLA (and hence SSair) reliably healthy?
	var/healthy = TRUE

	/// When was MILLA last seen unhealthy?
	var/last_unhealthy = 0

	/// A list of callbacks waiting for MILLA to finish its tick and enter synchronous mode.
	var/list/waiting_for_sync = list()

	var/list/reaction_handbook
	var/list/gas_handbook

/datum/controller/subsystem/air/stat_entry(msg)
	var/list/msg = list()
	msg += "C:{"
	msg += "ZZZ:[time_slept.to_string()]|"
	msg += "BM:[cost_bound_mixtures.to_string()]|"
	msg += "MT:[round(cost_milla_tick,1)]|"
	msg += "IT:[cost_interesting_tiles.to_string()]|"
	msg += "HS:[cost_hotspots.to_string()]|"
	msg += "PN:[cost_pipenets.to_string()]|"
	msg += "PTB:[cost_pipenets_to_build.to_string()]|"
	msg += "AM:[cost_atmos_machinery.to_string()]"
	msg += "} "
	msg += "BM:[original_bound_mixtures]+[added_bound_mixtures]|"
	msg += "IT:[interesting_tile_count]|"
	msg += "HS:[length(hotspots)]|"
	msg += "PN:[length(pipenets)]|"
	msg += "AM:[length(atmos_machinery)]|"
	return ..()

/*
/datum/controller/subsystem/air/stat_entry(msg)
	msg += "C:{"
	msg += "AT:[round(cost_turfs,1)]|"
	msg += "HS:[round(cost_hotspots,1)]|"
	msg += "EG:[round(cost_groups,1)]|"
	msg += "HP:[round(cost_highpressure,1)]|"
	msg += "SC:[round(cost_superconductivity,1)]|"
	msg += "PN:[round(cost_pipenets,1)]|"
	msg += "AM:[round(cost_atmos_machinery,1)]|"
	msg += "AO:[round(cost_atoms, 1)]|"
	msg += "RB:[round(cost_rebuilds,1)]|"
	msg += "AJ:[round(cost_adjacent,1)]|"
	msg += "} "
	msg += "AT:[active_turfs.len]|"
	msg += "HS:[hotspots.len]|"
	msg += "EG:[excited_groups.len]|"
	msg += "HP:[high_pressure_delta.len]|"
	msg += "SC:[active_super_conductivity.len]|"
	msg += "PN:[networks.len]|"
	msg += "AM:[atmos_machinery.len]|"
	msg += "AO:[atom_process.len]|"
	msg += "RB:[rebuild_queue.len]|"
	msg += "EP:[expansion_queue.len]|"
	msg += "AJ:[adjacent_rebuild.len]|"
	msg += "AT/MS:[round((cost ? active_turfs.len/cost : 0),0.1)]"
	return ..()
*/

/datum/controller/subsystem/air/Initialize()
	in_milla_safe_code = TRUE

	map_loading = FALSE
	gas_reactions = init_gas_reactions()
	hotspot_reactions = init_hotspot_reactions()
	setup_write_to_milla()
	setup_allturfs()
	setup_atmos_machinery()
	setup_pipenets()
	setup_turf_visuals()
	process_adjacent_rebuild()
	atmos_handbooks_init()
	in_milla_safe_code = FALSE

	return SS_INIT_SUCCESS

/datum/controller/subsystem/air/fire(resumed = FALSE)
		// All atmos stuff assumes MILLA is synchronous. Ensure it actually is.
	if(!is_synchronous)
		var/timer = TICK_USAGE_REAL

		while(!is_synchronous)
			// Sleep for 1ms.
			sleep(0.01)
			if(MC_TICK_CHECK)
				time_slept.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), FALSE)
				cost_full.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), FALSE)
				return

		cost_full.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), FALSE)
		time_slept.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), TRUE)

	fire_sleepless(resumed)

/datum/controller/subsystem/air/proc/fire_sleepless(resumed)
	// Any proc that wants MILLA to be synchronous should not sleep.
	SHOULD_NOT_SLEEP(TRUE)
	in_milla_safe_code = TRUE

	var/timer = TICK_USAGE_REAL

	if(currentpart == SSAIR_DEFERREDPIPENETS || !resumed)
		timer = TICK_USAGE_REAL

		build_pipenets(resumed)

		cost_pipenets_to_build.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), state != SS_PAUSED && state != SS_PAUSING)
		cost_full.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), FALSE)
		if(state == SS_PAUSED || state == SS_PAUSING)
			in_milla_safe_code = FALSE
			return
		resumed = 0
		currentpart = SSAIR_PIPENETS

	if(currentpart == SSAIR_PIPENETS || !resumed)
		timer = TICK_USAGE_REAL

		process_pipenets(resumed)

		cost_pipenets.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), state != SS_PAUSED && state != SS_PAUSING)
		cost_full.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), FALSE)
		if(state == SS_PAUSED || state == SS_PAUSING)
			in_milla_safe_code = FALSE
			return
		resumed = 0
		currentpart = SSAIR_ATMOSMACHINERY

	if(currentpart == SSAIR_ATMOSMACHINERY)
		timer = TICK_USAGE_REAL

		process_atmos_machinery(resumed)

		cost_atmos_machinery.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), state != SS_PAUSED && state != SS_PAUSING)
		cost_full.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), FALSE)
		if(state == SS_PAUSED || state == SS_PAUSING)
			in_milla_safe_code = FALSE
			return
		resumed = 0
		currentpart = SSAIR_INTERESTING_TILES

	if(currentpart == SSAIR_INTERESTING_TILES)
		timer = TICK_USAGE_REAL

		process_interesting_tiles(resumed)

		cost_interesting_tiles.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), state != SS_PAUSED && state != SS_PAUSING)
		cost_full.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), FALSE)
		if(state == SS_PAUSED || state == SS_PAUSING)
			in_milla_safe_code = FALSE
			return
		resumed = 0
		currentpart = SSAIR_HOTSPOTS

	if(currentpart == SSAIR_HOTSPOTS)
		timer = TICK_USAGE_REAL

		process_hotspots(resumed)

		cost_hotspots.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), state != SS_PAUSED && state != SS_PAUSING)
		cost_full.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), FALSE)
		if(state == SS_PAUSED || state == SS_PAUSING)
			in_milla_safe_code = FALSE
			return
		resumed = 0
		currentpart = SSAIR_BOUND_MIXTURES

	if(currentpart == SSAIR_BOUND_MIXTURES)
		timer = TICK_USAGE_REAL

		process_bound_mixtures(resumed)

		cost_bound_mixtures.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), state != SS_PAUSED && state != SS_PAUSING)
		cost_full.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), FALSE)
		if(state == SS_PAUSED || state == SS_PAUSING)
			in_milla_safe_code = FALSE
			return
		resumed = 0
		currentpart = SSAIR_MILLA_TICK

	if(currentpart == SSAIR_MILLA_TICK)
		timer = TICK_USAGE_REAL

		spawn_milla_tick_thread()
		is_synchronous = FALSE

		cost_milla_tick = MC_AVERAGE(cost_milla_tick, get_milla_tick_time())
		cost_full.record_progress(TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer), state != SS_PAUSED && state != SS_PAUSING)
		if(state == SS_PAUSED || state == SS_PAUSING)
			in_milla_safe_code = FALSE
			return
		resumed = 0

	currentpart = SSAIR_DEFERREDPIPENETS
	in_milla_safe_code = FALSE

/datum/controller/subsystem/air/Recover()
	hotspots = SSair.hotspots
	networks = SSair.networks
	rebuild_queue = SSair.rebuild_queue
	expansion_queue = SSair.expansion_queue
	adjacent_rebuild = SSair.adjacent_rebuild
	atmos_machinery = SSair.atmos_machinery
	pipe_init_dirs_cache = SSair.pipe_init_dirs_cache
	gas_reactions = SSair.gas_reactions
	atmos_gen = SSair.atmos_gen
	planetary = SSair.planetary
	is_synchronous = SSair.is_synchronous
	atom_process = SSair.atom_process
	currentrun = SSair.currentrun
	queued_for_activation = SSair.queued_for_activation

/datum/controller/subsystem/air/proc/process_adjacent_rebuild(init = FALSE)
	var/list/queue = adjacent_rebuild

	while (length(queue))
		var/turf/currT = queue[1]
		var/goal = queue[currT]
		queue.Cut(1,2)

		currT.immediate_calculate_adjacent_turfs()
		if(goal == MAKE_ACTIVE)
			add_to_active(currT)
		else if(goal == KILL_EXCITED)
			add_to_active(currT, TRUE)

		if(init)
			CHECK_TICK
		else
			if(MC_TICK_CHECK)
				break

/datum/controller/subsystem/air/proc/process_pipenets(resumed = FALSE)
	if (!resumed)
		src.currentrun = pipenets.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/datum/thing = currentrun[currentrun.len]
		currentrun.len--
		if(thing)
			thing.process()
		else
			pipenets.Remove(thing)
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/add_to_rebuild_queue(obj/machinery/atmospherics/atmos_machine)
	if(istype(atmos_machine, /obj/machinery/atmospherics) && !atmos_machine.rebuilding)
		rebuild_queue += atmos_machine
		atmos_machine.rebuilding = TRUE

/datum/controller/subsystem/air/proc/add_to_expansion(datum/pipeline/line, starting_point)
	var/list/new_packet = new(SSAIR_REBUILD_QUEUE)
	new_packet[SSAIR_REBUILD_PIPELINE] = line
	new_packet[SSAIR_REBUILD_QUEUE] = list(starting_point)
	expansion_queue += list(new_packet)

/datum/controller/subsystem/air/proc/remove_from_expansion(datum/pipeline/line)
	for(var/list/packet in expansion_queue)
		if(packet[SSAIR_REBUILD_PIPELINE] == line)
			expansion_queue -= packet
			return

/datum/controller/subsystem/air/proc/process_atoms(resumed = FALSE)
	if(!resumed)
		src.currentrun = atom_process.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/atom/talk_to = currentrun[currentrun.len]
		currentrun.len--
		if(!talk_to)
			return
		talk_to.process_exposure()
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_atmos_machinery(resumed = FALSE)
	if (!resumed)
		src.currentrun = atmos_machinery.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/obj/machinery/M = currentrun[currentrun.len]
		currentrun.len--
		if(isnull(M) || (M.process_atmos(seconds) == PROCESS_KILL))
			atmos_machinery -= M
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_hotspots(resumed = FALSE)
	if (!resumed)
		src.currentrun = hotspots.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/obj/effect/hotspot/H = currentrun[currentrun.len]
		currentrun.len--
		if (H)
			H.process()
		else
			hotspots -= H
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_high_pressure_delta(resumed = FALSE)
	while (high_pressure_delta.len)
		var/turf/open/T = high_pressure_delta[high_pressure_delta.len]
		high_pressure_delta.len--
		T.high_pressure_movements()
		T.pressure_difference = 0
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_interesting_tiles(resumed = FALSE)
	if(!resumed)
		// Fetch the list of interesting tiles from MILLA.
		src.currentrun = get_interesting_atmos_tiles()
		interesting_tile_count = length(src.currentrun) / MILLA_INTERESTING_TILE_SIZE
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(length(currentrun))
		// Pop a tile off the list.
		var/offset = length(currentrun) - MILLA_INTERESTING_TILE_SIZE
		var/turf/current_turf = currentrun[offset + MILLA_INDEX_TURF]
		if(!istype(current_turf))
			currentrun.len -= MILLA_INTERESTING_TILE_SIZE
			if(MC_TICK_CHECK)
				return
			continue

		var/reasons = currentrun[offset + MILLA_INDEX_INTERESTING_REASONS]
		var/x_flow = currentrun[offset + MILLA_INDEX_AIRFLOW_X]
		var/y_flow = currentrun[offset + MILLA_INDEX_AIRFLOW_Y]
		var/milla_tile = currentrun.Copy(offset + 1, offset + 1 + MILLA_TILE_SIZE + 1)
		currentrun.len -= MILLA_INTERESTING_TILE_SIZE

		// Bind the MILLA tile we got, if needed.
		if(isnull(current_turf.bound_air))
			bind_turf(current_turf, milla_tile)
		else if(current_turf.bound_air.lastread < times_fired)
			current_turf.bound_air.copy_from_milla(milla_tile)
			current_turf.bound_air.lastread = times_fired
			current_turf.bound_air.readonly = null
			current_turf.bound_air.dirty = FALSE
			current_turf.bound_air.synchronized = FALSE

		if(reasons & MILLA_INTERESTING_REASON_DISPLAY)
			var/turf/simulated/simmed_turf = current_turf
			if(istype(simmed_turf))
				simmed_turf.update_visuals()

		if(reasons & MILLA_INTERESTING_REASON_HOT)
			var/datum/gas_mixture/air = current_turf.get_readonly_air()
			current_turf.hotspot_expose(air.temperature(), CELL_VOLUME)
			for(var/atom/movable/item in current_turf)
				item.temperature_expose(air, air.temperature(), CELL_VOLUME)
			current_turf.temperature_expose(air, air.temperature(), CELL_VOLUME)

		if(reasons & MILLA_INTERESTING_REASON_WIND)
			current_turf.high_pressure_movements(x_flow, y_flow)

		if(MC_TICK_CHECK)
			return




/datum/controller/subsystem/air/proc/process_bound_mixtures(resumed = FALSE)
	if (!resumed)
		original_bound_mixtures = length(bound_mixtures)
		last_bound_mixtures = length(bound_mixtures)
	// Note that we do NOT copy this list to src.currentrun.
	//We're fine with things being added to it as we work, because it all needs to get written before the next MILLA tick.
	var/list/currentrun = bound_mixtures
	added_bound_mixtures = length(currentrun) - last_bound_mixtures
	while(currentrun.len)
		var/datum/gas_mixture/bound_to_turf/mixture = currentrun[length(currentrun)]
		currentrun.len--
		mixture.synchronized = FALSE
		if(mixture.dirty)
			// This is one of two places expected to call this otherwise-unsafe method.
			mixture.private_unsafe_write()
			mixture.dirty = FALSE
		if (MC_TICK_CHECK)
			last_bound_mixtures = length(bound_mixtures)
			return

/datum/controller/subsystem/air/proc/process_rebuilds()
	//Yes this does mean rebuilding pipenets can freeze up the subsystem forever, but if we're in that situation something else is very wrong
	var/list/currentrun = rebuild_queue
	while(currentrun.len || length(expansion_queue))
		while(currentrun.len && !length(expansion_queue)) //If we found anything, process that first
			var/obj/machinery/atmospherics/remake = currentrun[currentrun.len]
			currentrun.len--
			if (!remake)
				continue
			remake.rebuild_pipes()
			if (MC_TICK_CHECK)
				return

		var/list/queue = expansion_queue
		while(queue.len)
			var/list/pack = queue[queue.len]
			//We operate directly with the pipeline like this because we can trust any rebuilds to remake it properly
			var/datum/pipeline/linepipe = pack[SSAIR_REBUILD_PIPELINE]
			var/list/border = pack[SSAIR_REBUILD_QUEUE]
			expand_pipeline(linepipe, border)
			if(state != SS_RUNNING) //expand_pipeline can fail a tick check, we shouldn't let things get too fucky here
				return

			linepipe.building = FALSE
			queue.len--
			if (MC_TICK_CHECK)
				return

///Rebuilds a pipeline by expanding outwards, while yielding when sane
/datum/controller/subsystem/air/proc/expand_pipeline(datum/pipeline/net, list/border)
	while(border.len)
		var/obj/machinery/atmospherics/borderline = border[border.len]
		border.len--

		var/list/result = borderline.pipeline_expansion(net)
		if(!length(result))
			continue
		for(var/obj/machinery/atmospherics/considered_device in result)
			if(!istype(considered_device, /obj/machinery/atmospherics/pipe))
				considered_device.set_pipenet(net, borderline)
				net.add_machinery_member(considered_device)
				continue
			var/obj/machinery/atmospherics/pipe/item = considered_device
			if(net.members.Find(item))
				continue
			if(item.parent)
				var/static/pipenetwarnings = 10
				if(pipenetwarnings > 0)
					log_mapping("expand_pipeline(): [item.type] added to a pipenet while still having one. (pipes leading to the same spot stacking in one turf) around [AREACOORD(item)].")
					pipenetwarnings--
					if(pipenetwarnings == 0)
						log_mapping("expand_pipeline(): further messages about pipenets will be suppressed")

			net.members += item
			border += item

			net.air.volume += item.volume
			item.parent = net

			if(item.air_temporary)
				net.air.merge(item.air_temporary)
				item.air_temporary = null

		if (MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/StartLoadingMap()
	LAZYINITLIST(queued_for_activation)
	map_loading = TRUE

/datum/controller/subsystem/air/StopLoadingMap()
	map_loading = FALSE
	for(var/T in queued_for_activation)
		add_to_active(T, TRUE)
	queued_for_activation.Cut()

/datum/controller/subsystem/air/proc/setup_allturfs()
	for(var/turf/setup as anything in ALL_TURFS())
		setup.Initialize_atmos(times_fired)
		CHECK_TICK

/datum/controller/subsystem/air/proc/setup_allturfs_sleepless()
	for(var/turf/eepless as anything in ALL_TURFS())
		eepless.Initialize_Atmos(times_fired)

/datum/controller/subsystem/air/proc/setup_atmos_machinery()
	for (var/obj/machinery/atmospherics/AM in atmos_machinery)
		AM.atmos_init()
		CHECK_TICK

/datum/controller/subsystem/air/proc/setup_write_to_milla()
	var/watch = start_watch()
	log_startup_progress("Writing tiles to MILLA...")
	//cache for sanic speed (lists are references anyways)
	var/list/cache = bound_mixtures
	var/count = length(cache)
	while(length(cache))
		var/datum/gas_mixture/bound_to_turf/mixture = cache[length(cache)]
		cache.len--
		if(mixture.dirty)
			in_milla_safe_code = TRUE
			// This is one of two places expected to call this otherwise-unsafe method.
			mixture.private_unsafe_write()
			in_milla_safe_code = FALSE
		mixture.bound_turf.bound_air = null
		mixture.bound_turf = null
		CHECK_TICK

	log_startup_progress("Wrote [count] tiles in [stop_watch(watch)]s.")

/datum/controller/subsystem/air/proc/bind_turf(turf/to_bind, list/milla_tile = null)
	var/datum/gas_mixture/bound_to_turf/new_air = new()
	to_bind.bound_air = new_air
	new_air.bound_turf = to_bind
	if(isnull(milla_tile))
		milla_tile = new/list(MILLA_TILE_SIZE)
		get_tile_atmos(to_bind, milla_tile)
	new_air.copy_from_milla(milla_tile)
	new_air.lastread = src.times_fired
	new_air.readonly = null
	new_air.dirty = FALSE
	new_air.synchronized = FALSE


/// Similar to addtimer, but triggers once MILLA enters synchronous mode.
/datum/controller/subsystem/air/proc/synchronize(datum/milla_safe/CB)
	// Any proc that wants MILLA to be synchronous should not sleep.
	SHOULD_NOT_SLEEP(TRUE)

	if(is_synchronous)
		var/was_safe = SSair.in_milla_safe_code
		SSair.in_milla_safe_code = TRUE
		// This is one of two intended places to call this otherwise-unsafe proc.
		CB.private_unsafe_invoke()
		SSair.in_milla_safe_code = was_safe
		return
	waiting_for_sync += CB

/datum/controller/subsystem/air/proc/is_in_milla_safe_code()
	return in_milla_safe_code

/datum/controller/subsystem/air/proc/on_milla_tick_finished()
	is_synchronous = TRUE
	in_milla_safe_code = TRUE
	for(var/datum/milla_safe/CB as anything in waiting_for_sync)
		// This is one of two intended places to call this otherwise-unsafe proc.
		CB.private_unsafe_invoke()
	waiting_for_sync.Cut()
	in_milla_safe_code = FALSE

/proc/milla_tick_finished()
	// Any proc that wants MILLA to be synchronous should not sleep.
	SHOULD_NOT_SLEEP(TRUE)

	SSair.on_milla_tick_finished()

/// Create a subclass of this and implement `on_run` to manipulate tile air safely.
/datum/milla_safe
	var/run_args = list()

/// All subclasses should implement this.
/datum/milla_safe/proc/on_run(...)
	// Any proc that wants MILLA to be synchronous should not sleep.
	SHOULD_NOT_SLEEP(TRUE)

	CRASH("[src.type] does not implement on_run")

/// Call this to make the subclass run when it's safe to do so. Args will be passed to on_run.
/datum/milla_safe/proc/invoke_async(...)
	run_args = args.Copy()
	SSair.synchronize(src)

/// Do not call this yourself. This is what is called to run your code from a safe context.
/datum/milla_safe/proc/private_unsafe_invoke()
	soft_assert_safe()
	on_run(arglist(run_args))

/// Used internally to check that we're running safely, but without breaking things worse if we aren't.
/datum/milla_safe/proc/soft_assert_safe()
	ASSERT(SSair.is_in_milla_safe_code())

/// Fetch the air for a turf. Only use from `on_run`.
/datum/milla_safe/proc/get_turf_air(turf/T)
	RETURN_TYPE(/datum/gas_mixture)
	soft_assert_safe()
	// This is one of two intended places to call this otherwise-unsafe proc.
	var/datum/gas_mixture/bound_to_turf/air = T.private_unsafe_get_air()
	if(air.lastread < SSair.times_fired)
		var/list/milla_tile = new/list(MILLA_TILE_SIZE)
		get_tile_atmos(T, milla_tile)
		air.copy_from_milla(milla_tile)
		air.lastread = SSair.times_fired
		air.readonly = null
		air.dirty = FALSE
	if(!air.synchronized)
		air.synchronized = TRUE
		SSair.bound_mixtures += air
	return air

/// Add air to a turf. Only use from `on_run`.
/datum/milla_safe/proc/add_turf_air(turf/T, datum/gas_mixture/air)
	var/datum/gas_mixture/turf_air = get_turf_air(T)
	turf_air.merge(air)

/// Completely replace the air for a turf. Only use from `on_run`.
/datum/milla_safe/proc/set_turf_air(turf/T, datum/gas_mixture/air)
	var/datum/gas_mixture/turf_air = get_turf_air(T)
	turf_air.copy_from(air)
//this can't be done with setup_atmos_machinery() because
// all atmos machinery has to initalize before the first
// pipenet can be built.
/datum/controller/subsystem/air/proc/setup_pipenets()
	for (var/obj/machinery/atmospherics/AM in atmos_machinery)
		var/list/targets = AM.get_rebuild_targets()
		for(var/datum/pipeline/build_off as anything in targets)
			build_off.build_pipeline_blocking(AM)
		CHECK_TICK

GLOBAL_LIST_EMPTY(colored_turfs)
GLOBAL_LIST_EMPTY(colored_images)
/datum/controller/subsystem/air/proc/setup_turf_visuals()
	for(var/sharp_color in GLOB.contrast_colors)
		var/list/add_to = list()
		GLOB.colored_turfs += list(add_to)
		for(var/offset in 0 to SSmapping.max_plane_offset)
			var/obj/effect/overlay/atmos_excited/suger_high = new()
			SET_PLANE_W_SCALAR(suger_high, HIGH_GAME_PLANE, offset)
			add_to += suger_high
			var/image/shiny = new('icons/effects/effects.dmi', suger_high, "atmos_top")
			SET_PLANE_W_SCALAR(shiny, HIGH_GAME_PLANE, offset)
			shiny.color = sharp_color
			GLOB.colored_images += shiny

/datum/controller/subsystem/air/proc/setup_template_machinery(list/atmos_machines)
	var/obj/machinery/atmospherics/AM
	for(var/A in 1 to atmos_machines.len)
		AM = atmos_machines[A]
		AM.atmos_init()
		CHECK_TICK

	for(var/A in 1 to atmos_machines.len)
		AM = atmos_machines[A]
		var/list/targets = AM.get_rebuild_targets()
		for(var/datum/pipeline/build_off as anything in targets)
			build_off.build_pipeline_blocking(AM)
		CHECK_TICK


/datum/controller/subsystem/air/proc/get_init_dirs(type, dir, init_dir)

	if(!pipe_init_dirs_cache[type])
		pipe_init_dirs_cache[type] = list()

	if(!pipe_init_dirs_cache[type]["[init_dir]"])
		pipe_init_dirs_cache[type]["[init_dir]"] = list()

	if(!pipe_init_dirs_cache[type]["[init_dir]"]["[dir]"])
		var/obj/machinery/atmospherics/temp = new type(null, FALSE, dir, init_dir)
		pipe_init_dirs_cache[type]["[init_dir]"]["[dir]"] = temp.get_init_directions()
		qdel(temp)

	return pipe_init_dirs_cache[type]["[init_dir]"]["[dir]"]

/datum/controller/subsystem/air/proc/generate_atmos()
	atmos_gen = list()
	for(var/T in subtypesof(/datum/atmosphere))
		var/datum/atmosphere/atmostype = T
		atmos_gen[initial(atmostype.id)] = new atmostype



/// Takes a gas string, returns the matching mutable gas_mixture
/datum/controller/subsystem/air/proc/parse_gas_string(gas_string, gastype = /datum/gas_mixture)
	var/datum/gas_mixture/cached = strings_to_mix["[gas_string]-[gastype]"]

	if(cached)
		if(istype(cached, /datum/gas_mixture/immutable))
			return cached
		return cached.copy()

	var/datum/gas_mixture/canonical_mix = new gastype()
	// We set here so any future key changes don't fuck us
	strings_to_mix["[gas_string]-[gastype]"] = canonical_mix
	gas_string = preprocess_gas_string(gas_string)

	var/list/gases = canonical_mix.gases
	var/list/gas = params2list(gas_string)
	if(gas["TEMP"])
		canonical_mix.temperature = text2num(gas["TEMP"])
		canonical_mix.temperature_archived = canonical_mix.temperature
		gas -= "TEMP"
	else // if we do not have a temp in the new gas mix lets assume room temp.
		canonical_mix.temperature = T20C
	for(var/id in gas)
		var/path = id
		if(!ispath(path))
			path = gas_id2path(path) //a lot of these strings can't have embedded expressions (especially for mappers), so support for IDs needs to stick around
		ADD_GAS(path, gases)
		gases[path][MOLES] = text2num(gas[id])

	if(istype(canonical_mix, /datum/gas_mixture/immutable))
		return canonical_mix
	return canonical_mix.copy()

/datum/controller/subsystem/air/proc/preprocess_gas_string(gas_string)
	if(!atmos_gen)
		generate_atmos()
	if(!atmos_gen[gas_string])
		return gas_string
	var/datum/atmosphere/mix = atmos_gen[gas_string]
	return mix.gas_string

/**
 * Adds a given machine to the processing system for SSAIR_ATMOSMACHINERY processing.
 *
 * Arguments:
 * * machine - The machine to start processing. Can be any /obj/machinery.
 */
/datum/controller/subsystem/air/proc/start_processing_machine(obj/machinery/machine)
	if(machine.atmos_processing)
		return
	if(QDELETED(machine))
		stack_trace("We tried to add a garbage collecting machine to SSair. Don't")
		return
	machine.atmos_processing = TRUE
	atmos_machinery += machine

/**
 * Removes a given machine to the processing system for SSAIR_ATMOSMACHINERY processing.
 *
 * Arguments:
 * * machine - The machine to stop processing.
 */
/datum/controller/subsystem/air/proc/stop_processing_machine(obj/machinery/machine)
	if(!machine.atmos_processing)
		return
	machine.atmos_processing = FALSE
	atmos_machinery -= machine

	// If we're currently processing atmos machines, there's a chance this machine is in
	// the currentrun list, which is a cache of atmos_machinery. Remove it from that list
	// as well to prevent processing qdeleted objects in the cache.
	if(currentpart == SSAIR_ATMOSMACHINERY)
		currentrun -= machine

/datum/controller/subsystem/air/ui_state(mob/user)
	return ADMIN_STATE(R_DEBUG)

/datum/controller/subsystem/air/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AtmosControlPanel")
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/controller/subsystem/air/ui_data(mob/user)
	var/list/data = list()
	data["excited_groups"] = list()
	for(var/datum/excited_group/group in excited_groups)
		var/turf/T = group.turf_list[1]
		var/area/target = get_area(T)
		var/max = 0
		#ifdef TRACK_MAX_SHARE
		for(var/who in group.turf_list)
			var/turf/open/lad = who
			max = max(lad.max_share, max)
		#endif
		data["excited_groups"] += list(list(
			"jump_to" = REF(T), //Just go to the first turf
			"group" = REF(group),
			"area" = target.name,
			"breakdown" = group.breakdown_cooldown,
			"dismantle" = group.dismantle_cooldown,
			"size" = group.turf_list.len,
			"should_show" = group.should_display,
			"max_share" = max
		))
	data["active_size"] = active_turfs.len
	data["hotspots_size"] = hotspots.len
	data["excited_size"] = excited_groups.len
	data["conducting_size"] = active_super_conductivity.len
	data["frozen"] = can_fire
	data["show_all"] = display_all_groups
	data["fire_count"] = times_fired
	#ifdef TRACK_MAX_SHARE
	data["display_max"] = TRUE
	#else
	data["display_max"] = FALSE
	#endif
	data["showing_user"] = user.hud_used.atmos_debug_overlays
	return data

/datum/controller/subsystem/air/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !check_rights_for(usr.client, R_DEBUG))
		return
	switch(action)
		if("move-to-target")
			var/turf/target = locate(params["spot"])
			if(!target)
				return
			usr.forceMove(target)
		if("toggle-freeze")
			can_fire = !can_fire
			return TRUE
		if("toggle_show_group")
			var/datum/excited_group/group = locate(params["group"])
			if(!group)
				return
			group.should_display = !group.should_display
			if(display_all_groups)
				return TRUE
			if(group.should_display)
				group.display_turfs()
			else
				group.hide_turfs()
			return TRUE
		if("toggle_show_all")
			display_all_groups = !display_all_groups
			for(var/datum/excited_group/group in excited_groups)
				if(display_all_groups)
					group.display_turfs()
				else if(!group.should_display) //Don't flicker yeah?
					group.hide_turfs()
			return TRUE
		if("toggle_user_display")
			var/mob/user = ui.user
			user.hud_used.atmos_debug_overlays = !user.hud_used.atmos_debug_overlays
			if(user.hud_used.atmos_debug_overlays)
				user.client.images += GLOB.colored_images
			else
				user.client.images -= GLOB.colored_images
			return TRUE
