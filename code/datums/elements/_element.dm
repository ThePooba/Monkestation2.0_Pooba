/**
 * A holder for simple behaviour that can be attached to many different types
 *
 * Only one element of each type is instanced during game init.
 * Otherwise acts basically like a lightweight component.
 */
/datum/element
	/// Option flags for element behaviour
	var/element_flags = NONE
	/**
	  * The index of the first attach argument to consider for duplicate elements
	  *
	  * All arguments from this index onwards (1 based) are hashed into the key to determine
	  * if this is a new unique element or one already exists
	  *
	  * Is only used when flags contains [ELEMENT_BESPOKE]
	  *
	  * This is infinity so you must explicitly set this
	  */
	var/argument_hash_start_idx = INFINITY

/// Activates the functionality defined by the element on the given target datum
/datum/element/proc/Attach(datum/target)
	SHOULD_CALL_PARENT(TRUE)
	if(type == /datum/element)
		return ELEMENT_INCOMPATIBLE
	SEND_SIGNAL(target, COMSIG_ELEMENT_ATTACH, src)
	if(element_flags & ELEMENT_DETACH_ON_HOST_DESTROY)
		RegisterSignal(target, COMSIG_QDELETING, PROC_REF(OnTargetDelete), override = TRUE)

/datum/element/proc/OnTargetDelete(datum/source, force)
	SIGNAL_HANDLER
	Detach(source)

/// Deactivates the functionality defines by the element on the given datum
/datum/element/proc/Detach(datum/source, ...)
	SIGNAL_HANDLER
	SHOULD_CALL_PARENT(TRUE)

	SEND_SIGNAL(source, COMSIG_ELEMENT_DETACH, src)
	UnregisterSignal(source, COMSIG_QDELETING)

/datum/element/Destroy(force)
	if(!force)
		return QDEL_HINT_LETMELIVE
	SSdcs.elements_by_type -= type
	return ..()

//DATUM PROCS

/// Finds the singleton for the element type given and attaches it to src
/datum/proc/_AddElement(list/arguments)
	if(QDELING(src))
		CRASH("We just tried to add an element to a qdeleted datum, something is fucked")
	var/datum/element/ele = SSdcs.GetElement(arguments)
	arguments[1] = src
	if(ele.Attach(arglist(arguments)) == ELEMENT_INCOMPATIBLE)
		CRASH("Incompatible element [ele.type] was assigned to a [type]! args: [json_encode(args)]")

/// Finds the element and checks if the source is currently part of the element
/datum/proc/_HasElement(datum/source, datum/element/type)
	return SSdcs._Has_Element(source, type)

/**
 * Finds the singleton for the element type given and detaches it from src
 * You only need additional arguments beyond the type if you're using [ELEMENT_BESPOKE]
 */
/datum/proc/_RemoveElement(list/arguments)
	var/datum/element/ele = SSdcs.GetElement(arguments)
	if(ele.element_flags & ELEMENT_COMPLEX_DETACH)
		arguments[1] = src
		ele.Detach(arglist(arguments))
	else
		ele.Detach(src)
