extends Node2D

## Simple test script to verify organ quirks work.
## Attach to any Node2D in a scene.

var organ_manager: OrganManager
var brain: BrainRetrieval

func _ready():
	organ_manager = OrganManager.new()
	brain = BrainRetrieval.new()
	add_child(organ_manager)
	add_child(brain)

	organ_manager.set_player_index(0)

	print("Organ system ready!")
	print("Press 1=Heart, 2=Liver, 3=Pancreas, 4=Mouth, 5=Eyes, 6=Arms, 7=Legs")
	print("Press SPACE to lose random organ")
	print("Press R to restore all")

func _input(event):
	# Number keys to toggle organs
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: toggle_organ("heart")
			KEY_2: toggle_organ("liver")
			KEY_3: toggle_organ("pancreas")
			KEY_4: toggle_organ("mouth")
			KEY_5: toggle_organ("eyes")
			KEY_6: toggle_organ("arms")
			KEY_7: toggle_organ("legs")
			KEY_SPACE: lose_random()
			KEY_R: restore_all()

func toggle_organ(name: String):
	var is_missing = false
	match name:
		"heart": is_missing = organ_manager.heart.is_missing
		"liver": is_missing = organ_manager.liver.is_missing
		"pancreas": is_missing = organ_manager.pancreas.is_missing
		"mouth": is_missing = organ_manager.mouth.is_missing
		"eyes": is_missing = organ_manager.eyes.is_missing
		"arms": is_missing = organ_manager.arms.is_missing
		"legs": is_missing = organ_manager.legs.is_missing

	organ_manager.set_organ_missing(name, not is_missing)
	if not is_missing:
		organ_manager.activate_organ(name)

	var status = "MISSING" if not is_missing else "OK"
	print(" Organ %s: %s" % [name, status])

func lose_random():
	var organs = ["heart", "liver", "pancreas", "mouth", "eyes", "arms", "legs"]
	var r = organs[randi() % organs.size()]
	toggle_organ(r)

func restore_all():
	for o in ["heart", "liver", "pancreas", "mouth", "eyes", "arms", "legs"]:
		organ_manager.set_organ_missing(o, false)
	brain.revive_player()
	print("All organs restored!")

func _process(delta):
	organ_manager._process(delta)

	# Print status every 2 seconds
	if int(Time.get_ticks_msec() / 2000) % 2 == 0:
		var missing = []
		for o in ["heart", "liver", "pancreas", "mouth", "eyes", "arms", "legs"]:
			match o:
				"heart": if organ_manager.heart.is_missing: missing.append("Heart")
				"liver": if organ_manager.liver.is_missing: missing.append("Liver")
				"pancreas": if organ_manager.pancreas.is_missing: missing.append("Pancreas")
				"mouth": if organ_manager.mouth.is_missing: missing.append("Mouth")
				"eyes": if organ_manager.eyes.is_missing: missing.append("Eyes")
				"arms": if organ_manager.arms.is_missing: missing.append("Arms")
				"legs": if organ_manager.legs.is_missing: missing.append("Legs")
		if missing.size() > 0:
			print("Missing: ", missing)
