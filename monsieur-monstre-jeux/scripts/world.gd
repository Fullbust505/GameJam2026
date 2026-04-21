extends Node

@onready var players := {
	"P1" : {
		viewport = $HBoxContainer/P1_view_container/P1_view,
		camera = $HBoxContainer/P1_view_container/P1_view/P1Cam,
		player = $HBoxContainer/P1_view_container/P1_view/Level/P1
	},
	"P2" : {
		viewport = $HBoxContainer/P2_view_container/P2_view,
		camera = $HBoxContainer/P2_view_container/P2_view/P2Cam,
		player = $HBoxContainer/P1_view_container/P1_view/Level/P2
	}
}

func _ready():
	players["P2"].viewport.world_2d = players["P1"].viewport.world_2d
	for node in players.values():
		var remote_transform := RemoteTransform2D.new()
		remote_transform.remote_path = node.camera.get_path()
		node.player.add_child(remote_transform)
