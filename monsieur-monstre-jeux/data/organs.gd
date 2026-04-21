# Organ data configuration for Organ Grudge
# Resource file for organ definitions

extends Resource
class_name OrganDataConfig

## Static data file containing all organ configurations.
## Note: This should be saved as a .tres file (Resource) for proper usage.
## Load with: var config = load("res://data/organs.tres")

const OrganConst = preload("res://scripts/core/organ_constants.gd")

# All organ configurations as dictionaries
const ORGANS: Dictionary = {
	OrganConst.ORGAN_HEART: {
		"id": OrganConst.ORGAN_HEART,
		"name": "Heart",
		"description": "Maintains stamina. Count heartbeats when missing.",
		"max_count": 2,
		"is_vital": true,
		"is_protected": false,
		"buy_price": 0,
		"sell_price": 0,
		"buff": "+Stamina regeneration, Dual buffer",
		"side_effect": "Must count heartbeats every 10 sec"
	},
	OrganConst.ORGAN_LUNGS: {
		"id": OrganConst.ORGAN_LUNGS,
		"name": "Lungs",
		"description": "More lungs = lighter (float up easier)",
		"max_count": 3,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 50,
		"sell_price": 25,
		"buff": "+Air capacity, Buoyancy control",
		"side_effect": "Less lungs = sink faster"
	},
	OrganConst.ORGAN_EYES: {
		"id": OrganConst.ORGAN_EYES,
		"name": "Eyes",
		"description": "Full vision. Blind = audio cues only.",
		"max_count": 2,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 45,
		"sell_price": 22,
		"buff": "+Accuracy, Full vision",
		"side_effect": "Blind mode: Audio cues, distortion"
	},
	OrganConst.ORGAN_LEGS: {
		"id": OrganConst.ORGAN_LEGS,
		"name": "Legs",
		"description": "Mobility. No legs = alt movement mode.",
		"max_count": 2,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 40,
		"sell_price": 20,
		"buff": "+Speed, +Jump",
		"side_effect": "Must use Wheels/Crawl/Hop"
	},
	OrganConst.ORGAN_HANDS: {
		"id": OrganConst.ORGAN_HANDS,
		"name": "Hands",
		"description": "Input access. Fewer = limited buttons.",
		"max_count": 2,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 40,
		"sell_price": 20,
		"buff": "+All buttons, +Mash speed",
		"side_effect": "Limited buttons, swap for access"
	},
	OrganConst.ORGAN_STOMACH: {
		"id": OrganConst.ORGAN_STOMACH,
		"name": "Stomach",
		"description": "Digestion. No stomach = choking risk.",
		"max_count": 1,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 35,
		"sell_price": 17,
		"buff": "+Normal eating speed",
		"side_effect": "2x eating time, 15% choking risk"
	},
	OrganConst.ORGAN_BRAIN: {
		"id": OrganConst.ORGAN_BRAIN,
		"name": "Brain",
		"description": "Life indicator. CANNOT BE LOST = GAME OVER",
		"max_count": 1,
		"is_vital": true,
		"is_protected": true,
		"buy_price": 0,
		"sell_price": 0,
		"buff": "Life itself",
		"side_effect": "N/A - Cannot be lost"
	},
	OrganConst.ORGAN_PANCREAS: {
		"id": OrganConst.ORGAN_PANCREAS,
		"name": "Pancreas",
		"description": "Insulin. No pancreas = QTE every 15s",
		"max_count": 1,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 55,
		"sell_price": 27,
		"buff": "+Stable blood sugar",
		"side_effect": "Insulin QTE every 15 seconds"
	},
	OrganConst.ORGAN_LIVER: {
		"id": OrganConst.ORGAN_LIVER,
		"name": "Liver",
		"description": "Alcohol detox. More = drink longer.",
		"max_count": 2,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 45,
		"sell_price": 22,
		"buff": "+Alcohol resistance",
		"side_effect": "No liver = immediate drunk"
	},
	OrganConst.ORGAN_KIDNEYS: {
		"id": OrganConst.ORGAN_KIDNEYS,
		"name": "Kidneys",
		"description": "Hydration balance",
		"max_count": 2,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 35,
		"sell_price": 17,
		"buff": "+Hydration management",
		"side_effect": "Faster hydration drain"
	},
	OrganConst.ORGAN_SPLEEN: {
		"id": OrganConst.ORGAN_SPLEEN,
		"name": "Spleen",
		"description": "Blood loss recovery",
		"max_count": 1,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 30,
		"sell_price": 15,
		"buff": "+Blood loss recovery",
		"side_effect": "Slower damage recovery"
	},
	OrganConst.ORGAN_GALLBLADDER: {
		"id": OrganConst.ORGAN_GALLBLADDER,
		"name": "Gallbladder",
		"description": "Indigestion management",
		"max_count": 1,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 30,
		"sell_price": 15,
		"buff": "+Digestion capacity",
		"side_effect": "Indigestion shake QTE"
	},
	OrganConst.ORGAN_THYROID: {
		"id": OrganConst.ORGAN_THYROID,
		"name": "Thyroid",
		"description": "Temperature regulation",
		"max_count": 1,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 30,
		"sell_price": 15,
		"buff": "+Temperature adaptation",
		"side_effect": "Vulnerable to temperature"
	},
	OrganConst.ORGAN_ADRENAL: {
		"id": OrganConst.ORGAN_ADRENAL,
		"name": "Adrenal Glands",
		"description": "Burst charge for speed boosts",
		"max_count": 2,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 50,
		"sell_price": 25,
		"buff": "+Speed boost potential",
		"side_effect": "No boost without glands"
	},
	OrganConst.ORGAN_INTESTINE: {
		"id": OrganConst.ORGAN_INTESTINE,
		"name": "Large Intestine",
		"description": "Fart boost speed",
		"max_count": 2,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 40,
		"sell_price": 20,
		"buff": "+Fart boost speed",
		"side_effect": "No fart boost available"
	},
	OrganConst.ORGAN_SPINAL: {
		"id": OrganConst.ORGAN_SPINAL,
		"name": "Spinal Cord",
		"description": "Stagger recovery",
		"max_count": 1,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 35,
		"sell_price": 17,
		"buff": "+Stagger recovery",
		"side_effect": "Longer stagger duration"
	},
	OrganConst.ORGAN_SKIN: {
		"id": OrganConst.ORGAN_SKIN,
		"name": "Skin",
		"description": "Environmental shield",
		"max_count": 1,
		"is_vital": false,
		"is_protected": false,
		"buy_price": 25,
		"sell_price": 12,
		"buff": "+Environmental protection",
		"side_effect": "+25% damage from all"
	}
}

## Returns the organ info dictionary for the given organ_id.
static func get_organ_info(organ_id: int) -> Dictionary:
	return ORGANS.get(organ_id, {})

## Returns an array of all organ IDs defined in ORGANS.
static func get_all_organs() -> Array:
	return ORGANS.keys()
