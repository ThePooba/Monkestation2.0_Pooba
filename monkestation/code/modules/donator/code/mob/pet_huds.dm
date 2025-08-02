/datum/hud/dextrous/cyber_husky/New(mob/owner)
	..()

	var/atom/movable/screen/inventory/inv_box
	inv_box = new /atom/movable/screen/inventory(null, src)
	inv_box.name = "Glasses"
	inv_box.icon = ui_style
	inv_box.icon_state = "glasses"
	// inv_box.icon_full = "template"
	inv_box.screen_loc = ui_drone_head
	inv_box.slot_id = ITEM_SLOT_EYES
	static_inventory += inv_box
