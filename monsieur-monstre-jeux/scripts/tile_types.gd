class_name TileTypes
extends RefCounted

enum Type { CHALLENGE, SHOP, EVENT }

const CHALLENGE_CHANCE = 0.50
const SHOP_CHANCE = 0.25
const EVENT_CHANCE = 0.25

static func get_random_type(rng: RandomNumberGenerator) -> Type:
	var roll = rng.randf()
	if roll < CHALLENGE_CHANCE:
		return Type.CHALLENGE
	elif roll < CHALLENGE_CHANCE + SHOP_CHANCE:
		return Type.SHOP
	else:
		return Type.EVENT

static func get_type_name(type: Type) -> String:
	match type:
		Type.CHALLENGE: return "Challenge"
		Type.SHOP: return "Shop"
		Type.EVENT: return "Event"
	return "Unknown"
