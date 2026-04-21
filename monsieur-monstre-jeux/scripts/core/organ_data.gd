class_name OrganData
extends RefCounted

# Organ types available in the game
enum OrganType {
	BRAIN,
	HEART,
	LUNGS,
	ARMS,
	LEGS,
	EYES,
	PANCREAS,
	LIVER,
	KIDNEYS
}

# Organ information: name, challenge type, base quantity
const ORGANS_INFO := {
	OrganType.BRAIN: {
		"name": "Brain",
		"challenge_type": "",
		"base_quantity": 1,
		"can_be_stolen": false,
		"description": "Cannot be lost. Losing = 1 turn grace period then elimination."
	},
	OrganType.HEART: {
		"name": "Heart",
		"challenge_type": "joystick_pump",
		"base_quantity": 1,
		"can_be_stolen": true,
		"description": "CPR challenge - pump joystick up then down."
	},
	OrganType.LUNGS: {
		"name": "Lungs",
		"challenge_type": "continuous_alternate",
		"base_quantity": 1,
		"can_be_stolen": true,
		"description": "Apnea challenge - alternate L1/R1 to maintain rate."
	},
	OrganType.ARMS: {
		"name": "Arms",
		"challenge_type": "periodic_tap",
		"base_quantity": 2,
		"can_be_stolen": true,
		"description": "Swat flies challenge - tap within time window."
	},
	OrganType.LEGS: {
		"name": "Legs",
		"challenge_type": "periodic_tap_alt",
		"base_quantity": 2,
		"can_be_stolen": true,
		"description": "Step dance challenge - alternate between feet."
	},
	OrganType.EYES: {
		"name": "Eyes",
		"challenge_type": "blink",
		"base_quantity": 2,
		"can_be_stolen": true,
		"description": "Don't blink challenge - press button during blink window."
	},
	OrganType.PANCREAS: {
		"name": "Pancreas",
		"challenge_type": "qte_sequence",
		"base_quantity": 1,
		"can_be_stolen": true,
		"description": "Insulin shot challenge - complete A-A-B sequence."
	},
	OrganType.LIVER: {
		"name": "Liver",
		"challenge_type": "to_be_decided",
		"base_quantity": 1,
		"can_be_stolen": true,
		"description": "TBD challenge."
	},
	OrganType.KIDNEYS: {
		"name": "Kidneys",
		"challenge_type": "to_be_decided",
		"base_quantity": 2,
		"can_be_stolen": true,
		"description": "TBD challenge."
	}
}

# Get organ info by type
static func get_info(organ_type: OrganType) -> Dictionary:
	return ORGANS_INFO.get(organ_type, {})

# Get organ name
static func get_name(organ_type: OrganType) -> String:
	return ORGANS_INFO.get(organ_type, {}).get("name", "Unknown")

# Get challenge type for organ
static func get_challenge_type(organ_type: OrganType) -> String:
	return ORGANS_INFO.get(organ_type, {}).get("challenge_type", "")

# Get base quantity for organ
static func get_base_quantity(organ_type: OrganType) -> int:
	return ORGANS_INFO.get(organ_type, {}).get("base_quantity", 1)

# Check if organ can be stolen
static func can_be_stolen(organ_type: OrganType) -> bool:
	return ORGANS_INFO.get(organ_type, {}).get("can_be_stolen", true)

# Get difficulty scaling based on remaining organs
static func get_difficulty_for_count(organ_type: OrganType, remaining: int) -> float:
	var base := get_base_quantity(organ_type)
	if remaining >= base:
		return 0.5  # Easy - extra organs
	elif remaining == base - 1:
		return 1.0  # Medium - base amount
	elif remaining == 1:
		return 1.5  # Hard - one left
	else:
		return 2.0  # Very hard - none left (game penalty applies)

# Calculate extra organ bonus/quirk effect
static func get_extra_organ_quirk(organ_type: OrganType, extra_count: int) -> Dictionary:
	match organ_type:
		OrganType.LUNGS:
			# More lungs = faster but higher air consumption
			return {
				"positive": "Faster ascent for air",
				"negative": "Higher air consumption, fight buoyancy harder",
				"bonus_multiplier": 1.0 + (extra_count * 0.2),
				"penalty_multiplier": 1.0 + (extra_count * 0.3)
			}
		OrganType.ARMS:
			# More arms = bonus taps but complex timing
			return {
				"positive": "Extra tap available for mistakes",
				"negative": "Complex multi-tap timing required",
				"bonus_multiplier": 1.0 + (extra_count * 0.15),
				"penalty_multiplier": 1.0 + (extra_count * 0.2)
			}
		OrganType.LEGS:
			# More legs = alternation easier but faster required rate
			return {
				"positive": "Easier alternation pattern",
				"negative": "Faster rate required",
				"bonus_multiplier": 1.0 + (extra_count * 0.1),
				"penalty_multiplier": 1.0 + (extra_count * 0.25)
			}
		OrganType.EYES:
			# More eyes = longer windows but harder to sync
			return {
				"positive": "Longer blink windows",
				"negative": "Must blink all eyes in sync",
				"bonus_multiplier": 1.0 + (extra_count * 0.1),
				"penalty_multiplier": 1.0 + (extra_count * 0.15)
			}
		_:
			# Generic bonus
			return {
				"positive": "Extra organ bonus",
				"negative": "Higher challenge difficulty",
				"bonus_multiplier": 1.0 + (extra_count * 0.1),
				"penalty_multiplier": 1.0 + (extra_count * 0.1)
			}
