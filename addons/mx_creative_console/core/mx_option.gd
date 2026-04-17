class_name MXOption
extends RefCounted
## Serializable option descriptors for the MX bridge (Logitech side reads the same schema).


static func toggle(id: String, label: String, value: bool, group: String = "") -> Dictionary:
	return {
		"id": id,
		"type": "toggle",
		"label": label,
		"group": group,
		"value": value,
	}


static func range_option(
	id: String,
	label: String,
	min_v: float,
	max_v: float,
	step: float,
	value: float,
	group: String = "",
) -> Dictionary:
	return {
		"id": id,
		"type": "range",
		"label": label,
		"group": group,
		"min": min_v,
		"max": max_v,
		"step": step,
		"value": value,
	}


## values: Array of String (labels or string tokens). current_index must be in range.
static func choice(id: String, label: String, values: Array, current_index: int, group: String = "") -> Dictionary:
	return {
		"id": id,
		"type": "choice",
		"label": label,
		"group": group,
		"values": values,
		"index": clampi(current_index, 0, maxi(values.size() - 1, 0)),
	}


static func trigger(id: String, label: String, group: String = "") -> Dictionary:
	return {
		"id": id,
		"type": "trigger",
		"label": label,
		"group": group,
	}
