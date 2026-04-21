# Organ constants for cross-script compatibility
# Use these constants instead of enum values to avoid scope issues

## Organ ID constants representing different organ types.
## These are used as keys in organ dictionaries and for cross-script compatibility.
# Organ IDs
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
const ORGAN_SPLEEN: int = 10
const ORGAN_GALLBLADDER: int = 11
const ORGAN_THYROID: int = 12
const ORGAN_ADRENAL: int = 13
const ORGAN_INTESTINE: int = 14
const ORGAN_SPINAL: int = 15
const ORGAN_SKIN: int = 16

## All organ IDs as array for iteration.
const ALL_ORGANS: Array = [
	ORGAN_HEART, ORGAN_LUNGS, ORGAN_EYES, ORGAN_LEGS, ORGAN_HANDS,
	ORGAN_STOMACH, ORGAN_BRAIN, ORGAN_PANCREAS, ORGAN_LIVER, ORGAN_KIDNEYS,
	ORGAN_SPLEEN, ORGAN_GALLBLADDER, ORGAN_THYROID, ORGAN_ADRENAL, ORGAN_INTESTINE,
	ORGAN_SPINAL, ORGAN_SKIN
]

## Organ IDs that can have multiple instances (stackable).
const STACKABLE_ORGANS: Array = [
	ORGAN_HEART, ORGAN_LUNGS, ORGAN_EYES, ORGAN_LEGS, ORGAN_HANDS,
	ORGAN_STOMACH, ORGAN_PANCREAS, ORGAN_LIVER, ORGAN_KIDNEYS,
	ORGAN_SPLEEN, ORGAN_GALLBLADDER, ORGAN_THYROID, ORGAN_ADRENAL, ORGAN_INTESTINE,
	ORGAN_SPINAL, ORGAN_SKIN
]

## Vital organs that cannot be sold or stolen.
const VITAL_ORGANS: Array = [ORGAN_HEART, ORGAN_BRAIN]

## Protected organs that cannot be lost.
const PROTECTED_ORGANS: Array = [ORGAN_BRAIN]

## Human-readable display names for organs.
const ORGAN_DISPLAY_NAMES: Dictionary = {
	ORGAN_HEART: "Heart",
	ORGAN_LUNGS: "Lungs",
	ORGAN_EYES: "Eyes",
	ORGAN_LEGS: "Legs",
	ORGAN_HANDS: "Hands",
	ORGAN_STOMACH: "Stomach",
	ORGAN_BRAIN: "Brain",
	ORGAN_PANCREAS: "Pancreas",
	ORGAN_LIVER: "Liver",
	ORGAN_KIDNEYS: "Kidneys",
	ORGAN_SPLEEN: "Spleen",
	ORGAN_GALLBLADDER: "Gallbladder",
	ORGAN_THYROID: "Thyroid",
	ORGAN_ADRENAL: "Adrenal Glands",
	ORGAN_INTESTINE: "Large Intestine",
	ORGAN_SPINAL: "Spinal Cord",
	ORGAN_SKIN: "Skin"
}
