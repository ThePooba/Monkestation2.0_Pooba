/// Produces a mutable appearance glued to the [EMISSIVE_PLANE] dyed to be the [EMISSIVE_COLOR].
/proc/emissive_appearance(icon, icon_state = "", atom/offset_spokesman, layer = FLOAT_LAYER, alpha = 255, appearance_flags = NONE, offset_const)
	// Note: alpha doesn't "do" anything, since it's overriden by the color set shortly after
	// Consider removing it someday? (I wonder if we made emissives blend right we could make alpha actually matter. dreams man, dreams)
	var/mutable_appearance/appearance = mutable_appearance(icon, icon_state, layer, offset_spokesman, EMISSIVE_PLANE, 255, appearance_flags | EMISSIVE_APPEARANCE_FLAGS, offset_const)
	appearance.color = GLOB.emissive_color

	//Test to make sure emissives with broken or missing icon states are created
	if(PERFORM_ALL_TESTS(focus_only/invalid_emissives))
		if(icon_state && !icon_exists(icon, icon_state))
			stack_trace("An emissive appearance was added with non-existant icon_state \"[icon_state]\" in [icon]!")

	return appearance


/// Creates a mutable appearance glued to the EMISSIVE_PLAN, using the values from a mutable appearance
/proc/emissive_appearance_copy(mutable_appearance/to_use, atom/offset_spokesman, appearance_flags = (KEEP_APART))
	var/mutable_appearance/appearance = mutable_appearance(to_use.icon, to_use.icon_state, to_use.layer, offset_spokesman, EMISSIVE_PLANE, to_use.alpha, to_use.appearance_flags | appearance_flags)
	appearance.color = GLOB.emissive_color
	appearance.pixel_x = to_use.pixel_x
	appearance.pixel_y = to_use.pixel_y
	return appearance

// This is a semi hot proc, so we micro it. saves maybe 150ms
// sorry :)
/proc/fast_emissive_blocker(atom/make_blocker)
	// Note: alpha doesn't "do" anything, since it's overriden by the color set shortly after
	// Consider removing it someday?
	var/mutable_appearance/blocker = new()
	blocker.icon = make_blocker.icon
	blocker.icon_state = make_blocker.icon_state
	// blocker.layer = FLOAT_LAYER // Implied, FLOAT_LAYER is default for appearances
	blocker.appearance_flags |= make_blocker.appearance_flags | EMISSIVE_APPEARANCE_FLAGS
	blocker.dir = make_blocker.dir
	blocker.color = GLOB.em_block_color

	// Note, we are ok with null turfs, that's not an error condition we'll just default to 0, the error would be
	// Not passing ANYTHING in, key difference
	SET_PLANE_EXPLICIT(blocker, EMISSIVE_PLANE, make_blocker)
	return blocker

/// Produces a mutable appearance glued to the [EMISSIVE_PLANE] dyed to be the [EM_BLOCK_COLOR].
/proc/emissive_blocker(icon, icon_state = "", atom/offset_spokesman, layer = FLOAT_LAYER, alpha = 255, appearance_flags = NONE, offset_const)
	// Note: alpha doesn't "do" anything, since it's overriden by the color set shortly after
	// Consider removing it someday?
	var/mutable_appearance/appearance = mutable_appearance(icon, icon_state, layer, offset_spokesman, EMISSIVE_PLANE, alpha, appearance_flags | EMISSIVE_APPEARANCE_FLAGS, offset_const)
	appearance.color = GLOB.em_block_color
	return appearance

/// Takes a non area atom and a threshold
/// Makes it block emissive with any pixels with more alpha then that threshold, with the rest allowing the light to pass
/// Returns a list of objects, automatically added to your vis_contents, that apply this effect
/// QDEL them when appropriate
/proc/partially_block_emissives(atom/make_blocker, alpha_to_leave)
	var/static/uid = 0
	uid++
	if(!make_blocker.render_target)
		make_blocker.render_target = "partial_emissive_block_[uid]"

	// First, we cut away a constant amount
	var/cut_away = (alpha_to_leave - 1) / 255
	var/atom/movable/render_step/color/alpha_threshold_down = new(make_blocker, make_blocker.render_target, list(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,-cut_away))
	alpha_threshold_down.render_target = "*emissive_block_alpha_down_[uid]"
	// Then we multiply what remains by the amount we took away
	var/atom/movable/render_step/color/alpha_threshold_up = new(make_blocker, alpha_threshold_down.render_target, list(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,alpha_to_leave, 0,0,0,0))
	alpha_threshold_up.render_target = "*emissive_block_alpha_up_[uid]"
	// Now we just feed that into an emissive blocker
	var/atom/movable/render_step/emissive_blocker/em_block = new(make_blocker, alpha_threshold_up.render_target)
	var/list/hand_back = list()
	hand_back += alpha_threshold_down
	hand_back += alpha_threshold_up
	hand_back += em_block
	// Cast to movable so we can use vis_contents. will work for turfs, but not for areas
	var/atom/movable/vis_cast = make_blocker
	vis_cast.vis_contents += hand_back
	return hand_back
