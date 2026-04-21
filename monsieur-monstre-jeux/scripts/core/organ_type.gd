class_name OrganType
extends Resource

## Represents organ type definitions with properties and challenge configuration.
## Provides static factory method to create organ instances with preset data.

# Organ enumeration - using constants instead of enum for cross-file compatibility
const ORGAN_HEART: int = 0
const ORGAN_LUNGS: int = 1
const ORGAN_EYES: int = 2
const ORGAN_LEGS: int = 3
const ORGAN_HANDS: int = 4
const ORGAN_STOMACH: int = 5
const ORGAN_BRAIN: int = 6
const ORGAN_PANCREAS: int = 7
const ORGAN_LIVER: int = 8
const ORGAN_KIDNEYS: int = 9
#const ORGAN_SPLEEN: int = 10
#const ORGAN_GALLBLADDER: int = 11
#const ORGAN_THYROID: int = 12
#const ORGAN_ADRENAL: int = 13
#const ORGAN_INTESTINE: int = 14
#const ORGAN_SPINAL: int = 15
#const ORGAN_SKIN: int = 16

# All organs as array for iteration
const ALL_ORGANS: Array = [
	ORGAN_HEART, ORGAN_LUNGS, ORGAN_EYES, ORGAN_LEGS, ORGAN_HANDS, ORGAN_BRAIN, ORGAN_PANCREAS, ORGAN_LIVER, ORGAN_KIDNEYS, ORGAN_STOMACH
]

## Unique identifier for the organ type.
@export var organ_id: int
## Internal name for the organ.
@export var organ_name: String
## Display name shown to players.
@export var display_name: String
## Description of the organ's function.
@export var description: String
## Maximum count stackable (1 for unique organs).
@export var max_count: int = 1
## Price when selling this organ.
@export var sell_price: int
## Price when buying this organ.
@export var buy_price: int
## If true, organ cannot be sold or stolen.
@export var is_vital: bool = false
## If true, organ cannot be lost.
@export var is_protected: bool = false
## Description of the organ's buff/benefit.
@export var buff_description: String
## Description of side effects when organ is missing.
@export var side_effect_description: String
## Challenge type associated with this organ (e.g., "heart", "lungs").
@export var challenge_type: String = ""

## Factory method to create an OrganType instance with preset data for the given organ_id.
## Returns an OrganType resource configured with display name, descriptions, and challenge info.
static func get_organ_data(organ_id: int) -> OrganType:
	var organ = OrganType.new()
	organ.organ_id = organ_id
	
	match organ_id:
		ORGAN_HEART:
			organ.display_name = "Heart"
			organ.description = "Maintains stamina. Count heartbeats when missing."
			organ.max_count = 2
			organ.is_vital = true
			organ.buff_description = "+Stamina regeneration, Dual buffer"
			organ.side_effect_description = "Must count heartbeats every 10 sec"
			organ.challenge_type = "heart"
		ORGAN_LUNGS:
			organ.display_name = "Lungs"
			organ.description = "More lungs = lighter (float up easier)"
			organ.max_count = 3
			organ.buff_description = "+Air capacity, Buoyancy control"
			organ.side_effect_description = "Less lungs = sink faster"
			organ.challenge_type = "lungs"
		ORGAN_EYES:
			organ.display_name = "Eyes"
			organ.description = "Full vision. Blind = audio cues only."
			organ.max_count = 2
			organ.buff_description = "+Accuracy, Full vision"
			organ.side_effect_description = "Blind mode: Audio cues, distortion"
			organ.challenge_type = "eyes"
		ORGAN_LEGS:
			organ.display_name = "Legs"
			organ.description = "Mobility. No legs = alt movement mode."
			organ.max_count = 2
			organ.buff_description = "+Speed, +Jump"
			organ.side_effect_description = "Must use Wheels/Crawl/Hop"
			organ.challenge_type = "legs"
		ORGAN_HANDS:
			organ.display_name = "Hands"
			organ.description = "Input access. Fewer = limited buttons."
			organ.max_count = 2
			organ.buff_description = "+All buttons, +Mash speed"
			organ.side_effect_description = "Limited buttons, swap for access"
			organ.challenge_type = "hands"
		ORGAN_STOMACH:
			organ.display_name = "Stomach"
			organ.description = "Digestion. No stomach = choking risk."
			organ.max_count = 1
			organ.buff_description = "+Normal eating speed"
			organ.side_effect_description = "2x eating time, 15% choking risk"
			organ.challenge_type = "stomach"
		ORGAN_BRAIN:
			organ.display_name = "Brain"
			organ.description = "Life indicator. CANNOT BE LOST = GAME OVER"
			organ.max_count = 1
			organ.is_vital = true
			organ.is_protected = true
			organ.buff_description = "Life itself"
			organ.side_effect_description = "N/A - Cannot be lost"
			organ.challenge_type = ""
		ORGAN_PANCREAS:
			organ.display_name = "Pancreas"
			organ.description = "Insulin. No pancreas = QTE every 15s"
			organ.max_count = 1
			organ.buff_description = "+Stable blood sugar"
			organ.side_effect_description = "Insulin QTE every 15 seconds"
			organ.challenge_type = "pancreas"
		ORGAN_LIVER:
			organ.display_name = "Liver"
			organ.description = "Alcohol detox. More = drink longer."
			organ.max_count = 2
			organ.buff_description = "+Alcohol resistance"
			organ.side_effect_description = "No liver = immediate drunk"
			organ.challenge_type = "liver"
		ORGAN_KIDNEYS:
			organ.display_name = "Kidneys"
			organ.description = "Hydration balance"
			organ.max_count = 2
			organ.buff_description = "+Hydration management"
			organ.side_effect_description = "Faster hydration drain"
			organ.challenge_type = "kidneys"
		#ORGAN_SPLEEN:
			#organ.display_name = "Spleen"
			#organ.description = "Blood loss recovery"
			#organ.max_count = 1
			#organ.buff_description = "+Blood loss recovery"
			#organ.side_effect_description = "Slower damage recovery"
			#organ.challenge_type = "spleen"
		#ORGAN_GALLBLADDER:
			#organ.display_name = "Gallbladder"
			#organ.description = "Indigestion management"
			#organ.max_count = 1
			#organ.buff_description = "+Digestion capacity"
			#organ.side_effect_description = "Indigestion shake QTE"
			#organ.challenge_type = "gallbladder"
		#ORGAN_THYROID:
			#organ.display_name = "Thyroid"
			#organ.description = "Temperature regulation"
			#organ.max_count = 1
			#organ.buff_description = "+Temperature adaptation"
			#organ.side_effect_description = "Vulnerable to temperature"
			#organ.challenge_type = "thyroid"
		#ORGAN_ADRENAL:
			#organ.display_name = "Adrenal Glands"
			#organ.description = "Burst charge for speed boosts"
			#organ.max_count = 2
			#organ.buff_description = "+Speed boost potential"
			#organ.side_effect_description = "No boost without glands"
			#organ.challenge_type = "adrenal"
		#ORGAN_INTESTINE:
			#organ.display_name = "Large Intestine"
			#organ.description = "Fart boost speed"
			#organ.max_count = 2
			#organ.buff_description = "+Fart boost speed"
			#organ.side_effect_description = "No fart boost available"
			#organ.challenge_type = "intestine"
		#ORGAN_SPINAL:
			#organ.display_name = "Spinal Cord"
			#organ.description = "Stagger recovery"
			#organ.max_count = 1
			#organ.buff_description = "+Stagger recovery"
			#organ.side_effect_description = "Longer stagger duration"
			#organ.challenge_type = "spinal"
		#ORGAN_SKIN:
			#organ.display_name = "Skin"
			#organ.description = "Environmental shield"
			#organ.max_count = 1
			#organ.buff_description = "+Environmental protection"
			#organ.side_effect_description = "+25% damage from all"
			#organ.challenge_type = "skin"
	return organ

## Returns the display name for the given organ_id.
static func get_display_name(organ_id: int) -> String:
	return get_organ_data(organ_id).display_name
